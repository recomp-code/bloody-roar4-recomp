@echo off
rem Builds ps2EntryRunner.exe (the recompiled Bloody Roar 4) with at most %1 compilers at once (default 8): each unity
rem block of the game code needs several GB of RAM, so use about one compiler per 2.5 GB.
rem Log: logs\build_runner.log (ends with BUILD_EXIT=n). Exe: PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe
setlocal
call "%~dp0env.cmd"
set JOBS=%1
if "%JOBS%"=="" set JOBS=8
cmake --build "%W%\PS2Recomp\out\build" --config Release --target ps2EntryRunner -- /m:1 /p:CL_MPCount=%JOBS% /v:minimal > "%W%\logs\build_runner.log" 2>&1
set RC=%ERRORLEVEL%
echo BUILD_EXIT=%RC%>> "%W%\logs\build_runner.log"
exit /b %RC%
