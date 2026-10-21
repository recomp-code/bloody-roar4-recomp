# Bloody Roar 4's Windows pack for the Recomp launcher: the runtime and the GS host, ready to play -- never the game.
# The player's ISO stays the player's: the launcher checks it and copies its ELF and MODULES out of it.
#   .\make_pack.ps1 -Version 1.0 [-Out <dir>] [-HostDir <folder with pcsx2-gsrunner.exe>]
# Writes <Out>\BR4_Windows.zip and <Out>\recomp-game.json (the manifest the launcher reads from the release).
param(
    [Parameter(Mandatory)][string]$Version,
    [string]$Out = '',
    [string]$HostDir = 'C:\DBZBT4Recomp\dist\DBZ_BT4_Windows\gshost', # the shared GS host (same pcsx2 tree as DBZ BT4)
    [string]$LauncherMin = '3.0',
    [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' })
)
$ErrorActionPreference = 'Stop'
$R = $Root
if (-not $Out) { $Out = "$R\dist" }
$rt = "$R\PS2Recomp\out\build\ps2xRuntime\Release"
$stage = "$Out\pack_stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force "$stage\runtime", "$stage\gshost\presets", "$stage\DLSS" | Out-Null

# runtime: the runner and the DLLs next to it (not the build's .lib / .map), plus the MSVC runtime
Copy-Item "$rt\ps2EntryRunner.exe" "$stage\runtime"
Get-ChildItem $rt -Filter *.dll | Copy-Item -Destination "$stage\runtime"
foreach ($crt in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
    if (Test-Path "$HostDir\$crt") { Copy-Item "$HostDir\$crt" "$stage\runtime" }
}

# GS host: the exe, its DLLs and resources; BR4's presets (the launcher copies them into gshost\ on first use)
Copy-Item "$HostDir\pcsx2-gsrunner.exe" "$stage\gshost"
Get-ChildItem $HostDir -Filter *.dll | Copy-Item -Destination "$stage\gshost"
Copy-Item -Recurse "$HostDir\resources" "$stage\gshost\resources"
New-Item -ItemType File "$stage\gshost\portable.ini" | Out-Null
foreach ($ini in 'br4.ini', 'br4_4x3.ini', 'br4_dlss.ini', 'br4_dlss_4x3.ini') { Copy-Item "$R\gshost\$ini" "$stage\gshost\presets" }
if (Test-Path "$HostDir\presets\nvngx_dlss.dll") { Copy-Item "$HostDir\presets\nvngx_dlss.dll" "$stage\gshost\presets" }
[IO.File]::WriteAllText("$stage\DLSS\LEEME.txt", "Pon aqui una nvngx_dlss.dll mas nueva (o arrastrala a la ventana de Recomp) y se usara desde la proxima partida.`r`n", [Text.Encoding]::ASCII)

# nothing of the game may be in the pack
$bad = Get-ChildItem $stage -Recurse -File | Where-Object { $_.Extension -in '.iso', '.elf', '.gs', '.map', '.lib' -or $_.Name -like 'SLES_*' -or $_.FullName -match '\\textures\\' }
if ($bad) { throw "the pack must not contain: $($bad.FullName -join ', ')" }

$zip = "$Out\BR4_Windows.zip"
if (Test-Path $zip) { Remove-Item $zip }
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
# entries written one by one with "/" (Windows PowerShell's CreateFromDirectory writes "\", which other systems
# take as part of the file name)
$zs = [IO.File]::Open($zip, [IO.FileMode]::CreateNew)
$za = New-Object IO.Compression.ZipArchive($zs, [IO.Compression.ZipArchiveMode]::Create)
foreach ($f in Get-ChildItem $stage -Recurse -File) {
    $name = $f.FullName.Substring($stage.Length + 1).Replace('\', '/')
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $f.FullName, $name, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
}
$za.Dispose(); $zs.Dispose()
Remove-Item -Recurse -Force $stage
$hash = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
$size = (Get-Item $zip).Length
$manifest = [ordered]@{ id = 'br4'; version = $Version; launcherMin = $LauncherMin
    packs = [ordered]@{ Windows = [ordered]@{ file = 'BR4_Windows.zip'; sha256 = $hash; size = $size } } }
[IO.File]::WriteAllText("$Out\recomp-game.json", ($manifest | ConvertTo-Json -Depth 5), (New-Object Text.UTF8Encoding($false)))
"BR4_Windows.zip {0:N1} MB sha256 {1}" -f ($size / 1MB), $hash
