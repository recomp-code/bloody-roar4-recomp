<#
  Generates the game's C++ code from YOUR copy of Bloody Roar 4 [Analog Stick Mod] (SLES-51877) and leaves it ready to
  compile. None of this goes into the repository: it is a translation of the game's executable.

  Needs:
    - <Root>\game\iso\SLES_518.77      (your disc extracted; install.ps1 does it)
    - the recompiler built              (tools\configure.cmd + tools\build_recomp.cmd, or install.ps1)

  Steps: this repository's recompiler config (function list from Ghidra + SCE stubs + gap entry points; no game code)
  -> ps2_recomp -> <Root>\game\output -> .cpp to ps2xRuntime\src\runner and headers to ps2xRuntime\include
  -> fixes on the generated code -> the game's override (game\overrides\bloody_roar4_overrides.cpp).
  Usage: powershell -ExecutionPolicy Bypass -File tools\generate_game.ps1 [-Root C:\BloodyRoar4Recomp]
#>
param([string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' }))
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$game = Join-Path $Root 'game'

$elf = Join-Path $game 'iso\SLES_518.77'
if (-not (Test-Path $elf)) { throw "Missing ${elf}: extract your ISO into $game\iso (tools\install.ps1 does it)" }

# Recompiler configuration. config.toml has the paths of the default folder (C:/BloodyRoar4Recomp/...); they are
# rewritten for <Root> so the project can live anywhere.
New-Item -ItemType Directory -Force "$game\config", "$game\output", "$game\overrides", "$Root\logs" | Out-Null
Copy-Item "$Repo\game\config\*" "$game\config\" -Force
Copy-Item "$Repo\game\overrides\*" "$game\overrides\" -Force
$rootSlash = $Root.TrimEnd('\').Replace('\', '/')
$rootBack = $Root.TrimEnd('\').Replace('\', '\\')
$toml = [IO.File]::ReadAllText("$game\config\config.toml")
$toml = $toml.Replace('C:/BloodyRoar4Recomp', $rootSlash).Replace('C:\\BloodyRoar4Recomp', $rootBack)
[IO.File]::WriteAllText("$game\config\config.toml", $toml, (New-Object Text.UTF8Encoding $false))

$recomp = Join-Path $Root 'PS2Recomp\out\build\ps2xRecomp\Release\ps2_recomp.exe'
if (-not (Test-Path $recomp)) { throw "Missing ${recomp}: build the recompiler (tools\configure.cmd + tools\build_recomp.cmd)" }
Write-Host "    recompiling the ELF (a few minutes)..."
& $recomp "$game\config\config.toml" | Out-File "$Root\logs\ps2_recomp.log" -Encoding utf8
if ($LASTEXITCODE) { throw "ps2_recomp failed ($LASTEXITCODE), see $Root\logs\ps2_recomp.log" }

$runner = Join-Path $Root 'PS2Recomp\ps2xRuntime\src\runner'
$include = Join-Path $Root 'PS2Recomp\ps2xRuntime\include'
Write-Host "    copying the generated code to $runner"
New-Item -ItemType Directory -Force $runner | Out-Null
Copy-Item "$game\output\*.cpp" $runner -Force
Copy-Item "$game\output\*.h" $include -Force

# Fixes on the generated code (idempotent). The patched recompiler already emits SQRT.S and the 64-bit branches
# correctly; they run anyway in case another recompiler build is used.
& "$PSScriptRoot\fix_sqrt_s.ps1" -Dir $runner
& "$PSScriptRoot\fix_branch64.ps1" -Dirs $runner
& "$PSScriptRoot\fix_cop0_count.ps1" -Dir $runner

Copy-Item "$Repo\game\overrides\bloody_roar4_overrides.cpp" $runner -Force
Write-Host "    done. Next: tools\build_runner.cmd (or the launcher's 'Prepare game')"
