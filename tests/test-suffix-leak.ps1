# Comprehensive suffix-leak finder for auxForever.
#
# Builds an item list from the Forever account item cache (every item aux has seen),
# then runs the leak scan: after an of-the-X AH hover, none of those tips may gain +stats.
#
#   powershell -File tests/test-suffix-leak.ps1
#   powershell -File tests/test-suffix-leak.ps1 -SavedVariables "D:\path\auxForever.lua"
#
# Exit 0 only when victim count is 0. Prints affected item name + id when red.

param(
    [string]$SavedVariables = ''
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'auxForever'
$fixtureDir = Join-Path $PSScriptRoot 'fixtures'
$idsFile = Join-Path $fixtureDir 'suffix_leak_ids.tsv'

$lua = $null
foreach ($candidate in @(
    'lua5.1',
    (Join-Path $env:USERPROFILE 'scoop\apps\lua51\5.1.5\lua5.1.exe'),
    (Join-Path $env:USERPROFILE 'scoop\shims\lua5.1.exe')
)) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $lua = (Get-Command $candidate).Source
        break
    }
    if (Test-Path -LiteralPath $candidate) {
        $lua = $candidate
        break
    }
}
if (-not $lua) {
    Write-Error 'lua5.1 not found. Install with: scoop install lua51'
    exit 1
}

function Find-SavedVariables {
    if ($SavedVariables -and (Test-Path -LiteralPath $SavedVariables)) {
        return $SavedVariables
    }
    $accountRoot = 'C:\Program Files (x86)\World of Warcraft\_forever_\WTF\Account'
    if (-not (Test-Path -LiteralPath $accountRoot)) {
        return $null
    }
    $hits = Get-ChildItem -Path $accountRoot -Recurse -Filter 'auxForever.lua' -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\bak\\' -and $_.Name -eq 'auxForever.lua' } |
        Sort-Object LastWriteTimeUtc -Descending
    if ($hits) { return $hits[0].FullName }
    return $null
}

function Export-ItemIds([string]$svPath, [string]$outPath) {
    New-Item -ItemType Directory -Force -Path (Split-Path $outPath) | Out-Null
    $ids = @{}
    $names = @{}
    # Only packed item-cache rows: "Wool Cloth#|cnIQ…|Hitem:2592:…"
    # (Do not use ["key"] = number — that also matches settings like background_opacity.)
    $blob = [regex]'"([^"#]+)#\|[^"]*\|Hitem:(\d+):'
    Get-Content -LiteralPath $svPath -ReadCount 2000 | ForEach-Object {
        foreach ($line in $_) {
            foreach ($m in $blob.Matches($line)) {
                $n = $m.Groups[1].Value
                $id = [int]$m.Groups[2].Value
                if ($id -gt 0) {
                    $ids[$id] = $true
                    $names[$id] = $n
                }
            }
        }
    }
    $ordered = $ids.Keys | Sort-Object
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $sw = New-Object System.IO.StreamWriter($outPath, $false, $utf8)
    try {
        $sw.WriteLine("id`tname")
        foreach ($id in $ordered) {
            $n = if ($names.ContainsKey($id)) { $names[$id] } else { "item:$id" }
            $n = $n -replace '[\t\r\n]+', ' '
            $sw.WriteLine("$id`t$n")
        }
    }
    finally {
        $sw.Close()
    }
    return $ordered.Count
}

$sv = Find-SavedVariables
Write-Host "=== suffix-leak scan ($lua) ===" -ForegroundColor Cyan
if ($sv) {
    Write-Host "SavedVariables: $sv"
    $count = Export-ItemIds $sv $idsFile
    Write-Host "Exported $count item ids -> $idsFile"
}
else {
    Write-Host 'No Forever auxForever.lua found; using seed TSV' -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $fixtureDir | Out-Null
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($idsFile, @"
id	name
117	Tough Jerky
2589	Linen Cloth
2592	Wool Cloth
3676	Slimy Ichor
4538	Tel'Abim Banana
5339	Serpentbloom
6125	Brawler's Harness
6470	Deviate Hide
"@, $utf8)
}

$env:AUX_SUFFIX_LEAK_IDS = $idsFile
Push-Location $addon
try {
    & $lua ../tests/load_test.lua suffix-leak
    $code = $LASTEXITCODE
}
finally {
    Pop-Location
    Remove-Item Env:AUX_SUFFIX_LEAK_IDS -ErrorAction SilentlyContinue
}

if ($code -ne 0) {
    Write-Host 'SUFFIX LEAK SCAN FAILED — items above inherit of-the-X +stats from last_hover' -ForegroundColor Red
    exit $code
}
Write-Host 'SUFFIX LEAK SCAN OK (zero victims)' -ForegroundColor Green
exit 0
