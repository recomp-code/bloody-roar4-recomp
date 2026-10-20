# DLSS 5 test run: starts BR4 with <Root>\gshost_dlss5 (Direct3D 12 + ReShade + RenoDX DLSS 5 add-on, prepared by the
# launcher) in a window, reaches a fight with a button script and captures the window as it is shown on screen (with the
# neural pass, which the GS's own screenshots do not include). At each -Compare time it presses F6 (neural pass on/off)
# and captures before and after.
#   .\capture_dlss5.ps1 [-Seconds 100] [-Shots 70,80] [-Compare 85] [-Window 1920x1080] [-Tag dlss5]
param(
    [int]$Seconds = 100,
    [double[]]$Shots = @(70, 80),
    [double[]]$Compare = @(88),
    [string]$Window = "1920x1080",
    [string]$Tag = "dlss5",
    [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' })
)
$R = $Root
$out = "$R\logs\$Tag"
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -File -ErrorAction SilentlyContinue | Remove-Item -Force
Add-Type -AssemblyName System.Drawing
if (-not ("Br4.Win" -as [type])) {
    Add-Type -Name Win -Namespace Br4 -MemberDefinition @'
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(System.IntPtr h);
[DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr h, int cmd);
[DllImport("user32.dll")] public static extern bool GetClientRect(System.IntPtr h, out RECT r);
[DllImport("user32.dll")] public static extern bool ClientToScreen(System.IntPtr h, ref POINT p);
[DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, System.UIntPtr extra);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
public struct RECT { public int Left, Top, Right, Bottom; }
public struct POINT { public int X, Y; }
'@
}
[void][Br4.Win]::SetProcessDPIAware()

function Get-HostWindow {
    $h = Get-Process pcsx2-gsrunner -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$R\gshost_dlss5\*" -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($h) { $h.MainWindowHandle } else { [IntPtr]::Zero }
}
function Save-Window([string]$name) {
    $hw = Get-HostWindow
    if ($hw -eq [IntPtr]::Zero) { Add-Content "$out\capture.log" "${name}: no window"; return }
    [void][Br4.Win]::ShowWindow($hw, 9); [void][Br4.Win]::SetForegroundWindow($hw); Start-Sleep -Milliseconds 400
    $rc = New-Object Br4.Win+RECT; [void][Br4.Win]::GetClientRect($hw, [ref]$rc)
    $pt = New-Object Br4.Win+POINT; [void][Br4.Win]::ClientToScreen($hw, [ref]$pt)
    $w = $rc.Right - $rc.Left; $hgt = $rc.Bottom - $rc.Top
    $bmp = New-Object Drawing.Bitmap $w, $hgt
    $g = [Drawing.Graphics]::FromImage($bmp); $g.CopyFromScreen($pt.X, $pt.Y, 0, 0, $bmp.Size); $g.Dispose()
    $bmp.Save("$out\$name.png", [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    Add-Content "$out\capture.log" ("{0}: {1}x{2}" -f $name, $w, $hgt)
}
function Send-Key([byte]$vk) {
    $hw = Get-HostWindow
    if ($hw -ne [IntPtr]::Zero) { [void][Br4.Win]::SetForegroundWindow($hw); Start-Sleep -Milliseconds 200 }
    [Br4.Win]::keybd_event($vk, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 80
    [Br4.Win]::keybd_event($vk, 0, 2, [UIntPtr]::Zero)
}

$env:PS2X_CD_IMAGE = "$R\game\BloodyRoar4.iso"
$env:PS2X_GS_LIVE = "1"
$env:PS2X_PAD_ANALOG = "1"
$env:PS2X_GSHOST = "$R\gshost_dlss5\pcsx2-gsrunner.exe"
$env:PS2X_GSHOST_ARGS = "-renderer dx12 -ini $R\gshost_dlss5\br4_dlss_dx12.ini"
$env:PS2X_LIVE_SERIAL = "SLES-51877"
$env:PS2X_LIVE_TITLE = "Bloody Roar 4"
$env:PS2X_HOST_WINDOW = $Window
$env:PS2X_FPS_LOG = "1"
$env:PS2X_NO_GAMEPAD = "1"
$env:PS2X_PAD_SCRIPT = "6:CROSS,9:LEFT,10:CROSS,14:CROSS,30:START,35:START,42:START,48:START,54:CROSS,60:CROSS,66:CROSS,74:CROSS"

$rt = "$R\PS2Recomp\out\build\ps2xRuntime\Release"
$p = Start-Process "$rt\ps2EntryRunner.exe" -ArgumentList "`"$R\game\iso\SLES_518.77`"" -WorkingDirectory "$R\game\iso" `
     -RedirectStandardOutput "$out\stdout.log" -RedirectStandardError "$out\stderr.log" -PassThru -WindowStyle Minimized
$t0 = Get-Date
$events = @()
$Shots | ForEach-Object { $events += [pscustomobject]@{ t = $_; kind = "shot" } }
$Compare | ForEach-Object { $events += [pscustomobject]@{ t = $_; kind = "compare" } }
$events = [System.Collections.Generic.List[object]]($events | Sort-Object t)
while (-not $p.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt $Seconds) {
    $el = ((Get-Date) - $t0).TotalSeconds
    if ($events.Count -gt 0 -and $el -ge $events[0].t) {
        $e = $events[0]; $events.RemoveAt(0)
        $name = ("win_{0:000}" -f $e.t)
        if ($e.kind -eq "shot") { Save-Window $name }
        else {
            Save-Window "${name}_neural_on"
            Send-Key 0x75   # F6: neural pass on/off
            Start-Sleep -Milliseconds 700
            Save-Window "${name}_neural_off"
            Send-Key 0x75
        }
    }
    Start-Sleep -Milliseconds 250
}
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pcsx2-gsrunner.exe' -and $_.CommandLine -like "*$R*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
Copy-Item "$R\gshost_dlss5\logs\emulog.txt" $out -ErrorAction SilentlyContinue
Copy-Item "$R\gshost_dlss5\ReShade.log" $out -ErrorAction SilentlyContinue
Get-ChildItem $out | Select-Object Length, Name | Format-Table -AutoSize
