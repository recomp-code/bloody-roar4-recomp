# Building by hand (Windows) and technical details

**English** | [Español](BUILDING.es.md)

Players only need the launcher: see the [README](../README.md). This page keeps the manual build, the
renderer, how the recompiler configuration was made, the patches and the test tools.

## Requirements

- Windows 10/11 x64, a GPU with Vulkan (Direct3D 12 for DLSS 5), ~25 GB free, 16 GB RAM recommended.
- **Visual Studio 2022 Build Tools** with "Desktop development with C++" (MSVC v143 + Windows SDK).
- The project folder is **`C:\BloodyRoar4Recomp`**; set the environment variable `BR4_ROOT` to use another
  one (every script and the launcher read it). This repository goes in `<project>\bloody-roar4-recomp`.
- Portable tools in `C:\BloodyRoar4Recomp\tools\`. Each one is also looked for in
  `C:\NBAStreetRecomp\tools\` (the NBA Street V3 port uses the same versions), so a PC that built that port
  needs nothing new. `tools\env.ps1` / `tools\env.cmd` pick them up.

| Folder | Tool | Needed for |
|---|---|---|
| `tools\mingit\` | [MinGit](https://github.com/git-for-windows/git/releases) (or Git on the PATH) | everything |
| `tools\cmake\cmake-4.4.4-windows-x86_64\` | [CMake 4.x](https://cmake.org/download/) (zip) | everything |
| `tools\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\` | [LLVM 20](https://github.com/llvm/llvm-project/releases) (clang-cl) | building the renderer |
| `tools\ninja\` | [Ninja](https://github.com/ninja-build/ninja/releases) | building the renderer |
| `tools\python\` | Embeddable Python 3 | the renderer's dependencies |
| `tools\portablegit\` | [PortableGit](https://github.com/git-for-windows/git/releases) (`bash`, `patch`) | the renderer's dependencies |
| `tools\7zip\` | [7-Zip](https://www.7-zip.org/) extra (`x64\7za.exe`) | the renderer's dependencies |
| `tools\jdk\jdk-21.0.12.1+1\`, `tools\ghidra\ghidra_12.1.4_PUBLIC\` | JDK 21, [Ghidra 12.1.4](https://github.com/NationalSecurityAgency/ghidra/releases) | only to re-derive the configuration |

*Prepare game* (`tools\install.ps1`) downloads CMake and MinGit by itself when they are missing.

## Folder layout

```
C:\BloodyRoar4Recomp\
  bloody-roar4-recomp\    this repository (or the release zip)
  game\BloodyRoar4.iso    your ISO (a hard link when it is on the same drive, otherwise a copy)
  game\iso\               the disc's files (SLES_518.77, SYSTEM.CNF, MODULES, FPACK, STR...); saves in game\iso\mc0
  game\config, overrides  copies of this repository's game\ (config.toml with the paths of this folder)
  game\output\            the C++ generated from your ELF (never committed)
  PS2Recomp\              ran-j/PS2Recomp 2c5fbb9 + patches\ps2recomp.patch; build in PS2Recomp\out\build
  pcsx2\, ext\DLSS\       PCSX2 d073d75 + patches\pcsx2.patch and NVIDIA's DLSS SDK (only to build the renderer)
  gshost\                 the renderer: pcsx2-gsrunner.exe, DLLs, resources, nvngx_dlss.dll, br4*.ini
  gshost_dlss5\           made by the launcher for DLSS 5 (gshost\ + ReShade as dxgi.dll + RenoDX + DLSSNR)
  DLSS\                   your own DLSS files (optional)
  tools\, logs\
```

## Building

**1. Your game.** Extract the ISO and put the image next to it (the game also reads disc sectors directly):
```bat
powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\iso_extract.ps1 -Iso "D:\BR4 Analog.iso" -Out C:\BloodyRoar4Recomp\game\iso
mklink /H C:\BloodyRoar4Recomp\game\BloodyRoar4.iso "D:\BR4 Analog.iso"     (or copy it)
```
`game\iso\SLES_518.77` must have SHA-256 `228548DAB8E4EFD03316C643F39210498691C24C9C39D65DF7715A74BF83DCDB`
(the Analog Stick Mod build): the function list in `game\config` was made from that exact file.

**2. PS2Recomp sources with the patch:**
```bat
powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\setup_sources.ps1
```

**3. Build the recompiler:**
```bat
bloody-roar4-recomp\tools\configure.cmd
bloody-roar4-recomp\tools\build_recomp.cmd
```
`configure.cmd`: Visual Studio 2022 x64, no studio/tests/analyzer, unity build of the game code, no console
window. If the NBA Street V3 port's build folder exists, its downloaded dependencies are reused.

**4. Generate the game code** from your ELF (a few minutes):
```bat
powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\generate_game.ps1
```
It copies `game\config` (rewriting the paths for `BR4_ROOT`), runs `ps2_recomp`, copies the `.cpp` files to
`PS2Recomp\ps2xRuntime\src\runner` and the headers to `ps2xRuntime\include`, runs the fixes on the generated
code (`fix_sqrt_s.ps1`, `fix_branch64.ps1`, `fix_cop0_count.ps1`) and adds the game's override.

**5. Build the game** (slow the first time: it is the whole game as C++):
```bat
bloody-roar4-recomp\tools\build_runner.cmd 8
```
The number is how many compilers run at once: about one per 2.5 GB of RAM. Output:
`PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe`. Logs go to `logs\`.

**6. The renderer:** see below.

**7. Play:** `bloody-roar4-recomp\Launcher.cmd` or `Play.cmd`.
`powershell -File bloody-roar4-recomp\Launcher.ps1 -DryRun [dlss|dlss5] [4:3] [window]` prints the
environment and command line PLAY would use, without starting or changing anything.

## The renderer

The GS host is PCSX2's `pcsx2-gsrunner` built from PCSX2 **`d073d75`** + `patches\pcsx2.patch`: the NBA Street
V3 live renderer plus the DBZ BT4 host changes. It is the same `pcsx2-gsrunner.exe` as the DBZ BT4 port's.
`tools\install.ps1` takes it, in this order, from:

1. `gshost-win64*.zip` next to the launcher (the release zip ships it; `tools\make_release.ps1` makes it);
2. `-GsHostDir <folder>` (any folder with that build, e.g. `C:\DBZBT4Recomp\gshost`;
   `tools\setup_gshost.ps1 -From <folder>` does the same by hand);
3. the DBZ BT4 port's `C:\DBZBT4Recomp\gshost`, when it is there;
4. `-GsHostUrl <zip url>`;
5. a build from source (`-BuildPcsx2`, or when nothing above exists):
   ```bat
   powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\setup_sources.ps1 -WithPcsx2
   bloody-roar4-recomp\tools\build_pcsx2_deps.bat
   bloody-roar4-recomp\tools\build_pcsx2.cmd
   powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\setup_gshost.ps1
   ```
   `-WithPcsx2` also clones NVIDIA's DLSS SDK into `ext\DLSS` (headers and import library; without it the host
   has AMD FSR only). The dependencies (SDL3, shaderc...) are built once; if the NBA Street V3 port's
   `C:\NBAStreetRecomp\pcsx2\deps` exists it is reused.

The resources come from PCSX2's own `bin\resources` (stock GameIndex entry for SLES-51877). NVIDIA's DLSS
runtime (`nvngx_dlss.dll`) is downloaded from NVIDIA's DLSS repository into `gshost\`, with a copy as
`nvngx_dlss.orig.dll` that the launcher puts back when *Use my own DLSS DLLs* is off.

Graphics presets (`gshost\br4*.ini`, copied from this repository only when missing; F1 in the game saves
into them):

| File | Picture |
|---|---|
| `br4.ini` / `br4_4x3.ini` | Vulkan, 6x (3840x2688 in PAL), 16x anisotropic, FXAA, CAS 50, DLSS/FSR when the window is larger than the image, HD textures on |
| `br4_dlss.ini` / `br4_dlss_4x3.ini` | the same at 2x (1280x1024 in PAL), upscaled by DLSS (FSR 1 without DLSS) |
| `dlss5\br4_dlss_dx12.ini` | Direct3D 12, 2x + DLSS; the neural pass on top (in `gshost_dlss5\`) |
| `dlss5\ReShade.ini` | ReShade + RenoDX DLSS 5 settings: F6 neural pass on/off, Home ReShade menu |

`NbaUpscaler` (0 = off, 1 = AMD FSR 1, 2 = NVIDIA DLSS) only acts while the internal resolution is smaller
than the window, so DLSS needs the 2x presets and a window larger than 1280x1024.

## Re-deriving the recompiler configuration

Not needed to build: `game\config` already has the result. To make it again from the ELF:
```bat
bloody-roar4-recomp\tools\ghidra_br4.cmd        :: ~3 min -> game\config\config.toml + functions.csv
PS2Recomp\out\build\ps2xAnalyzer\Release\ps2_analyzer.exe game\iso\SLES_518.77 game\config\config.analyzer.toml
powershell -File bloody-roar4-recomp\tools\fix_functions_csv.ps1 -Elf game\iso\SLES_518.77 -Csv game\config\functions.csv
powershell -File bloody-roar4-recomp\tools\find_gap_entries.ps1 -Elf game\iso\SLES_518.77 -Csv game\config\functions.csv -Out game\config\gap_entries.txt
powershell -File bloody-roar4-recomp\tools\merge_config.ps1
```
(`ps2_analyzer` needs a configure with `-DPS2X_BUILD_ANALYZER=ON`.) `merge_config.ps1` joins the Ghidra
export (`config.ghidra_original.toml`), the SCE stubs `ps2_analyzer` recognises and the gap entry points:
301 stubs and 680 entry points; it reproduces the committed `config.toml` byte for byte. `tools\decomp.cmd`
decompiles or finds references in the Ghidra project.

## Regenerating the patches

From the source trees, against the pinned commits (new untracked files included, generated code left out):
```bat
powershell -ExecutionPolicy Bypass -File bloody-roar4-recomp\tools\make_patches.ps1 -Pcsx2 C:\BloodyRoar4Recomp\pcsx2 -Check
```
`-Check` clones both trees into a temporary folder, checks out `2c5fbb9` / `d073d75` and verifies that each
patch applies cleanly (`git apply --check`); `-CheckOnly` only does that. Generated files never go into
`ps2recomp.patch`: `ps2xRuntime/src/runner/*`, `ps2xRuntime/include/ps2_recompiled_functions.h` and
`ps2_recompiled_stubs.h`.

## Testing

- `tools\run_test.ps1 -Seconds 90 -Shots 20,40,60 [-Ini br4_dlss.ini] [-Env @{PS2X_PAD_SCRIPT="30:START"}]`:
  starts the game in a window, asks the renderer for screenshots at those seconds
  (`logs\<tag>\shot_*.png`), then closes it. `PS2X_PAD_SCRIPT="<s>:<BUTTON>,..."` presses buttons by itself
  (e.g. to reach a fight) and `PS2X_FPS_LOG=1` logs the frame rate.
- `tools\capture_dlss5.ps1`: the same with the DLSS 5 renderer, capturing the window as shown on screen
  (with the neural pass, which the renderer's own screenshots do not include); `-Compare` presses F6 and
  captures with and without it.
- Logs: `logs\play.log`, `logs\play_err.log` (game), `gshost\logs\emulog.txt` (renderer).

## Environment variables

| Variable | Effect |
|---|---|
| `BR4_ROOT` | project folder (default `C:\BloodyRoar4Recomp`) |
| `PS2X_GS_LIVE=1` | draw with the live PCSX2 renderer (set by the launcher) |
| `PS2X_PAD_ANALOG=1` | the pad starts in analog mode (set by the launcher: the mod's ANALOG) |
| `PS2X_LIVE_SERIAL`, `PS2X_LIVE_TITLE` | `SLES-51877` (PCSX2's per-game fixes) and the window title |
| `PS2X_CD_IMAGE` | the disc image (default `game\BloodyRoar4.iso`) |
| `PS2X_GSHOST`, `PS2X_GSHOST_ARGS`, `PS2X_HOST_WINDOW` | renderer exe, its arguments (`-renderer vulkan -ini br4.ini -fullscreen`) and window size |
| `PS2X_BR4_WIDESCREEN=0` | original 4:3 picture (no widescreen patch) |
| `PS2X_BR4_STICK=0`, `PS2X_BR4_STICK_DEADZONE=n` | left stick to D-pad off / dead zone 0..127 (48) |
| `PS2X_PATH3_ONE_PACKET=0`, `PS2X_PATH3_VIA_DIRECT=0` | back to the old PATH3 behaviour (diagnostics) |
| `PS2X_IOP_RPC_LOG=n`, `PS2X_PATH3_TRACE=<s>`, `PS2X_GS_DUMP` | diagnostics: IOP RPC calls, PATH3 trace, GS dump |

## Contributing

Issues and pull requests are welcome. Read [PORTING_NOTES.md](PORTING_NOTES.md) first.

**Never** commit game files (ISO, ELF, extracted disc files, generated code in `game\output` or
`ps2xRuntime\src\runner`, saves) or binaries (renderer, NVIDIA DLSS, ReShade, add-ons). For changes to
PS2Recomp or PCSX2, regenerate the patches with `tools\make_patches.ps1 -Check`.
