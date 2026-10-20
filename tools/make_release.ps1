<#
  Makes the GitHub release zip (what a player downloads):
    BloodyRoar4-PC-<version>.zip = this repository (git ls-files: launcher, installer, patches, configuration, scripts)
                                   + gshost-win64.zip (PCSX2's GS host, already built from patches\pcsx2.patch, GPL)
  It contains NOTHING from the game: the game is compiled on the player's PC from their own ISO.
  gshost-win64.zip = pcsx2-gsrunner.exe + its DLLs + resources + portable.ini + the VC++ runtime. Left out: NVIDIA's
  nvngx_dlss*.dll (the installer downloads it from NVIDIA), ReShade/DLSS 5 files (the launcher takes them from DLSS 5
  Swapper or the player's DLSS folder), FFmpeg (PCSX2 only uses it for video capture), settings, logs and caches.
  Usage: tools\make_release.ps1 -Version 1.0 [-GsHost C:\BloodyRoar4Recomp\gshost] [-OutDir C:\BloodyRoar4Recomp\release]
#>
param(
    [Parameter(Mandatory)][string]$Version,
    [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' }),
    [string]$GsHost = '',
    [string]$OutDir = ''
)
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\env.ps1" -Root $Root
if (-not $GsHost) { $GsHost = Join-Path $Root 'gshost' }
if (-not $OutDir) { $OutDir = Join-Path $Root 'release' }
$name = "BloodyRoar4-PC-$Version"
$stage = Join-Path $OutDir $name
if (Test-Path $stage) { cmd /c rmdir /s /q "`"$stage`"" }
New-Item -ItemType Directory -Force $stage | Out-Null

# Only what is in git (never loose game files that could be lying in the folder).
$files = git -C $Repo ls-files
if ($LASTEXITCODE) { throw "git ls-files failed" }
foreach ($f in $files) {
    $dst = Join-Path $stage $f
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    Copy-Item (Join-Path $Repo $f) $dst
}

# The GS host.
if (-not (Test-Path "$GsHost\pcsx2-gsrunner.exe")) { throw "No pcsx2-gsrunner.exe in $GsHost" }
$hostStage = Join-Path $OutDir 'gshost-stage'
if (Test-Path $hostStage) { cmd /c rmdir /s /q "`"$hostStage`"" }
New-Item -ItemType Directory -Force $hostStage | Out-Null
Get-ChildItem $GsHost -File | Where-Object { $_.Extension -in '.exe', '.dll' -and $_.Name -notmatch '^(av[a-z]+|sw[a-z]+)-\d+\.dll$' -and
    $_.Name -notlike 'nvngx_*' -and $_.Name -ne 'dxgi.dll' } | Copy-Item -Destination $hostStage
if (Test-Path "$GsHost\D3D12") { Copy-Item "$GsHost\D3D12" $hostStage -Recurse }
Copy-Item "$GsHost\resources" $hostStage -Recurse
New-Item -ItemType File "$hostStage\portable.ini" | Out-Null
$crt = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT" -ErrorAction SilentlyContinue | Select-Object -Last 1
if ($crt) { foreach ($d in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') { Copy-Item "$($crt.FullName)\$d" $hostStage } }
else { Write-Warning 'VC++ runtime not found (VS 2022 Build Tools): players without it installed cannot start the host' }
Compress-Archive "$hostStage\*" (Join-Path $stage 'gshost-win64.zip') -Force
cmd /c rmdir /s /q "`"$hostStage`""

$zip = Join-Path $OutDir "$name.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive "$stage\*" $zip
cmd /c rmdir /s /q "`"$stage`""
Get-ChildItem $OutDir -Filter '*.zip' | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } }
