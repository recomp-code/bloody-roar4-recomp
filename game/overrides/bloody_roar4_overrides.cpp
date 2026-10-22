// Game override: Bloody Roar 4 [Analog Stick Mod] (PAL, SLES_518.77, entry 0x00100008)
//
// The analog stick mod patches the game's own copy of libpad's scePadRead (0x002DA7D0, found by
// matching NBA Street V3's scePadRead word for word): the 2nd instruction became "j 0x000FD050"
// and the final "jr ra" became "j 0x000FD05C", i.e. code outside the ELF that post-processes the
// pad data the game reads. That code is not on the disc as such, so it cannot be recompiled.
// Here scePadRead is the runtime's (HLE) and the mod's job is done natively after it:
//   - the pad is in analog mode from the start (PS2X_PAD_ANALOG=1, set by the launcher); on a
//     console the player has to press ANALOG;
//   - while the pad reports analog mode (0x73 / 0x79), the left stick also presses the D-pad
//     (8 directions), which is how the game moves.
// PS2X_BR4_STICK=0 turns the stick-to-D-pad mapping off; PS2X_BR4_STICK_DEADZONE=<0..127>
// (default 48) is how far from the centre the stick must go.
//
// 16:9 by default (PS2X_BR4_WIDESCREEN=0 turns it off): PCSX2's SLES-51877 widescreen pnach by ElHecht, a continuous
// write of the horizontal projection scale at 0x0060EC20), applied on every sceGsSyncV. Needs
// AspectRatio = 16:9 in the GS host's ini.

#include "game_overrides.h"
#include "ps2_runtime.h"
#include "ps2_runtime_macros.h"

#include <algorithm>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <string>

void ps2xAddEeIdleLoop(uint32_t begin, uint32_t end); // EeScheduler.cpp

namespace
{
    constexpr uint32_t kScePadRead = 0x002DA7D0u;

    constexpr uint16_t kPadBtnUp = 1u << 4;
    constexpr uint16_t kPadBtnRight = 1u << 5;
    constexpr uint16_t kPadBtnDown = 1u << 6;
    constexpr uint16_t kPadBtnLeft = 1u << 7;

    constexpr uint32_t kSceGsSyncV = 0x002C9120u;
    constexpr uint32_t kProjectionScaleX = 0x0060EC20u;
    constexpr uint32_t kProjectionScaleX4x3 = 0x3FDA2E04u;
    constexpr uint32_t kProjectionScaleX16x9 = 0x3FA3A283u;

    PS2Runtime::RecompiledFunction g_padReadHandler = nullptr;
    PS2Runtime::RecompiledFunction g_syncVHandler = nullptr;

    // The game's wait at 0x0029E6C0-0x0029E6FC: "while (*(gp-0x6ff8) != *(gp-0x6ff4) || *(u8 *)(gp-0x7000)) call
    // *(gp-0x72e0) if set", a queue that interrupt handlers drain. Only loads: in the deterministic (online) mode emulated
    // time goes on to the next event there instead of spinning through the dispatcher (3/4 of the game thread, ~45 fps).
    constexpr uint32_t kWaitLoopBegin = 0x0029E6C0u;
    constexpr uint32_t kWaitLoopEnd = 0x0029E700u;

    // Environment variable or "" (MSVC: _dupenv_s, getenv is deprecated there).
    std::string envValue(const char *name)
    {
        std::string value;
#if defined(_MSC_VER)
        char *env = nullptr;
        size_t envLength = 0;
        if (_dupenv_s(&env, &envLength, name) == 0 && env)
        {
            value = env;
            std::free(env);
        }
#else
        if (const char *env = std::getenv(name))
            value = env;
#endif
        return value;
    }

    int stickDeadzone()
    {
        static const int s_deadzone = []
        {
            const std::string env = envValue("PS2X_BR4_STICK_DEADZONE");
            return env.empty() ? 48 : std::clamp(std::atoi(env.c_str()), 0, 127);
        }();
        return s_deadzone;
    }

    // scePadRead(port, slot, data) -> 1 when data holds a fresh reading.
    void padReadWithStick(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        const uint32_t dataAddr = GPR_U32(ctx, 6);
        g_padReadHandler(rdram, ctx, runtime);
        if (GPR_U32(ctx, 2) == 0u || dataAddr == 0u || dataAddr + 8u > PS2_RAM_SIZE)
            return;

        uint8_t *data = rdram + dataAddr;
        const uint8_t mode = data[1];
        if (mode != 0x73u && mode != 0x79u)
            return;

        const int dx = static_cast<int>(data[6]) - 0x80;
        const int dy = static_cast<int>(data[7]) - 0x80;
        const int magnitude = std::max(std::abs(dx), std::abs(dy));
        if (magnitude <= stickDeadzone())
            return;

        // 8 directions: an axis counts when it is at least half of the dominant one (~26.6 deg).
        uint16_t pressed = 0u;
        if (std::abs(dx) * 2 >= magnitude)
            pressed |= dx < 0 ? kPadBtnLeft : kPadBtnRight;
        if (std::abs(dy) * 2 >= magnitude)
            pressed |= dy < 0 ? kPadBtnUp : kPadBtnDown;

        uint16_t buttons = static_cast<uint16_t>(data[2] | (data[3] << 8)); // active low
        buttons = static_cast<uint16_t>(buttons & ~pressed);
        data[2] = static_cast<uint8_t>(buttons & 0xFFu);
        data[3] = static_cast<uint8_t>(buttons >> 8);
    }

    bool g_widescreen = false;

    void syncVHook(uint8_t *rdram, R5900Context *ctx, PS2Runtime *runtime)
    {
        if (g_widescreen)
        {
            uint32_t scale = 0;
            std::memcpy(&scale, rdram + kProjectionScaleX, sizeof(scale));
            if (scale == kProjectionScaleX4x3)
            {
                const uint32_t wide = kProjectionScaleX16x9;
                std::memcpy(rdram + kProjectionScaleX, &wide, sizeof(wide));
            }
        }
        g_syncVHandler(rdram, ctx, runtime);
    }

    // PS2X_CD_IMAGE overrides; default is the ISO next to the extracted files (<elf dir>\..\BR4.iso).
    void configureCdImage()
    {
        PS2Runtime::IoPaths paths = PS2Runtime::getIoPaths();
        std::filesystem::path image;
        if (const std::string env = envValue("PS2X_CD_IMAGE"); !env.empty())
            image = env;
        if (image.empty() && !paths.elfDirectory.empty())
            image = paths.elfDirectory.parent_path() / "BloodyRoar4.iso";
        std::error_code ec;
        if (!image.empty() && std::filesystem::exists(image, ec))
        {
            paths.cdImage = image;
            PS2Runtime::setIoPaths(paths);
            std::cerr << "[Bloody Roar 4] CD image: " << image.string() << std::endl;
        }
        else
        {
            std::cerr << "[Bloody Roar 4] CD image not found (" << image.string()
                      << "); files are read from the extracted disc only. Set PS2X_CD_IMAGE." << std::endl;
        }
    }

    void applyBloodyRoar4(PS2Runtime &runtime)
    {
        configureCdImage();

        // The game runs its own malloc over the whole SetupHeap range (0x41CF50 to the end of RAM).
        // Without a private runtime region, the runtime's GS packets (sceGsPutDispEnv...) landed on
        // the game's first heap block, a list of handlers walked by 0x0028D990, which then called 0.
        // 64 KB is plenty (the runtime uses a few hundred bytes there). The heap is tight: with 1 MB
        // reserved the game ran out loading Alice's second model (chr/ali/0010_ps2.dff, 0x39340)
        // whenever the CPU picked her, then retried a CD file that does not exist forever.
        ps2_game_overrides::setRuntimeHeapReserve(0x00010000u);
        ps2xAddEeIdleLoop(kWaitLoopBegin, kWaitLoopEnd);

        const std::string widescreen = envValue("PS2X_BR4_WIDESCREEN");
        g_widescreen = widescreen.empty() || widescreen[0] != '0';
        g_syncVHandler = runtime.lookupFunction(kSceGsSyncV);
        if (g_syncVHandler && g_widescreen)
        {
            runtime.replaceFunction(kSceGsSyncV, syncVHook);
            if (g_widescreen)
                std::cerr << "[Bloody Roar 4] widescreen 16:9 on" << std::endl;
        }

        // SDK functions ps2_analyzer did not name in this stripped ELF; left as guest code they spin
        // forever in "bind RPC until cd->server != 0" (no IOP server for their SID here).
        //   0x002D8730 _sceCdSearchFile  binds 0x80000597 (same as NBA Street V3's 0x004C6E60)
        //   0x002D8A48 sceCdSearchFile   28-byte wrapper of 0x002D8730, called by the game's file code
        struct Binding
        {
            uint32_t address;
            const char *handler;
        };
        static constexpr Binding kBindings[] = {
            {0x002D8730u, "sceCdSearchFile"},
            {0x002D8A48u, "sceCdSearchFile"},
        };
        for (const Binding &binding : kBindings)
        {
            if (!ps2_game_overrides::bindAddressHandler(runtime, binding.address, binding.handler))
                std::cerr << "[Bloody Roar 4] could not bind 0x" << std::hex << binding.address << std::dec
                          << " to " << binding.handler << std::endl;
        }

        // The mod's scePadRead jumps out of the ELF: replace it with the runtime's one first.
        if (!ps2_game_overrides::bindAddressHandler(runtime, kScePadRead, "scePadRead"))
        {
            std::cerr << "[Bloody Roar 4] could not bind scePadRead at 0x2DA7D0" << std::endl;
            return;
        }
        const std::string stick = envValue("PS2X_BR4_STICK");
        g_padReadHandler = runtime.lookupFunction(kScePadRead);
        if (g_padReadHandler && (stick.empty() || stick[0] != '0'))
            runtime.replaceFunction(kScePadRead, padReadWithStick);
    }
}

PS2_REGISTER_GAME_OVERRIDE("Bloody Roar 4 Analog Mod (SLES_518.77)", "SLES_518.77", 0x00100008u, 0u, applyBloodyRoar4)
