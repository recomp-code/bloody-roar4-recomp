# Bloody Roar 4 test run: starts the game in a window for N seconds, asks the GS host for screenshots and closes it.
#   .\run_test.ps1 -Seconds 90 -Shots 20,40,60,80 [-Tag x] [-Ini br4_dlss.ini] [-Env @{PS2X_PAD_SCRIPT="30:START"; PS2X_NO_GAMEPAD="1"}]
# Screenshots in <Root>\logs\<tag>\shot_*.png (PS2X_SHOT_DIR + host.req of the live host), game logs in stdout/stderr.log.
# PS2X_PAD_SCRIPT="<seconds>:<BUTTON>,..." presses buttons by itself (e.g. to reach a fight); PS2X_FPS_LOG=1 logs fps.
param(
    [int]$Seconds = 90,
    [double[]]$Shots = @(),
    [string]$Tag = "test",
    [string]$Ini = "br4.ini",
    [hashtable]$Env = @{},
    [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' })
)
$R = $Root
$rt = "$R\PS2Recomp\out\build\ps2xRuntime\Release"
$out = "$R\logs\$Tag"
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -File -ErrorAction SilentlyContinue | Remove-Item -Force

$env:PS2X_CD_IMAGE = "$R\game\BloodyRoar4.iso"
$env:PS2X_GS_LIVE = "1"
$env:PS2X_PAD_ANALOG = "1"
$env:PS2X_GSHOST = "$R\gshost\pcsx2-gsrunner.exe"
$env:PS2X_GSHOST_ARGS = "-renderer vulkan -ini $R\gshost\$Ini"
$env:PS2X_LIVE_SERIAL = "SLES-51877"
$env:PS2X_LIVE_TITLE = "Bloody Roar 4"
$env:PS2X_HOST_WINDOW = "1280x720"
$env:PS2X_FPS_LOG = "1"
$env:PS2X_SHOT_DIR = $out
$env:PS2X_HOST_NOACTIVATE = "1"
foreach ($k in $Env.Keys) { Set-Item "env:$k" $Env[$k] }

$p = Start-Process "$rt\ps2EntryRunner.exe" -ArgumentList "`"$R\game\iso\SLES_518.77`"" -WorkingDirectory "$R\game\iso" `
     -RedirectStandardOutput "$out\stdout.log" -RedirectStandardError "$out\stderr.log" -PassThru -WindowStyle Minimized
$t0 = Get-Date
$pending = [System.Collections.Generic.List[double]]::new(); $Shots | ForEach-Object { $pending.Add($_) }
while (-not $p.HasExited -and ((Get-Date) - $t0).TotalSeconds -lt $Seconds) {
    $el = ((Get-Date) - $t0).TotalSeconds
    if ($pending.Count -gt 0 -and $el -ge $pending[0]) {
        [IO.File]::WriteAllText("$out\host.req", ("shot_{0:000.0}.png" -f $pending[0]).Replace(",", "."))
        $pending.RemoveAt(0)
    }
    Start-Sleep -Milliseconds 500
}
$exited = $p.HasExited
$code = if ($exited) { $p.ExitCode } else { $null }
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pcsx2-gsrunner.exe' -and $_.CommandLine -like "*$R*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
"exited_by_itself=$exited code=$code after {0:N0}s" -f ((Get-Date) - $t0).TotalSeconds
Get-ChildItem $out | Select-Object Length, Name | Format-Table -AutoSize
