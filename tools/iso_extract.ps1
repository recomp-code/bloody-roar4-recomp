<#
  Reads a PS2 DVD image (ISO9660) without mounting it: lists or extracts its files. Nothing leaves the PC.
    iso_extract.ps1 -Iso <image.iso> -List                      names, sizes and sectors
    iso_extract.ps1 -Iso <image.iso> -Out <dir>                 extracts everything
    iso_extract.ps1 -Iso <image.iso> -Out <dir> -Only SLES_518.77,SYSTEM.CNF
  Used by install.ps1 (works for ISOs on any drive, also where Mount-DiskImage is not available).
#>
param(
    [Parameter(Mandatory)][string]$Iso,
    [string]$Out = '',
    [string[]]$Only = @(),
    [switch]$List
)
$ErrorActionPreference = 'Stop'
$fs = [IO.File]::Open((Resolve-Path $Iso).Path, 'Open', 'Read', 'Read')
try {
    function Read-Sectors([long]$lba, [int]$length) {
        $buffer = New-Object byte[] $length
        $fs.Position = $lba * 2048
        $read = 0
        while ($read -lt $length) {
            $n = $fs.Read($buffer, $read, $length - $read)
            if ($n -le 0) { throw "The image ends early (sector $lba): is the ISO complete?" }
            $read += $n
        }
        , $buffer
    }
    $pvd = Read-Sectors 16 2048
    if ($pvd[0] -ne 1 -or [Text.Encoding]::ASCII.GetString($pvd, 1, 5) -ne 'CD001') { throw "$Iso is not an ISO9660 disc image" }

    # Every file: @{ Path = 'DIR\NAME'; Lba; Size; Dir }
    $entries = New-Object System.Collections.Generic.List[object]
    function Walk([long]$lba, [int]$size, [string]$prefix, [int]$depth) {
        if ($depth -gt 16) { return }
        $data = Read-Sectors $lba $size
        $i = 0
        while ($i -lt $size) {
            $len = $data[$i]
            if ($len -eq 0) { $i = ([math]::Floor($i / 2048) + 1) * 2048; continue }   # records never cross sectors
            $extent = [BitConverter]::ToUInt32($data, $i + 2)
            $length = [BitConverter]::ToUInt32($data, $i + 10)
            $isDir = ($data[$i + 25] -band 2) -ne 0
            $nameLength = $data[$i + 32]
            $raw = [Text.Encoding]::ASCII.GetString($data, $i + 33, $nameLength)
            if ($nameLength -eq 1 -and ($data[$i + 33] -eq 0 -or $data[$i + 33] -eq 1)) { $i += $len; continue }   # . and ..
            $name = ($raw -split ';')[0]
            if ($name.EndsWith('.') -and -not $isDir) { $name = $name.TrimEnd('.') }
            $path = if ($prefix) { "$prefix\$name" } else { $name }
            $entries.Add([pscustomobject]@{ Path = $path; Lba = [long]$extent; Size = [long]$length; Dir = $isDir })
            if ($isDir) { Walk $extent $length $path ($depth + 1) }
            $i += $len
        }
    }
    Walk ([BitConverter]::ToUInt32($pvd, 156 + 2)) ([BitConverter]::ToUInt32($pvd, 156 + 10)) '' 0

    if ($List) {
        $entries | Where-Object { -not $_.Dir } | Select-Object Path, Size, Lba
        return
    }
    if (-not $Out) { throw 'Give -Out <folder> or -List' }
    New-Item -ItemType Directory -Force $Out | Out-Null
    $files = @($entries | Where-Object { -not $_.Dir -and (-not $Only.Count -or $Only -contains $_.Path) })
    if ($Only.Count -and $files.Count -ne $Only.Count) {
        $missing = $Only | Where-Object { $files.Path -notcontains $_ }
        throw "Not on this disc: $($missing -join ', ')"
    }
    $total = ($files | Measure-Object Size -Sum).Sum
    $done = 0L
    $buffer = New-Object byte[] (4MB)
    foreach ($f in $files) {
        $target = Join-Path $Out $f.Path
        New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
        $os = [IO.File]::Create($target)
        try {
            $fs.Position = $f.Lba * 2048
            $left = $f.Size
            while ($left -gt 0) {
                $n = $fs.Read($buffer, 0, [int][math]::Min($buffer.Length, $left))
                if ($n -le 0) { throw "The image ends early inside $($f.Path): is the ISO complete?" }
                $os.Write($buffer, 0, $n)
                $left -= $n; $done += $n
            }
        } finally { $os.Dispose() }
        if ($total -gt 64MB) { Write-Host -NoNewline ("`r    extracting: {0:N0} / {1:N0} MB      " -f ($done / 1MB), ($total / 1MB)) }
    }
    if ($total -gt 64MB) { Write-Host '' }
    "extracted=$($files.Count) bytes=$total"
}
finally { $fs.Dispose() }
