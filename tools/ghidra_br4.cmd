@echo off
rem Ghidra on game\iso\SLES_518.77 -> game\config\config.toml + functions.csv (~3 min; log in logs\ghidra.log).
rem Only needed to re-derive the configuration: the repository already has the result (game\config). Afterwards:
rem ps2_analyzer, fix_functions_csv.ps1, find_gap_entries.ps1 and merge_config.ps1 (see docs\BUILDING.md).
setlocal
call "%~dp0env.cmd"
if not exist "%W%\game\config" mkdir "%W%\game\config"
call "%~dp0run_ghidra.cmd" "%W%\game\iso\SLES_518.77" "%W%\game\config\config.toml" "%W%\game\config\functions.csv" > "%W%\logs\ghidra.log" 2>&1
set RC=%ERRORLEVEL%
echo GHIDRA_EXIT=%RC%>> "%W%\logs\ghidra.log"
exit /b %RC%
