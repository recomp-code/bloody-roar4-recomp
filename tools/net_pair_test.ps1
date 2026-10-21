# Bloody Roar 4 online test on one machine: two games (player 1 and player 2) in lockstep over local UDP (or through
# a relay), each with its own copy of the same memory card, then a comparison of their state hashes.
#   .\net_pair_test.ps1 -Seconds 150 [-Script1 "50:CROSS,..."] [-Script2 "..."] [-Delay 2|auto] [-Shots 120,148] [-Relay]
# -Relay: both go through a local copy of the server's UDP relay (tools\testrelay, built to logs\testrelay.exe).
# Logs in <Root>\logs\net_p1 and net_p2 (stderr.log has the [net] and [dethash] lines).
param(
    [int]$Seconds = 150,
    [string]$Script1 = '50:CROSS,52:LEFT,54:CROSS,62:START,66:CROSS,70:CROSS,80:START,84:CROSS,88:CROSS,92:CROSS,96:CROSS,100:CROSS,104:CROSS,108:CROSS,112:CROSS,116:CROSS',
    [string]$Script2 = '',
    [string]$Delay = '2',
    [int]$Port = 0,
    [double[]]$Shots = @(120, 148),
    [string]$Rtc = '1767225600',
    [hashtable]$Env1 = @{},
    [hashtable]$Env2 = @{},
    [switch]$Relay,
    [int]$Seconds2 = 0, # player 2 quits after this many seconds (0 = -Seconds): the disconnect test
    [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' })
)
$R = $Root
if ($Port -eq 0) { $Port = Get-Random -Minimum 20000 -Maximum 60000 }
$tools = Split-Path -Parent $MyInvocation.MyCommand.Path
$card = "$R\game\iso\mc0"
$relayProc = $null
$token = -join ((1..32) | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
if ($Relay) {
    $relayExe = "$R\logs\testrelay.exe"
    if (-not (Test-Path $relayExe)) { throw "build tools\testrelay first: go build -o $relayExe" }
    $relayProc = Start-Process $relayExe -ArgumentList "-listen 127.0.0.1:$Port" -PassThru -WindowStyle Hidden -RedirectStandardError "$R\logs\testrelay.log"
}
$jobs = foreach ($pl in 1, 2) {
    $mc = "$R\logs\net_mc$pl"
    if (Test-Path $mc) { Remove-Item -Recurse -Force $mc }
    if (Test-Path $card) { Copy-Item -Recurse $card $mc } else { New-Item -ItemType Directory $mc | Out-Null }
    $e = @{ PS2X_DETERMINISTIC = '1'; PS2X_DETHASH = '60'; PS2X_RTC = $Rtc; PS2X_NO_GAMEPAD = '1'; PS2X_MC_ROOT = $mc
            PS2X_NET_PLAYER = "$pl"; PS2X_NET_DELAY = $Delay; PS2X_NET_STATUS_FILE = "$R\logs\net_p$pl.status" }
    if ($Relay) { $e.PS2X_NET_RELAY = "127.0.0.1:$Port"; $e.PS2X_NET_TOKEN = $token }
    if ($pl -eq 1) { if (-not $Relay) { $e.PS2X_NET_LISTEN = "$Port" }; if ($Script1) { $e.PS2X_PAD_SCRIPT = $Script1 }; foreach ($k in $Env1.Keys) { $e[$k] = $Env1[$k] } }
    else { if (-not $Relay) { $e.PS2X_NET = "127.0.0.1:$Port" }; if ($Script2) { $e.PS2X_PAD_SCRIPT = $Script2 }; foreach ($k in $Env2.Keys) { $e[$k] = $Env2[$k] } }
    $sec = if ($pl -eq 2 -and $Seconds2 -gt 0) { $Seconds2 } else { $Seconds }
    Start-Job -ArgumentList "$tools\run_test.ps1", $sec, "net_p$pl", $e, $Shots, $R -ScriptBlock {
        param($script, $sec, $tag, $envs, $shots, $root)
        & $script -Seconds $sec -Tag $tag -Env $envs -Shots $shots -Root $root | Out-Null
    }
    Start-Sleep -Seconds 2
}
$jobs | Wait-Job | Remove-Job
if ($relayProc -and -not $relayProc.HasExited) { Stop-Process -Id $relayProc.Id -Force }
foreach ($pl in 1, 2) {
    "== player $pl ($(Get-Content "$R\logs\net_p$pl.status" -ErrorAction SilentlyContinue))"
    Select-String "$R\logs\net_p$pl\stderr.log" -Pattern '^\[net\]' | Select-Object -Last 6 | ForEach-Object Line
}
$h = foreach ($pl in 1, 2) { ,@(Select-String "$R\logs\net_p$pl\stderr.log" -Pattern '^\[dethash\]' | ForEach-Object Line) }
$n = [Math]::Min($h[0].Count, $h[1].Count); $first = -1
for ($i = 0; $i -lt $n; $i++) { if ($h[0][$i] -ne $h[1][$i]) { $first = $i; break } }
if ($first -ge 0) { "hashes differ from check #$first`: $($h[0][$first]) | $($h[1][$first])" } else { "hashes equal for $n checks ($($h[0].Count) / $($h[1].Count))" }
