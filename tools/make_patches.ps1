<#
  Regenerates the patches from the local source trees, against their pinned commits, including new
  untracked files. Never touches the trees' real git index (a temporary copy is used).
    patches\ps2recomp.patch = <Root>\PS2Recomp vs ran-j/PS2Recomp 2c5fbb9 (all NBA Street V3 + Bloody Roar 4
                              changes). Generated code is left out: it is made from the game's ELF.
    patches\pcsx2.patch     = the GS host tree vs PCSX2 d073d75 (NBA Street V3's pcsx2.patch + the DBZ BT4 live-host
                              patches = the pcsx2-gsrunner.exe this port uses).
  -Check: afterwards, clones both trees into a temporary folder, checks out the pinned commits and verifies that
  each patch applies cleanly there (git apply --check). The clones are deleted.
  Usage: powershell -ExecutionPolicy Bypass -File tools\make_patches.ps1 [-Root C:\BloodyRoar4Recomp]
             [-Pcsx2 C:\DBZBT4Recomp\pcsx2] [-Check] [-CheckOnly]
#>
param(
    [string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' }),
    [string]$PS2Recomp = '',
    [string]$Pcsx2 = '',
    [switch]$Check,
    [switch]$CheckOnly
)
$ErrorActionPreference = 'Stop'
$Repo = Split-Path -Parent $PSScriptRoot
. "$PSScriptRoot\env.ps1" -Root $Root
if (-not $PS2Recomp) { $PS2Recomp = Join-Path $Root 'PS2Recomp' }
if (-not $Pcsx2) { $Pcsx2 = Join-Path $Root 'pcsx2' }
$PS2RecompCommit = '2c5fbb9'
$Pcsx2Commit = 'd073d75'

# Generated from the game's ELF by ps2_recomp / generate_game.ps1: never in a patch.
$Generated = @(
    'ps2xRuntime/src/runner',
    'ps2xRuntime/include/ps2_recompiled_functions.h',
    'ps2xRuntime/include/ps2_recompiled_stubs.h'
)

function MakePatch($src, $commit, $out, $exclude) {
    # git prints line-ending warnings on stderr; they must not stop the script.
    $ErrorActionPreference = 'Continue'
    $tmp = Join-Path $env:TEMP ("idx_" + [guid]::NewGuid().ToString('N'))
    Copy-Item "$src\.git\index" $tmp
    $env:GIT_INDEX_FILE = $tmp
    try {
        $untracked = git -C $src ls-files --others --exclude-standard
        if ($untracked) { $untracked | Where-Object { $p = $_; -not ($exclude | Where-Object { $p -like "$_*" }) } | ForEach-Object { git -C $src add -N -- $_ } }
        $diffArgs = @('-C', $src, '-c', 'core.abbrev=9', 'diff', '--binary', $commit, '--', '.') + ($exclude | ForEach-Object { ":(exclude)$_" })
        $patch = & git @diffArgs
        if ($LASTEXITCODE) { throw "git diff failed in $src" }
        [IO.File]::WriteAllText($out, (($patch -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
    }
    finally { Remove-Item Env:GIT_INDEX_FILE; Remove-Item $tmp -Force }
}

# Clones $src (sharing its objects, read-only for the source), checks out $commit and checks the patch.
function CheckPatch($src, $commit, $patch) {
    $ErrorActionPreference = 'Continue'
    $dir = Join-Path $env:TEMP ("br4chk_" + [guid]::NewGuid().ToString('N'))
    try {
        git clone --quiet --shared --no-checkout $src $dir 2>&1 | Out-Null
        if ($LASTEXITCODE) { throw "git clone $src failed" }
        # Same git settings as tools\setup_sources.ps1 uses on a player's PC (MinGit: core.autocrlf=true).
        git -C $dir checkout --quiet --detach $commit 2>&1 | Out-Null
        if ($LASTEXITCODE) { throw "git checkout $commit failed in the clone of $src" }
        $result = git -C $dir apply --check --whitespace=nowarn $patch 2>&1
        $ok = $LASTEXITCODE -eq 0
        $files = @(Select-String -Path $patch -Pattern '^diff --git ').Count
        Write-Host ("  {0}: {1} on a fresh checkout of {2} ({3} files)" -f [IO.Path]::GetFileName($patch), $(if ($ok) { 'applies cleanly' } else { 'DOES NOT APPLY' }), $commit, $files)
        if (-not $ok) { $result | Select-Object -First 20 | ForEach-Object { Write-Host "    $_" } }
        return $ok
    }
    finally { if (Test-Path $dir) { cmd /c rmdir /s /q "`"$dir`"" } }
}

if (-not $CheckOnly) {
    if (-not (Test-Path "$PS2Recomp\.git")) { throw "No PS2Recomp git checkout at $PS2Recomp" }
    MakePatch $PS2Recomp $PS2RecompCommit "$Repo\patches\ps2recomp.patch" $Generated
    if (Test-Path "$Pcsx2\.git") { MakePatch $Pcsx2 $Pcsx2Commit "$Repo\patches\pcsx2.patch" @() }
    else { Write-Warning "No PCSX2 git checkout at ${Pcsx2}: patches\pcsx2.patch left as it is" }
    Get-ChildItem "$Repo\patches" | Select-Object Name, Length | Format-Table -AutoSize
}
if ($Check -or $CheckOnly) {
    Write-Host 'Checking the patches on clean checkouts of the pinned commits...'
    $ok = CheckPatch $PS2Recomp $PS2RecompCommit "$Repo\patches\ps2recomp.patch"
    if (Test-Path "$Pcsx2\.git") { $ok = (CheckPatch $Pcsx2 $Pcsx2Commit "$Repo\patches\pcsx2.patch") -and $ok }
    if (-not $ok) { throw 'A patch does not apply on its pinned commit' }
}
