@echo off
rem Analyses an ELF with headless Ghidra (R5900 processor) and exports config.toml + functions.csv with PS2Recomp's
rem ExportPS2Functions.java.   run_ghidra.cmd <elf> <config.toml> <functions.csv>
rem Needs JDK 21 and Ghidra 12.1.4 in <W>\tools (or C:\NBAStreetRecomp\tools), see tools\env.cmd.
setlocal
call "%~dp0env.cmd"
set "ELF=%~1"
set "TOML=%~2"
set "CSV=%~3"
if not exist "%W%\game\ghidra_project" mkdir "%W%\game\ghidra_project"
call "%GHIDRA%\support\analyzeHeadless.bat" "%W%\game\ghidra_project" BloodyRoar4 ^
  -import "%ELF%" -overwrite ^
  -processor r5900:LE:32:default -cspec default ^
  -scriptPath "%W%\PS2Recomp\ps2xRecomp\tools\ghidra" ^
  -postScript ExportPS2Functions.java "%TOML%" "%CSV%"
exit /b %ERRORLEVEL%
