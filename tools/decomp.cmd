@echo off
rem Decompiles / finds references in the Ghidra project of the ELF (made by ghidra_br4.cmd):
rem   decomp.cmd <output.txt> d:0xADDR x:0xADDR s:text ...     (d: decompile, x: references to, s: find string)
setlocal
call "%~dp0env.cmd"
call "%GHIDRA%\support\analyzeHeadless.bat" "%W%\game\ghidra_project" BloodyRoar4 ^
  -process -noanalysis -readOnly ^
  -scriptPath "%~dp0ghidra_scripts" -postScript Decomp.java %* > "%W%\logs\decomp_run.log" 2>&1
exit /b %ERRORLEVEL%
