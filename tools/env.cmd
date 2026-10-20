@echo off
rem Shared paths for the .cmd tools:  call "%~dp0env.cmd"
rem   W        = the project folder (%BR4_ROOT%, default C:\BloodyRoar4Recomp)
rem   PATH     += portable Git, CMake, JDK (<W>\tools first, then C:\NBAStreetRecomp\tools: same versions as the
rem               NBA Street V3 port, so a PC that built that port reuses them)
rem   GHIDRA   = Ghidra 12.1.4 folder (only for re-analysing the ELF)
if "%BR4_ROOT%"=="" set "BR4_ROOT=C:\BloodyRoar4Recomp"
set "W=%BR4_ROOT%"
set "T=%W%\tools"
set "TN=C:\NBAStreetRecomp\tools"
set "GITDIR=%T%\mingit\cmd"
if not exist "%GITDIR%\git.exe" if exist "%TN%\mingit\cmd\git.exe" set "GITDIR=%TN%\mingit\cmd"
set "CMAKEDIR=%T%\cmake\cmake-4.4.4-windows-x86_64\bin"
if not exist "%CMAKEDIR%\cmake.exe" if exist "%TN%\cmake\cmake-4.4.4-windows-x86_64\bin\cmake.exe" set "CMAKEDIR=%TN%\cmake\cmake-4.4.4-windows-x86_64\bin"
set "JAVA_HOME=%T%\jdk\jdk-21.0.12.1+1"
if not exist "%JAVA_HOME%\bin\java.exe" if exist "%TN%\jdk\jdk-21.0.12.1+1\bin\java.exe" set "JAVA_HOME=%TN%\jdk\jdk-21.0.12.1+1"
set "GHIDRA=%T%\ghidra\ghidra_12.1.4_PUBLIC"
if not exist "%GHIDRA%\support\analyzeHeadless.bat" if exist "%TN%\ghidra\ghidra_12.1.4_PUBLIC\support\analyzeHeadless.bat" set "GHIDRA=%TN%\ghidra\ghidra_12.1.4_PUBLIC"
set "PATH=%GITDIR%;%CMAKEDIR%;%JAVA_HOME%\bin;%PATH%"
if not exist "%W%\logs" mkdir "%W%\logs"
