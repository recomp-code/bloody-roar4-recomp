<#
  Shared paths for the PowerShell tools. Dot-source it:  . "$PSScriptRoot\env.ps1" [-Root <dir>]
  Sets $BR4Root (default C:\BloodyRoar4Recomp, or $env:BR4_ROOT) and puts the portable tools on the PATH.
  Each tool is looked for in <Root>\tools first and then in C:\NBAStreetRecomp\tools (the NBA Street V3 port
  uses the same versions), so a PC that already built that port does not download anything twice.
#>
param([string]$Root = '')
if (-not $Root) { $Root = if ($env:BR4_ROOT) { $env:BR4_ROOT } else { 'C:\BloodyRoar4Recomp' } }
$BR4Root = $Root
$BR4ToolDirs = @((Join-Path $Root 'tools'), 'C:\NBAStreetRecomp\tools')

# First existing "<tools>\<relative>" or $null.
function Find-BR4Tool([string]$relative) {
    foreach ($dir in $BR4ToolDirs) {
        $path = Join-Path $dir $relative
        if (Test-Path $path) { return $path }
    }
    return $null
}

$BR4Git = Find-BR4Tool 'mingit\cmd'
$BR4CMake = Find-BR4Tool 'cmake\cmake-4.4.4-windows-x86_64\bin'
$BR4Jdk = Find-BR4Tool 'jdk\jdk-21.0.12.1+1'
$BR4Ghidra = Find-BR4Tool 'ghidra\ghidra_12.1.4_PUBLIC'
if ($BR4Jdk) { $env:JAVA_HOME = $BR4Jdk }
foreach ($dir in @($BR4Git, $BR4CMake, $(if ($BR4Jdk) { "$BR4Jdk\bin" }), 'C:\Program Files\7-Zip')) {
    if ($dir -and (Test-Path $dir) -and ($env:Path -split ';') -notcontains $dir) { $env:Path = "$dir;$env:Path" }
}
