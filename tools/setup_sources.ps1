<#
  Downloads PS2Recomp (and, with -WithPcsx2, PCSX2 and NVIDIA's DLSS SDK) at the exact versions this port was made
  on and applies this repository's patches:
    <Root>\PS2Recomp  = ran-j/PS2Recomp 2c5fbb9 + patches\ps2recomp.patch
    <Root>\pcsx2      = PCSX2/pcsx2 d073d75     + patches\pcsx2.patch       (only to build the GS host yourself)
    <Root>\ext\DLSS   = NVIDIA/DLSS SDK (headers and import library for the GS host's DLSS; only with -WithPcsx2)
  Running it again is safe: patches already applied are detected and skipped.
  Usage (git on the PATH, or tools\env.ps1 finds MinGit):
      powershell -ExecutionPolicy Bypass -File tools\setup_sources.ps1 [-Root C:\BloodyRoar4Recomp] [-WithPcsx2]
#>
param(
    [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' }),
    [switch]$WithPcsx2
)
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\env.ps1" -Root $Root
New-Item -ItemType Directory -Force (Join-Path $Root 'logs') | Out-Null

$sources = @(
    @{ Name = 'PS2Recomp'; Url = 'https://github.com/ran-j/PS2Recomp.git'; Commit = '2c5fbb9'; Patch = @('ps2recomp.patch') }
)
if ($WithPcsx2) {
    $sources += @{ Name = 'pcsx2'; Url = 'https://github.com/PCSX2/pcsx2.git'; Commit = 'd073d75'; Patch = @('pcsx2.patch') }
}

# git prints to stderr even when it works (progress) and `apply --check` reports a mismatch there.
# With $ErrorActionPreference = 'Stop', Windows PowerShell 5.1 turns redirected stderr into a
# terminating error, so the checks run with 'Continue' and are judged by their exit code.
function Test-Git([string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git @arguments 2>&1 | Out-Null; return $LASTEXITCODE -eq 0 } finally { $ErrorActionPreference = $saved }
}
function Invoke-Git([string[]]$arguments) {
    $saved = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & git @arguments 2>&1 | ForEach-Object { Write-Host "    $_" }; return $LASTEXITCODE } finally { $ErrorActionPreference = $saved }
}

foreach ($s in $sources) {
    $dir = Join-Path $Root $s.Name
    if (-not (Test-Path $dir)) {
        Write-Host "Cloning $($s.Name)..."
        if (Invoke-Git @('clone', $s.Url, $dir)) { throw "git clone $($s.Name) failed" }
    }
    Write-Host "Pinned version $($s.Commit) of $($s.Name)"
    # Already patched (the script is run again)? Then the checkout is skipped: it would fail on the patched files.
    $last = Join-Path $Repo "patches\$($s.Patch[-1])"
    if (Test-Git @('-C', $dir, 'apply', '--check', '--reverse', '--whitespace=nowarn', $last)) {
        Write-Host "  $($s.Patch -join ' + ') already applied"
        continue
    }
    if (Invoke-Git @('-C', $dir, 'checkout', '--quiet', $s.Commit)) { throw "git checkout $($s.Commit) failed in $($s.Name)" }
    foreach ($name in $s.Patch) {
        $patch = Join-Path $Repo "patches\$name"
        if (-not (Test-Git @('-C', $dir, 'apply', '--check', '--whitespace=nowarn', $patch))) {
            throw "The patch $name does not apply on $($s.Name) $($s.Commit) (local changes in $dir?)"
        }
        if (Invoke-Git @('-C', $dir, 'apply', '--whitespace=nowarn', $patch)) { throw "Could not apply $name" }
        Write-Host "  $name applied"
    }
}

if ($WithPcsx2) {
    $sdk = Join-Path $Root 'ext\DLSS'
    if (-not (Test-Path "$sdk\include\nvsdk_ngx_vk.h")) {
        Write-Host 'Cloning the NVIDIA DLSS SDK (headers for the GS host; without it the host has AMD FSR only)...'
        New-Item -ItemType Directory -Force (Split-Path $sdk) | Out-Null
        if (Invoke-Git @('clone', '--depth', '1', 'https://github.com/NVIDIA/DLSS.git', $sdk)) { Write-Warning 'NVIDIA DLSS SDK not downloaded: the GS host will be built without DLSS' }
    }
}
Write-Host "Sources ready in $Root"
