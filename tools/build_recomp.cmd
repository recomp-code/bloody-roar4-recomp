@echo off
rem Builds the recompiler (ps2_recomp.exe) after tools\configure.cmd. Log: logs\build_recomp.log (ends with BUILD_EXIT=n)
setlocal
call "%~dp0env.cmd"
cmake --build "%W%\PS2Recomp\out\build" --config Release --target ps2_recomp --parallel -- /v:minimal > "%W%\logs\build_recomp.log" 2>&1
set RC=%ERRORLEVEL%
echo BUILD_EXIT=%RC%>> "%W%\logs\build_recomp.log"
exit /b %RC%
