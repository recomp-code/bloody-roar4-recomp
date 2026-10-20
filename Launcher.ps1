<#
  Bloody Roar 4 [Analog Stick Mod] PC launcher: pick your ISO, prepare the game once, choose the picture, play.
  Opened by Launcher.cmd. Preparing (compiling the game on your PC) only happens once.
    Launcher.ps1                         the launcher window
    Launcher.ps1 -Play [options]         starts the game with the saved settings, no window (Play.cmd)
    Launcher.ps1 -DryRun [options]       prints what PLAY would run (environment, command line, files it would copy)
                                         and changes nothing
  Options (override the saved settings for this start): 6x | dlss | dlss5, 16:9 | 4:3, window | fullscreen
  The project folder is C:\BloodyRoar4Recomp (or %BR4_ROOT%).
#>
param(
    [switch]$Play,
    [switch]$DryRun,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Options = @()
)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Root = if ($env:BR4_ROOT) { $env:BR4_ROOT.TrimEnd('\') } else { 'C:\BloodyRoar4Recomp' }
$Repo = $PSScriptRoot
$GameExe = "$Root\PS2Recomp\out\build\ps2xRuntime\Release\ps2EntryRunner.exe"
$Elf = "$Root\game\iso\SLES_518.77"
$GsHost = "$Root\gshost"
$GsHost5 = "$Root\gshost_dlss5"
$DlssDir = "$Root\DLSS"
$SettingsFile = Join-Path $env:APPDATA 'BloodyRoar4Launcher.json'

# Picture presets. Ini = the GS host's settings file (gshost\<ini>.ini, "_4x3" for the original aspect ratio).
$Presets = @(
    @{ Key = '6x';    Ini = 'br4';           Renderer = 'vulkan'; Text = '6x supersampling - sharpest picture, any GPU (Vulkan)' },
    @{ Key = 'dlss';  Ini = 'br4_dlss';      Renderer = 'vulkan'; Text = 'NVIDIA DLSS - 2x internal upscaled by DLSS (RTX)' },
    @{ Key = 'dlss5'; Ini = 'br4_dlss_dx12'; Renderer = 'dx12';   Text = 'DLSS 5 - DLSS + NVIDIA neural pass (experimental, RTX)' }
)
$QualityDlss = 1
$QualityDlss5 = 2

# ---------------------------------------------------------------- launcher settings
# First start: everything on (16:9, fullscreen, the 6x preset, the player's own DLSS DLLs when there are any).
$settings = @{ Iso = ''; Quality = 0; Widescreen = $true; Fullscreen = $true; OwnDlss = $true }
try {
    if (Test-Path $SettingsFile) {
        $loaded = Get-Content $SettingsFile -Raw | ConvertFrom-Json
        if ($loaded.Iso) { $settings.Iso = [string]$loaded.Iso }
        if ($null -ne $loaded.Quality -and [int]$loaded.Quality -ge 0 -and [int]$loaded.Quality -lt $Presets.Count) { $settings.Quality = [int]$loaded.Quality }
        foreach ($k in 'Widescreen', 'Fullscreen', 'OwnDlss') { if ($null -ne $loaded.$k) { $settings[$k] = [bool]$loaded.$k } }
    }
} catch {}
function Save-Settings { if (-not $DryRun) { try { $settings | ConvertTo-Json | Set-Content $SettingsFile } catch {} } }

function Show-Message($text, $title = 'Bloody Roar 4', $icon = 'Information') {
    if ($DryRun) { Write-Host "[$title] $text" } else { [void][Windows.Forms.MessageBox]::Show($text, $title, 'OK', $icon) }
}

# ---------------------------------------------------------------- DLSS files
# DLSS\ in the project folder (any subfolder, any file name): files are recognised by their version info and the newest
# of each kind wins. Kinds: NVIDIA DLSS super resolution (nvngx_dlss.dll), NVIDIA DLSSNR (DLSS 5's neural pass),
# ReShade 64-bit and the RenoDX DLSS 5 add-on. What DLSS\ lacks comes from the game (DLSS) or from DLSS 5 Swapper.
function Test-X64($path) {
    # PE machine type x64 (0x8664): the DLSS SDK also has ARM64 builds of the same DLLs, which would not load.
    try {
        $fs = [IO.File]::Open($path, 'Open', 'Read', 'ReadWrite')
        try {
            $r = New-Object IO.BinaryReader $fs
            $fs.Position = 0x3C; $fs.Position = $r.ReadInt32() + 4
            return $r.ReadUInt16() -eq 0x8664
        } finally { $fs.Dispose() }
    } catch { return $false }
}
function Get-DlssKind($path) {
    try {
        $name = [IO.Path]::GetFileName($path).ToLowerInvariant()
        if ($name.EndsWith('.addon64')) { if ($name.Contains('dlss5')) { return 'Addon' } else { return '' } }
        if (-not $name.EndsWith('.dll') -or -not (Test-X64 $path)) { return '' }
        $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($path)
        $product = [string]$v.ProductName; $description = [string]$v.FileDescription
        if ($product -match 'Deep Learning SuperSampling') { return 'SuperRes' }
        if ($product -eq 'NVIDIA DLSSNR') { return 'Neural' }
        if ($product -eq 'ReShade' -and $description -match '64-bit') { return 'ReShade' }
    } catch {}
    return ''
}
function Get-FileVer($path) {
    try { $v = [Diagnostics.FileVersionInfo]::GetVersionInfo($path); return New-Object Version $v.FileMajorPart, $v.FileMinorPart, $v.FileBuildPart, $v.FilePrivatePart }
    catch { return New-Object Version 0, 0 }
}
function Get-VersionText($path) { $v = Get-FileVer $path; if ($v.Revision -gt 0) { $v.ToString(4) } else { $v.ToString(3) } }
# The newest file of that kind in DLSS\, or $null.
function Get-UserDlss($kind) {
    if (-not (Test-Path $DlssDir)) { return $null }
    $best = $null
    foreach ($f in Get-ChildItem $DlssDir -Recurse -File -Include *.dll, *.addon64 -ErrorAction SilentlyContinue) {
        if ((Get-DlssKind $f.FullName) -eq $kind -and (-not $best -or (Get-FileVer $f.FullName) -gt (Get-FileVer $best))) { $best = $f.FullName }
    }
    return $best
}
function Get-SwapperFile($relative) {
    $p = Join-Path $env:LOCALAPPDATA "Programs\DLSS 5 Swapper\resources\payload\$relative"
    if (Test-Path $p) { return $p } else { return $null }
}
# ReShade, the RenoDX DLSS 5 add-on and nvngx_dlssnr.dll (DLSS\ first, then DLSS 5 Swapper), or $null if one is missing.
function Get-Dlss5Parts {
    $reshade = Get-UserDlss 'ReShade'; if (-not $reshade) { $reshade = Get-SwapperFile 'reshade-vulkan\ReShade64.dll' }
    $addon = Get-UserDlss 'Addon'; if (-not $addon) { $addon = Get-SwapperFile 'renodx-dlss5.addon64' }
    $neural = Get-UserDlss 'Neural'; if (-not $neural) { $neural = Get-SwapperFile 'streamline\nvngx_dlssnr.dll' }
    if ($reshade -and $addon -and $neural) { return @($reshade, $addon, $neural) } else { return $null }
}
# The DLSS the game will use: DLSS\'s newest nvngx_dlss.dll (if "use my own" is on), else the one the game came with.
function Get-SuperResDll($own) {
    if ($own) { $user = Get-UserDlss 'SuperRes'; if ($user) { return $user } }
    if (Test-Path "$GsHost\nvngx_dlss.orig.dll") { return "$GsHost\nvngx_dlss.orig.dll" }
    if (Test-Path "$GsHost\nvngx_dlss.dll") { return "$GsHost\nvngx_dlss.dll" }
    return $null
}

# ---------------------------------------------------------------- files for the GS host
function Copy-IfChanged($src, $dst) {
    $a = Get-Item $src; $b = Get-Item $dst -ErrorAction SilentlyContinue
    if ($b -and $a.Length -eq $b.Length -and $a.LastWriteTimeUtc -eq $b.LastWriteTimeUtc) { return }
    if ($DryRun) { Write-Host "  would copy $src -> $dst"; return }
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    [IO.File]::Copy($src, $dst, $true)
}
function Copy-Tree($src, $dst) {
    foreach ($f in Get-ChildItem $src -Recurse -File) { Copy-IfChanged $f.FullName (Join-Path $dst $f.FullName.Substring($src.Length + 1)) }
}
# Puts the chosen nvngx_dlss.dll next to the normal host (gshost_dlss5\ copies it from there).
function Set-SuperResDll($own) {
    $src = Get-SuperResDll $own
    $dst = "$GsHost\nvngx_dlss.dll"
    if ($src -and -not [string]::Equals([IO.Path]::GetFullPath($src), [IO.Path]::GetFullPath($dst), 'OrdinalIgnoreCase')) { Copy-IfChanged $src $dst }
}
# The host's settings file for this preset and aspect ratio: copied from the repository the first time (F1 in the game
# saves the player's changes into it). The 4:3 DLSS 5 file is made from the 16:9 one.
function Initialize-Ini($dir, $name, $template) {
    $path = Join-Path $dir $name
    if (Test-Path $path) { return }
    if ($DryRun) { Write-Host "  would create $path"; return }
    New-Item -ItemType Directory -Force $dir | Out-Null
    if (Test-Path $template) { Copy-Item $template $path; return }
    $wide = Join-Path $dir ($name -replace '_4x3\.ini$', '.ini')
    if (-not (Test-Path $wide)) { $wide = Join-Path "$Repo\gshost\dlss5" ($name -replace '_4x3\.ini$', '.ini') }
    (Get-Content $wide) -replace '^AspectRatio = .*$', 'AspectRatio = 4:3' | Set-Content $path -Encoding ascii
}
# DLSS 5: a copy of gshost\ with ReShade (as dxgi.dll), the RenoDX DLSS 5 add-on and NVIDIA's nvngx_dlssnr.dll, so the
# normal host never loads ReShade. Kept up to date on every start (only changed files are copied).
function Initialize-Dlss5Host {
    $parts = Get-Dlss5Parts
    if (-not $parts) { return $null }
    foreach ($f in Get-ChildItem $GsHost -File | Where-Object { $_.Extension -in '.exe', '.dll' -and $_.Name -ne 'dxgi.dll' -and $_.Name -notlike '*.orig.dll' }) {
        Copy-IfChanged $f.FullName (Join-Path $GsHost5 $f.Name)
    }
    if (Test-Path "$GsHost\resources") { Copy-Tree "$GsHost\resources" "$GsHost5\resources" }
    if (-not (Test-Path "$GsHost5\portable.ini") -and -not $DryRun) { New-Item -ItemType Directory -Force $GsHost5 | Out-Null; New-Item -ItemType File "$GsHost5\portable.ini" | Out-Null }
    Copy-IfChanged $parts[0] "$GsHost5\dxgi.dll"
    Copy-IfChanged $parts[1] "$GsHost5\renodx-dlss5.addon64"
    Copy-IfChanged $parts[2] "$GsHost5\nvngx_dlssnr.dll"
    if (-not (Test-Path "$GsHost5\ReShade.ini")) {
        if ($DryRun) { Write-Host "  would create $GsHost5\ReShade.ini" } else { Copy-Item "$Repo\gshost\dlss5\ReShade.ini" $GsHost5 }
    }
    return $GsHost5
}

# ---------------------------------------------------------------- start the game
function Get-CdImage {
    if ($settings.Iso -and (Test-Path $settings.Iso)) { return $settings.Iso }
    if (Test-Path "$Root\game\BloodyRoar4.iso") { return "$Root\game\BloodyRoar4.iso" }
    return $null
}
function Test-Ready { (Test-Path $GameExe) -and (Test-Path "$GsHost\pcsx2-gsrunner.exe") -and (Test-Path $Elf) -and [bool](Get-CdImage) }

# Window mode: 16:9, up to 1920x1080 and 90% of the screen (DLSS only runs while the window is larger than the 2x image).
function Get-WindowSize {
    $wa = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $w = [math]::Min(1920, [int]($wa.Width * 0.9)); $h = [int]($w * 9 / 16)
    if ($h -gt [int]($wa.Height * 0.9)) { $h = [int]($wa.Height * 0.9); $w = [int]($h * 16 / 9) }
    return "${w}x$h"
}

function Start-Game([int]$quality, [bool]$widescreen, [bool]$fullscreen, [bool]$ownDlss) {
    if (-not (Test-Ready)) {
        Show-Message "The game is not prepared yet. Open Launcher.cmd, choose your ISO and press 'Prepare game'." 'Bloody Roar 4' 'Warning'
        return $false
    }
    if ($DryRun) { Write-Host "Dry run: nothing is started or changed. Project folder: $Root" }
    try { Set-SuperResDll $ownDlss }
    catch { Show-Message "Could not put your DLSS DLL in place (is the game still running?):`n$($_.Exception.Message)" 'NVIDIA DLSS' }
    $hostDir = $GsHost
    if ($quality -eq $QualityDlss5) {
        try { $hostDir = Initialize-Dlss5Host } catch { $hostDir = $null; Show-Message "Could not prepare DLSS 5: $($_.Exception.Message)" 'DLSS 5' }
        if (-not $hostDir) {
            Show-Message 'DLSS 5 needs an NVIDIA RTX GPU and DLSS 5 Swapper installed (or ReShade64.dll, renodx-dlss5.addon64 and nvngx_dlssnr.dll in the DLSS folder). Playing with normal DLSS.' 'DLSS 5'
            $quality = $QualityDlss
            $hostDir = $GsHost
        }
    }
    $preset = $Presets[$quality]
    $ini = $preset.Ini + $(if ($widescreen) { '' } else { '_4x3' }) + '.ini'
    $template = if ($quality -eq $QualityDlss5) { "$Repo\gshost\dlss5\$ini" } else { "$Repo\gshost\$ini" }
    Initialize-Ini $hostDir $ini $template

    $cdImage = Get-CdImage
    $vars = [ordered]@{
        PS2X_GS_LIVE         = '1'
        PS2X_PAD_ANALOG      = '1'                 # the mod's ANALOG mode is always on
        PS2X_LIVE_SERIAL     = 'SLES-51877'        # PCSX2's per-game GS fixes for this disc
        PS2X_LIVE_TITLE      = 'Bloody Roar 4'
        PS2X_CD_IMAGE        = $cdImage
        PS2X_GSHOST          = "$hostDir\pcsx2-gsrunner.exe"
        PS2X_GSHOST_ARGS     = "-renderer $($preset.Renderer) -ini $ini" + $(if ($fullscreen) { ' -fullscreen' } else { '' })
        PS2X_HOST_WINDOW     = Get-WindowSize
        PS2X_BR4_WIDESCREEN  = $(if ($widescreen) { '1' } else { '0' })
    }
    $logs = "$Root\logs"
    $arguments = "`"$Elf`""
    if ($DryRun) {
        Write-Host "Preset: $($preset.Text)$(if ($widescreen) { ', 16:9' } else { ', 4:3' })$(if ($fullscreen) { ', fullscreen' } else { ', window' })"
        foreach ($k in $vars.Keys) { Write-Host ("  set {0}={1}" -f $k, $vars[$k]) }
        Write-Host "  cd /d `"$Root\game\iso`""
        Write-Host "  `"$GameExe`" $arguments > `"$logs\play.log`" 2> `"$logs\play_err.log`""
        return $true
    }
    foreach ($k in $vars.Keys) { Set-Item "env:$k" $vars[$k] }
    New-Item -ItemType Directory -Force $logs | Out-Null
    try {
        Start-Process $GameExe -ArgumentList $arguments -WorkingDirectory "$Root\game\iso" -WindowStyle Hidden `
            -RedirectStandardOutput "$logs\play.log" -RedirectStandardError "$logs\play_err.log"
    } catch {
        Show-Message "Could not start the game: $($_.Exception.Message)" 'Bloody Roar 4' 'Error'
        return $false
    }
    return $true
}

# ---------------------------------------------------------------- Play.cmd / dry run: no window
if ($Play -or $DryRun) {
    $quality = $settings.Quality; $wide = $settings.Widescreen; $full = $settings.Fullscreen
    foreach ($o in $Options) {
        switch ($o.ToLowerInvariant()) {
            '6x' { $quality = 0 } 'dlss' { $quality = $QualityDlss } 'dlss5' { $quality = $QualityDlss5 }
            '16:9' { $wide = $true } '4:3' { $wide = $false }
            'window' { $full = $false } 'windowed' { $full = $false } 'fullscreen' { $full = $true }
            default { Show-Message "Unknown option '$o' (use 6x, dlss, dlss5, 16:9, 4:3, window, fullscreen)" }
        }
    }
    if (Start-Game $quality $wide $full $settings.OwnDlss) { exit 0 } else { exit 1 }
}

# ---------------------------------------------------------------- window
[System.Windows.Forms.Application]::EnableVisualStyles()
$form = New-Object Windows.Forms.Form
$form.Text = 'Bloody Roar 4 - PC'
$form.Size = New-Object Drawing.Size(540, 620)
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object Drawing.Font('Segoe UI', 10)

$title = New-Object Windows.Forms.Label
$title.Text = 'Bloody Roar 4'
$title.Font = New-Object Drawing.Font('Segoe UI', 18, [Drawing.FontStyle]::Bold)
$title.Location = '20,10'; $title.AutoSize = $true
$form.Controls.Add($title)
$subtitle = New-Object Windows.Forms.Label
$subtitle.Text = 'Analog Stick Mod - PAL SLES-51877 - native PC port'
$subtitle.Location = '22,48'; $subtitle.AutoSize = $true; $subtitle.ForeColor = [Drawing.Color]::DimGray
$form.Controls.Add($subtitle)

$isoLabel = New-Object Windows.Forms.Label
$isoLabel.Text = 'Your game disc image (Bloody Roar 4 [Analog Stick Mod] ISO, SLES-51877):'
$isoLabel.Location = '20,80'; $isoLabel.AutoSize = $true
$form.Controls.Add($isoLabel)

$isoBox = New-Object Windows.Forms.TextBox
$isoBox.Location = '20,104'; $isoBox.Size = '390,26'; $isoBox.Text = $settings.Iso
$form.Controls.Add($isoBox)

$browse = New-Object Windows.Forms.Button
$browse.Text = 'Browse...'; $browse.Location = '418,102'; $browse.Size = '90,30'
$browse.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Choose your Bloody Roar 4 [Analog Stick Mod] ISO'
    $dialog.Filter = 'Disc image (*.iso)|*.iso|All files (*.*)|*.*'
    if ($settings.Iso) { try { $dialog.InitialDirectory = Split-Path $settings.Iso } catch {} }
    if ($dialog.ShowDialog() -eq 'OK') { $isoBox.Text = $dialog.FileName; $settings.Iso = $dialog.FileName; Save-Settings; Update-Status }
})
$form.Controls.Add($browse)

$status = New-Object Windows.Forms.Label
$status.Location = '20,140'; $status.Size = '490,44'
$form.Controls.Add($status)

# Picture
$group = New-Object Windows.Forms.GroupBox
$group.Text = 'Picture'; $group.Location = '20,188'; $group.Size = '488,250'
$form.Controls.Add($group)

$qualityLabel = New-Object Windows.Forms.Label
$qualityLabel.Text = 'Quality:'; $qualityLabel.Location = '12,30'; $qualityLabel.AutoSize = $true
$group.Controls.Add($qualityLabel)
$qualityBox = New-Object Windows.Forms.ComboBox
$qualityBox.DropDownStyle = 'DropDownList'; $qualityBox.Location = '80,26'; $qualityBox.Size = '396,26'
$Presets | ForEach-Object { [void]$qualityBox.Items.Add($_.Text) }
$group.Controls.Add($qualityBox)

$wideBox = New-Object Windows.Forms.CheckBox
$wideBox.Text = 'Widescreen 16:9 (off = the original 4:3 picture)'; $wideBox.Location = '12,62'; $wideBox.AutoSize = $true
$wideBox.Checked = $settings.Widescreen
$group.Controls.Add($wideBox)
$fullBox = New-Object Windows.Forms.CheckBox
$fullBox.Text = 'Fullscreen'; $fullBox.Location = '12,90'; $fullBox.AutoSize = $true
$fullBox.Checked = $settings.Fullscreen
$group.Controls.Add($fullBox)
$ownBox = New-Object Windows.Forms.CheckBox
$ownBox.Text = 'Use my own DLSS DLLs (nvngx_dlss.dll... in the DLSS folder)'; $ownBox.Location = '12,118'; $ownBox.AutoSize = $true
$ownBox.Checked = $settings.OwnDlss
$group.Controls.Add($ownBox)

$dlssInfo = New-Object Windows.Forms.Label
$dlssInfo.Location = '12,148'; $dlssInfo.Size = '466,56'; $dlssInfo.ForeColor = [Drawing.Color]::DimGray
$group.Controls.Add($dlssInfo)
$addDlss = New-Object Windows.Forms.Button
$addDlss.Text = 'Add DLSS files...'; $addDlss.Location = '12,208'; $addDlss.Size = '200,30'
$group.Controls.Add($addDlss)
$openDlss = New-Object Windows.Forms.Button
$openDlss.Text = 'Open DLSS folder'; $openDlss.Location = '222,208'; $openDlss.Size = '180,30'
$group.Controls.Add($openDlss)

$prepare = New-Object Windows.Forms.Button
$prepare.Text = 'Prepare game'; $prepare.Location = '20,450'; $prepare.Size = '150,44'
$form.Controls.Add($prepare)

$playButton = New-Object Windows.Forms.Button
$playButton.Text = 'PLAY'; $playButton.Location = '358,450'; $playButton.Size = '150,44'
$playButton.Font = New-Object Drawing.Font('Segoe UI', 12, [Drawing.FontStyle]::Bold)
$form.Controls.Add($playButton)

$help = New-Object Windows.Forms.Label
$help.Text = "In game: F1 or hold START = graphics menu. Alt+Enter = window/fullscreen.`nDLSS 5: F6 = neural pass on/off, Home = ReShade menu."
$help.Location = '20,506'; $help.Size = '490,44'; $help.ForeColor = [Drawing.Color]::DimGray
$form.Controls.Add($help)

function Update-Dlss {
    $own = $ownBox.Checked
    $sr = Get-SuperResDll $own
    $mine = $own -and [bool](Get-UserDlss 'SuperRes')
    $parts = Get-Dlss5Parts
    $text = if ($sr) { "NVIDIA DLSS $(Get-VersionText $sr) ($(if ($mine) { 'yours, DLSS folder' } else { 'included' }))" } else { 'NVIDIA DLSS: not installed yet (RTX only)' }
    $text += "   DLSS 5: " + $(if ($parts) { "ready (DLSSNR $(Get-VersionText $parts[2]))" } else { 'not available' })
    if (-not $parts) { $text += "`nDLSS 5 needs DLSS 5 Swapper, or nvngx_dlssnr.dll, ReShade64.dll and renodx-dlss5.addon64 in the DLSS folder." }
    else { $text += "`nDLSS folder: $DlssDir" }
    $dlssInfo.Text = $text
    $qualityBox.Items[$QualityDlss5] = if ($parts) { $Presets[$QualityDlss5].Text } else { 'DLSS 5 - needs DLSS 5 Swapper or its files in the DLSS folder (RTX)' }
}

# Copies the chosen files into DLSS\ (recognised by their version info; anything else is refused).
function Add-DlssFiles([string[]]$files) {
    $added = 0; $skipped = @()
    foreach ($f in $files) {
        $kind = Get-DlssKind $f
        if (-not $kind) { $skipped += [IO.Path]::GetFileName($f); continue }
        if ($kind -eq 'SuperRes') {
            # Any DLSS build can be used (developers test their own), but one that is not NVIDIA's signed runtime
            # is only added after a warning.
            $sig = Get-AuthenticodeSignature $f
            if ($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Subject -notmatch 'O=NVIDIA Corporation') {
                $answer = [Windows.Forms.MessageBox]::Show("$([IO.Path]::GetFileName($f)) is not signed by NVIDIA, or it was modified after signing (signature: $($sig.Status)).`n`nIf DLSS does not work with it, remove it from the DLSS folder.`n`nUse it anyway?", 'NVIDIA DLSS', 'YesNo', 'Warning')
                if ($answer -ne 'Yes') { continue }
            }
        }
        try {
            New-Item -ItemType Directory -Force $DlssDir | Out-Null
            Copy-Item $f (Join-Path $DlssDir ([IO.Path]::GetFileName($f))) -Force
            $added++
        } catch { $skipped += "$([IO.Path]::GetFileName($f)) ($($_.Exception.Message))" }
    }
    if ($added) { $ownBox.Checked = $true }
    Update-Dlss
    if ($skipped) {
        Show-Message ("Not a DLSS file the game uses:`n" + ($skipped -join "`n") + "`n`nUsable: nvngx_dlss.dll (DLSS) and, for DLSS 5, nvngx_dlssnr.dll, ReShade64.dll and renodx-dlss5.addon64.") 'DLSS'
    } elseif ($added) {
        Show-Message "Done. $($dlssInfo.Text)" 'DLSS'
    }
}
$addDlss.Add_Click({
    $dialog = New-Object Windows.Forms.OpenFileDialog
    $dialog.Title = 'Choose DLSS files (nvngx_dlss.dll; for DLSS 5 also nvngx_dlssnr.dll, ReShade64.dll, renodx-dlss5.addon64)'
    $dialog.Filter = 'DLSS files (*.dll;*.addon64)|*.dll;*.addon64'
    $dialog.Multiselect = $true
    if ($dialog.ShowDialog() -eq 'OK') { Add-DlssFiles $dialog.FileNames }
})
$openDlss.Add_Click({
    New-Item -ItemType Directory -Force $DlssDir | Out-Null
    Start-Process explorer.exe "`"$DlssDir`""
})
$ownBox.Add_CheckedChanged({ Update-Dlss })

function Save-Options {
    $settings.Quality = [math]::Max(0, $qualityBox.SelectedIndex)
    $settings.Widescreen = $wideBox.Checked
    $settings.Fullscreen = $fullBox.Checked
    $settings.OwnDlss = $ownBox.Checked
    if ($isoBox.Text.Trim()) { $settings.Iso = $isoBox.Text.Trim() }
    Save-Settings
}

function Update-Status {
    $ready = Test-Ready
    $playButton.Enabled = $ready
    if ($ready) {
        $status.Text = 'The game is ready. Press PLAY.'
        $status.ForeColor = [Drawing.Color]::DarkGreen
        $prepare.Text = 'Repair'
    } elseif ((Test-Path $GameExe) -and (Test-Path $Elf) -and -not (Get-CdImage)) {
        $status.Text = 'Your ISO is not where it was: choose it again (Browse...).'
        $status.ForeColor = [Drawing.Color]::DarkOrange
    } else {
        $status.Text = "First time: choose your ISO and press 'Prepare game'. It builds the game on your PC (a few GB of downloads; the first time can take about an hour)."
        $status.ForeColor = [Drawing.Color]::DarkOrange
        $prepare.Text = 'Prepare game'
    }
}

$prepare.Add_Click({
    $iso = $isoBox.Text.Trim()
    if (-not (Test-Path $Elf) -and -not ($iso -and (Test-Path $iso))) {
        Show-Message 'Choose your Bloody Roar 4 [Analog Stick Mod] ISO first (Browse...).'
        return
    }
    Save-Options
    $arguments = @('-NoExit', '-ExecutionPolicy', 'Bypass', '-File', "`"$Repo\tools\install.ps1`"", '-Root', "`"$Root`"")
    if ($iso) { $arguments += @('-Iso', "`"$iso`"") }
    $form.Enabled = $false
    $status.Text = 'Preparing... progress is shown in the other window. Close it when it says "Done".'
    $proc = Start-Process powershell -ArgumentList $arguments -PassThru
    while (-not $proc.HasExited) { [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 200 }
    $form.Enabled = $true
    Update-Dlss
    Update-Status
})

$playButton.Add_Click({
    Save-Options
    if (Start-Game $qualityBox.SelectedIndex $wideBox.Checked $fullBox.Checked $ownBox.Checked) { $form.WindowState = 'Minimized' }
})

$form.Add_FormClosing({ Save-Options })
$qualityBox.SelectedIndex = $settings.Quality
Update-Dlss
Update-Status
[void]$form.ShowDialog()
