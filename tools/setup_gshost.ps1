<#
  Assembles <Root>\gshost, the folder the GS host (PCSX2's pcsx2-gsrunner) runs from: exe + dependency DLLs +
  resources (PCSX2's own GameIndex) + this port's graphics presets (br4*.ini).
    setup_gshost.ps1                      from <Root>\pcsx2 after tools\build_pcsx2.cmd
    setup_gshost.ps1 -From <folder>       from a host that is already built from patches\pcsx2.patch (for example the
                                          DBZ BT4 port's gshost folder: it is the same pcsx2-gsrunner.exe)
  The player's graphics settings (gshost\br4*.ini) are never overwritten.
#>
param(
    [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' }),
    [string]$From = ''
)
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
$pcsx2 = Join-Path $Root 'pcsx2'
$out = Join-Path $Root 'gshost'
New-Item -ItemType Directory -Force $out | Out-Null

if ($From) {
    if (-not (Test-Path "$From\pcsx2-gsrunner.exe")) { throw "No pcsx2-gsrunner.exe in $From" }
    # Only the program and its libraries: no settings, logs, caches or files of another game.
    Get-ChildItem $From -File | Where-Object { $_.Extension -in '.exe', '.dll' -and $_.Name -notlike 'nvngx_*' -and $_.Name -ne 'dxgi.dll' } |
        ForEach-Object { Copy-Item $_.FullName $out -Force }
    if (Test-Path "$From\D3D12") { Copy-Item "$From\D3D12" $out -Recurse -Force }
    # PCSX2's own resources (GameIndex.yaml with the stock SLES-51877 entry): from the PCSX2 sources when they are here,
    # otherwise the host's (another port may ship a GameIndex with its own game's fixes; they do not touch SLES-51877).
    $resources = if (Test-Path "$pcsx2\bin\resources") { "$pcsx2\bin\resources" } else { "$From\resources" }
    Copy-Item $resources $out -Recurse -Force
} else {
    $exe = Join-Path $pcsx2 'build\pcsx2-gsrunner\pcsx2-gsrunner.exe'
    if (-not (Test-Path $exe)) { throw "Missing ${exe}: build it with tools\build_pcsx2.cmd" }
    Copy-Item $exe $out -Force
    $deps = if (Test-Path "$pcsx2\deps\bin") { "$pcsx2\deps\bin" } else { 'C:\NBAStreetRecomp\pcsx2\deps\bin' }
    Copy-Item "$deps\*.dll" $out -Force
    if (Test-Path "$deps\D3D12") { Copy-Item "$deps\D3D12" $out -Recurse -Force }
    Copy-Item "$pcsx2\bin\resources" $out -Recurse -Force
}
# Portable mode: PCSX2 keeps its settings, logs and caches next to the exe, not in Documents.
if (-not (Test-Path "$out\portable.ini")) { New-Item -ItemType File "$out\portable.ini" | Out-Null }
# Graphics presets: only when missing (the in-game menu, F1, saves the player's changes into them).
foreach ($ini in Get-ChildItem "$Repo\gshost" -Filter 'br4*.ini') {
    if (-not (Test-Path (Join-Path $out $ini.Name))) { Copy-Item $ini.FullName $out }
}
Write-Host "gshost ready in $out"
