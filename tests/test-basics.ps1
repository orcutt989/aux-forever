# Local basics contract for auxForever (no game client).
# Run from repo root or tests/:
#   powershell -File tests/test-basics.ps1
#
# Exit 0 only when both basics and smoke print "done, errors: 0".

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'auxForever'

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

$luac = $null
foreach ($candidate in @(
    'luac5.1',
    (Join-Path $env:USERPROFILE 'scoop\apps\lua51\5.1.5\luac5.1.exe')
)) {
    if (Get-Command $candidate -ErrorAction SilentlyContinue) {
        $luac = (Get-Command $candidate).Source
        break
    }
    if (Test-Path -LiteralPath $candidate) {
        $luac = $candidate
        break
    }
}

Push-Location $addon
try {
    Write-Host "Using $lua"
    if ($luac) {
        Write-Host '--- syntax ---'
        $files = @(
            Get-ChildItem -Path $addon -Recurse -Filter '*.lua'
            Get-ChildItem -Path (Join-Path $root 'tests') -Filter '*.lua'
        )
        foreach ($f in $files) {
            & $luac -p $f.FullName
            if ($LASTEXITCODE -ne 0) {
                Write-Error "syntax fail: $($f.FullName)"
                exit 1
            }
        }
    }
    Write-Host '--- basics ---'
    & $lua ../tests/load_test.lua basics
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host '--- smoke ---'
    & $lua ../tests/load_test.lua smoke
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Write-Host 'ALL GREEN'
    exit 0
}
finally {
    Pop-Location
}
