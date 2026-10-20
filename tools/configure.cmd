@echo off
rem Configures <W>\PS2Recomp\out\build for Bloody Roar 4 (Visual Studio 2022 x64): recompiler + runtime, no
rem studio/tests/analyzer, unity build of the game code, no console window.
rem If the NBA Street V3 port's build folder exists, its already downloaded dependencies (FetchContent sources and the
rem FFmpeg zip) are reused instead of downloading them again.
rem Log: logs\cmake_configure.log (ends with CONFIGURE_EXIT=n)
setlocal
call "%~dp0env.cmd"
set "D=C:\NBAStreetRecomp\PS2Recomp\out\build\_deps"
set "FFZIP=C:/NBAStreetRecomp/PS2Recomp/out/build/ThirdParty/ffmpeg-prefix/src/ffmpeg-n7.1-241205-lgpl-amd64-shared.zip"
set REUSE=
if exist "%D%\elfio-src" set REUSE=-DPS2X_FFMPEG_LOCAL_ZIP=%FFZIP% ^
  -DFETCHCONTENT_SOURCE_DIR_ELFIO=%D%/elfio-src -DFETCHCONTENT_SOURCE_DIR_FMT=%D%/fmt-src ^
  -DFETCHCONTENT_SOURCE_DIR_IMGUI=%D%/imgui-src -DFETCHCONTENT_SOURCE_DIR_IMGUI_CLUB=%D%/imgui_club-src ^
  -DFETCHCONTENT_SOURCE_DIR_IMGUI_COLORTEXTEDIT=%D%/imgui_colortextedit-src ^
  -DFETCHCONTENT_SOURCE_DIR_IMGUI_FILE_DIALOG=%D%/imgui_file_dialog-src ^
  -DFETCHCONTENT_SOURCE_DIR_LIBDWARF=%D%/libdwarf-src -DFETCHCONTENT_SOURCE_DIR_NLOHMANN_JSON=%D%/nlohmann_json-src ^
  -DFETCHCONTENT_SOURCE_DIR_RABBITIZER=%D%/rabbitizer-src -DFETCHCONTENT_SOURCE_DIR_RAYLIB=%D%/raylib-src ^
  -DFETCHCONTENT_SOURCE_DIR_RLIMGUI=%D%/rlimgui-src -DFETCHCONTENT_SOURCE_DIR_SDL2=%D%/sdl2-src ^
  -DFETCHCONTENT_SOURCE_DIR_TOML11=%D%/toml11-src
cmake -S "%W%\PS2Recomp" -B "%W%\PS2Recomp\out\build" -G "Visual Studio 17 2022" -A x64 ^
  -DPS2X_BUILD_STUDIO=OFF -DPS2X_BUILD_TEST=OFF -DPS2X_BUILD_ANALYZER=OFF ^
  -DPS2X_ENABLE_RUNNER_UNITY_BUILD=ON -DPS2X_RUNNER_UNITY_BUILD_BATCH_SIZE=32 -DPS2X_ENABLE_RUNNER_PCH=ON ^
  -DPS2X_SHOW_WINDOWS_CONSOLE=OFF %REUSE% > "%W%\logs\cmake_configure.log" 2>&1
set RC=%ERRORLEVEL%
echo CONFIGURE_EXIT=%RC%>> "%W%\logs\cmake_configure.log"
exit /b %RC%
