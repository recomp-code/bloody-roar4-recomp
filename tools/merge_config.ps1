<#
  Builds game\config\config.toml the way the NBA Street V3 port's was made: the TOML exported by Ghidra
  (config.ghidra_original.toml) + the SCE stubs ps2_analyzer recognises (config.analyzer.toml) + entry points for code
  Ghidra left outside any function (gap_entries.txt, from find_gap_entries.ps1).
  Only needed when re-deriving the configuration (the repository already has the result).
  Usage: merge_config.ps1 [-Root C:\BloodyRoar4Recomp]
#>
param([string]$Root = $(if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' }))
$ErrorActionPreference = "Stop"
$c = Join-Path $Root 'game\config'
if (-not (Test-Path "$c\config.ghidra_original.toml")) { Copy-Item "$c\config.toml" "$c\config.ghidra_original.toml" }
$ghidra = Get-Content "$c\config.ghidra_original.toml"

function Get-List([string[]]$lines, [string]$key) {
    $i = [array]::IndexOf($lines, "$key = [")
    if ($i -lt 0) { return @() }
    $out = @()
    for ($j = $i + 1; $j -lt $lines.Count -and $lines[$j].Trim() -ne "]"; $j++) { $out += $lines[$j].Trim().Trim(',').Trim('"') }
    return $out
}

$byAddr = [ordered]@{}
foreach ($s in (Get-List $ghidra "stubs") + (Get-List (Get-Content "$c\config.analyzer.toml") "stubs")) {
    $addr = $s.Split('@')[1].ToUpper()
    if (-not $byAddr.Contains($addr)) { $byAddr[$addr] = $s }
}
$entries = Get-Content "$c\gap_entries.txt" | Where-Object { $_ -and -not $byAddr.Contains($_.Split('@')[1].ToUpper()) }

$outDir = (Join-Path $Root 'game\output').Replace('\', '/')
$out = New-Object System.Collections.Generic.List[string]
$skipping = $false
foreach ($line in $ghidra) {
    if ($skipping) { if ($line.Trim() -eq "]") { $skipping = $false }; continue }
    if ($line -like 'output = *') { $out.Add("output = `"$outDir`""); continue }
    if ($line -eq "stubs = [") {
        $out.Add("stubs = ["); $byAddr.Values | ForEach-Object { $out.Add("  `"$_`",") }; $out.Add("]")
        $skipping = $true; continue
    }
    if ($line -eq "untracked_stubs = [") {
        $out.Add("untracked_stubs = ["); $out.Add("]")
        $out.Add("entry_points = ["); $entries | ForEach-Object { $out.Add("  `"$_`",") }; $out.Add("]")
        $skipping = $true; continue
    }
    $out.Add($line)
}
$out | Set-Content -Encoding ASCII "$c\config.toml"
"stubs=$($byAddr.Count) entry_points=$($entries.Count)"
