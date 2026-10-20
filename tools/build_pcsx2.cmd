@echo off
rem Configures and builds the GS host (PCSX2's pcsx2-gsrunner, no Qt) with clang-cl, NVIDIA DLSS (NGX) and AMD FSR.
rem Sources: <W>\pcsx2 = PCSX2 d073d75 + patches\pcsx2.patch (tools\setup_sources.ps1 -WithPcsx2), dependencies built
rem once by tools\build_pcsx2_deps.bat, DLSS SDK in <W>\ext\DLSS (github.com/NVIDIA/DLSS; without it, FSR only).
rem Needs VS 2022 Build Tools (Windows SDK) and LLVM 20, Ninja, CMake, Python in <W>\tools (see docs\BUILDING.md).
rem   build_pcsx2.cmd              pcsx2-gsrunner
rem   build_pcsx2.cmd <targets>    other targets
setlocal
call "%~dp0env.cmd"
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1
set "PATH=%T%\llvm\clang+llvm-20.1.8-x86_64-pc-windows-msvc\bin;%T%\ninja;%T%\python;%T%\portablegit\cmd;%PATH%"
set "P=%W%\pcsx2"
set "WF=%W:\=/%"
rem PCSX2's dependencies: our own build, or the NBA Street V3 port's (the same versions) when ours is missing.
set "DEPS=%P%\deps"
if not exist "%DEPS%\bin" if exist "C:\NBAStreetRecomp\pcsx2\deps\bin" set "DEPS=C:\NBAStreetRecomp\pcsx2\deps"
if not exist "%P%\build\build.ninja" (
  cmake -S "%P%" -B "%P%\build" -G Ninja -DCMAKE_BUILD_TYPE=Release ^
    -DCMAKE_C_COMPILER=clang-cl -DCMAKE_CXX_COMPILER=clang-cl -DCMAKE_LINKER=lld-link ^
    -DCMAKE_PREFIX_PATH="%DEPS%" -DENABLE_QT_UI=OFF -DENABLE_GSRUNNER=ON -DENABLE_TESTS=OFF ^
    -DNBA_DLSS_SDK="%WF%/ext/DLSS" -DCMAKE_RC_COMPILER=llvm-rc || exit /b 2
)
if "%1"=="" (cmake --build "%P%\build" --target pcsx2-gsrunner || exit /b 3) else (cmake --build "%P%\build" --target %* || exit /b 3)
