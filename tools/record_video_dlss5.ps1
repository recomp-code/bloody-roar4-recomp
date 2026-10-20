# Graba un video de Bloody Roar 4 con DLSS 5 (D3D12 + ReShade + RenoDX: el pase neural solo existe en la imagen que
# se presenta, asi que el video se captura de la pantalla con ffmpeg ddagrab + NVENC) y el audio del runtime
# (PS2X_WAVCAP). Los dos se alinean por reloj de pared: <wav>.start (primera muestra) y el progreso de ffmpeg.
# La ventana del host queda sin bordes, siempre encima y centrada en el area de trabajo del monitor principal (por
# defecto el mayor 16:9 que cabe sobre la barra de tareas), asi otras ventanas no salen en el video ni la minimizan.
# Resultado: logs\video\raw.mp4 + audio.wav -> br4_dlss5_full.mp4 (AV1, para docs\videos) y br4_dlss5_highlights.mp4
# (H.264 720p60 < 10 MB, para verlo dentro del README como el de DBZ).
param([int]$Seconds = 170, [int]$Width = 2560, [int]$Height = 1440, [double]$FullFrom = 40, [double]$HighFrom = 95,
      [double]$HighSeconds = 30, [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' }))
. "$PSScriptRoot\env.ps1" -Root $Root
$R = $Root
$out = "$R\logs\video"
$ff = Find-BR4Tool 'ffmpeg\ffmpeg.exe'
if (-not $ff) { $ff = (Get-Command ffmpeg -ErrorAction Stop).Source }   # needs ffmpeg 8+ (ddagrab, NVENC)
New-Item -ItemType Directory -Force $out | Out-Null
Get-ChildItem $out -File -ErrorAction SilentlyContinue | Remove-Item -Force
Add-Type -AssemblyName System.Windows.Forms
# Inside the work area (the taskbar stays on top of everything): by default the largest 16:9 that fits there.
$screen = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
if ($Height -gt $screen.Height) { $Height = $screen.Height - ($screen.Height % 2); $Width = [int]([Math]::Floor($Height * 16 / 9 / 2) * 2) }
$offX = $screen.X + [int](($screen.Width - $Width) / 2); $offY = $screen.Y
function NowMs { [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() }

# Menus -> character select -> fight (same path as the tests), then a fight: punches/kicks/beast/throws and movement.
$p = "6:CROSS,9:LEFT,10:CROSS,14:CROSS,30:START,35:START,42:START,48:START,54:CROSS,60:CROSS,66:CROSS,74:CROSS"
$moves = "SQUARE","SQUARE","TRIANGLE","RIGHT","SQUARE","TRIANGLE","TRIANGLE","CIRCLE","SQUARE","SQUARE","SQUARE",
         "TRIANGLE","LEFT","CROSS","RIGHT","RIGHT","TRIANGLE","SQUARE","CIRCLE","SQUARE","TRIANGLE","SQUARE+TRIANGLE"
$inv = [Globalization.CultureInfo]::InvariantCulture
$t = 80.0; $i = 0
while ($t -lt $Seconds - 5) { $p += "," + $t.ToString('0.00', $inv) + ":" + $moves[$i % $moves.Count]; $t += 0.45; $i++ }

$env:PS2X_CD_IMAGE = "$R\game\BloodyRoar4.iso"
$env:PS2X_GS_LIVE = "1"
$env:PS2X_PAD_ANALOG = "1"
$env:PS2X_GSHOST = "$R\gshost_dlss5\pcsx2-gsrunner.exe"
$env:PS2X_GSHOST_ARGS = "-renderer dx12 -ini $R\gshost_dlss5\br4_dlss_dx12.ini"
$env:PS2X_LIVE_SERIAL = "SLES-51877"
$env:PS2X_LIVE_TITLE = "Bloody Roar 4"
# A window, not fullscreen: a fullscreen host that loses focus minimises and stalls the game. The window is captured
# by its HWND (Windows Graphics Capture), so other windows on top of it don't end up in the video.
$env:PS2X_HOST_WINDOW = "${Width}x${Height}"
$env:PS2X_HOST_NOACTIVATE = "1"
$env:PS2X_FPS_LOG = "1"
$env:PS2X_NO_GAMEPAD = "1"
$env:PS2X_PAD_SCRIPT = $p
$env:PS2X_PAD_SCRIPT_HOLD = "160"
$env:PS2X_WAVCAP = "$out\audio.wav"

$rt = "$R\PS2Recomp\out\build\ps2xRuntime\Release"
$game = Start-Process "$rt\ps2EntryRunner.exe" -ArgumentList "`"$R\game\iso\SLES_518.77`"" -WorkingDirectory "$R\game\iso" `
        -RedirectStandardOutput "$out\stdout.log" -RedirectStandardError "$out\stderr.log" -PassThru -WindowStyle Minimized
# Wait for the GS host window, then capture it (near-lossless HEVC) with a progress file to time its first frame.
$hwnd = 0
for ($k = 0; $k -lt 200 -and $hwnd -eq 0; $k++) {
    Start-Sleep -Milliseconds 100
    $h = Get-Process pcsx2-gsrunner -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$R\gshost_dlss5\*" -and $_.MainWindowHandle -ne 0 } | Select-Object -First 1
    if ($h) { $hwnd = [int64]$h.MainWindowHandle }
}
if ($hwnd -eq 0) { throw "no GS host window" }
# Windows Graphics Capture fails here (0x800706BE), so: borderless, exactly Width x Height, centred and topmost (other
# windows stay behind it and it never minimises), then Desktop Duplication of that rectangle.
if (-not ("Br4.Rec" -as [type])) {
    Add-Type -Name Rec -Namespace Br4 -MemberDefinition @'
[DllImport("user32.dll")] public static extern System.IntPtr SetWindowLongPtr(System.IntPtr h, int index, System.IntPtr value);
[DllImport("user32.dll")] public static extern bool SetWindowPos(System.IntPtr h, System.IntPtr after, int x, int y, int cx, int cy, uint flags);
[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
'@
}
[void][Br4.Rec]::SetProcessDPIAware()
# Not while D3D12 is still creating its swap chain: wait for the host's first frames (DLSS set up).
$emulog = "$R\gshost_dlss5\logs\emulog.txt"
for ($k = 0; $k -lt 150; $k++) {
    if ((Test-Path $emulog) -and (Select-String $emulog -Pattern 'upscaler:|swap chain' -Quiet)) { break }
    Start-Sleep -Milliseconds 100
}
Start-Sleep -Seconds 2
$hw = [IntPtr]$hwnd
[void][Br4.Rec]::SetWindowLongPtr($hw, -16, [IntPtr]0x16000000)   # GWL_STYLE = WS_POPUP | WS_VISIBLE | WS_CLIPSIBLINGS
[void][Br4.Rec]::SetWindowPos($hw, [IntPtr](-1), $offX, $offY, $Width, $Height, 0x0020 -bor 0x0040)  # HWND_TOPMOST, FRAMECHANGED|SHOWWINDOW
Start-Sleep -Seconds 1
$vf = "ddagrab=output_idx=0:framerate=60:draw_mouse=0:offset_x=${offX}:offset_y=${offY}:video_size=${Width}x${Height}"
$ffArgs = "-hide_banner -loglevel error -y -f lavfi -i $vf -c:v hevc_nvenc -preset p5 -tune hq -rc constqp -qp 14 -t $Seconds -progress `"$out\progress.txt`" -stats_period 0.1 `"$out\raw.mp4`""
$cap = Start-Process $ff -ArgumentList $ffArgs -PassThru -WindowStyle Hidden -RedirectStandardError "$out\ffmpeg_capture.log"
$startMs = [double]::MaxValue
while (-not $cap.HasExited) {
    if (Test-Path "$out\progress.txt") {
        $us = Select-String "$out\progress.txt" -Pattern '^out_time_us=(\d+)' | Select-Object -Last 1
        if ($us -and [double]$us.Matches[0].Groups[1].Value -gt 0) {
            $startMs = [Math]::Min($startMs, (NowMs) - [double]$us.Matches[0].Groups[1].Value / 1000.0)
        }
    }
    Start-Sleep -Milliseconds 40
}
Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'pcsx2-gsrunner.exe' -and $_.CommandLine -match 'BloodyRoar4Recomp' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
if (-not $game.HasExited) { Stop-Process -Id $game.Id -Force -ErrorAction SilentlyContinue }
Copy-Item "$R\gshost_dlss5\logs\emulog.txt" $out -ErrorAction SilentlyContinue
Copy-Item "$R\gshost_dlss5\ReShade.log" $out -ErrorAction SilentlyContinue

$wavStart = [double](Get-Content "$out\audio.wav.start")
$offset = ($startMs - $wavStart) / 1000.0   # seconds of audio before the first video frame
"video start {0:0} ms, audio start {1:0} ms -> audio offset {2:0.000} s" -f $startMs, $wavStart, $offset | Tee-Object "$out\sync.txt"

# Audio input for a clip starting at video second $from: its position in the WAV is $offset + $from (negative = the
# audio started later than the video: delay it instead).
function AudioIn([double]$from) {
    $pos = $offset + $from
    if ($pos -ge 0) { return "-ss " + $pos.ToString('0.000', $inv) + " -i `"$out\audio.wav`"" }
    return "-itsoffset " + (-$pos).ToString('0.000', $inv) + " -i `"$out\audio.wav`""
}
# Full video (AV1 1440p60, the DBZ repo uses AV1 too) from -FullFrom to the end
$full = "-hide_banner -loglevel error -y -ss " + $FullFrom.ToString($inv) + " -i `"$out\raw.mp4`" " + (AudioIn $FullFrom) +
        " -map 0:v -map 1:a -c:v av1_nvenc -preset p7 -tune hq -rc vbr -cq 30 -b:v 5M -maxrate 9M -c:a aac -b:a 192k -movflags +faststart -shortest `"$out\br4_dlss5_full.mp4`""
Start-Process $ff -ArgumentList $full -Wait -NoNewWindow
# Highlights (H.264 720p60, < 10 MB so GitHub plays it inline)
$hi = "-hide_banner -loglevel error -y -ss " + $HighFrom.ToString($inv) + " -t " + $HighSeconds.ToString($inv) + " -i `"$out\raw.mp4`" " + (AudioIn $HighFrom) +
      " -map 0:v -map 1:a -vf scale=1280:720:flags=lanczos -c:v h264_nvenc -preset p7 -tune hq -rc vbr -b:v 2300k -maxrate 3500k -bufsize 6M -profile:v high -c:a aac -b:a 128k -movflags +faststart -shortest `"$out\br4_dlss5_highlights.mp4`""
Start-Process $ff -ArgumentList $hi -Wait -NoNewWindow
Get-ChildItem $out -File | Where-Object Extension -in '.mp4', '.wav' | Select-Object Name, @{ n = 'MB'; e = { [math]::Round($_.Length / 1MB, 1) } } | Format-Table -AutoSize
