# Reliable local DE tip acceptance gate for auxForever (no game client).
#
#   powershell -File tests/test-de.ps1
#   powershell -File tests/test-de.ps1 -Prove          # contract + mutation + deploy match
#   powershell -File tests/test-de.ps1 -Prove -Deploy  # prove, then copy into Forever AddOns
#   powershell -File tests/test-de.ps1 -Watch
#
# -Prove is the "safe to /reload" gate:
#   1) DE contract (white no DE, green has DE, cross-hover)
#   2) Mutation proof (OLD last_link-first picker is caught by those cases)
#   3) Forever AddOns files match the repo (after -Deploy, or already deployed)

param(
    [switch]$Watch,
    [switch]$Deploy,
    [switch]$Prove
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$addon = Join-Path $root 'auxForever'
$forever = 'C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns\auxForever'
$files = @(
    'util\info.lua',
    'core\tooltip.lua',
    'core\disenchant.lua',
    'gui\auction_listing.lua'
)

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

function Assert-FilesMatch {
    if (-not (Test-Path -LiteralPath $forever)) {
        Write-Host 'DEPLOY CHECK SKIP: Forever AddOns path missing' -ForegroundColor Yellow
        return $true
    }
    $allMatch = $true
    foreach ($rel in $files) {
        $src = Join-Path $addon $rel
        $dst = Join-Path $forever $rel
        if (-not (Test-Path -LiteralPath $dst)) {
            Write-Host "DEPLOY MISMATCH: missing $dst" -ForegroundColor Red
            $allMatch = $false
            continue
        }
        $a = Get-FileHash -LiteralPath $src -Algorithm SHA256
        $b = Get-FileHash -LiteralPath $dst -Algorithm SHA256
        if ($a.Hash -ne $b.Hash) {
            Write-Host "DEPLOY MISMATCH: $rel" -ForegroundColor Red
            $allMatch = $false
        }
        else {
            Write-Host "DEPLOY MATCH: $rel" -ForegroundColor DarkGreen
        }
    }
    return $allMatch
}

function Invoke-Deploy {
    if (-not (Test-Path -LiteralPath $forever)) {
        Write-Host "Deploy skipped: $forever not found" -ForegroundColor Yellow
        return
    }
    foreach ($rel in $files) {
        Copy-Item -LiteralPath (Join-Path $addon $rel) -Destination (Join-Path $forever $rel) -Force
    }
    Write-Host "Deployed to $forever" -ForegroundColor Yellow
}

function Invoke-DeGate {
    Push-Location $addon
    try {
        Write-Host "=== DE contract ($lua) ===" -ForegroundColor Cyan
        & $lua ../tests/load_test.lua de
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'DE CONTRACT FAILED' -ForegroundColor Red
            return 1
        }
        Write-Host 'DE CONTRACT OK (white no DE, green has DE, cross-hover)' -ForegroundColor Green

        if ($Prove) {
            Write-Host ''
            Write-Host "=== Mutation prove ($lua) ===" -ForegroundColor Cyan
            # Capture native stdout so PROVE OK lines always show in the host.
            $proveOut = & $lua ../tests/de_mutation_prove.lua 2>&1
            $proveCode = $LASTEXITCODE
            foreach ($line in $proveOut) { Write-Host $line }
            if ($proveCode -ne 0) {
                Write-Host 'MUTATION PROVE FAILED — suite would not catch the old bug' -ForegroundColor Red
                return 1
            }
        }

        if ($Deploy) {
            Invoke-Deploy
        }

        if ($Prove) {
            Write-Host ''
            Write-Host '=== Deploy match ===' -ForegroundColor Cyan
            if (-not (Assert-FilesMatch)) {
                Write-Host 'NOT SAFE: Forever AddOns differ from repo. Re-run with -Deploy.' -ForegroundColor Red
                return 1
            }
            Write-Host ''
            Write-Host 'SAFE TO /reload' -ForegroundColor Green
            Write-Host 'After reload: hover Brawler''s Harness (no Disenchant) then a green (Disenchant), or /aux smoke.' -ForegroundColor DarkGray
            Write-Host 'Local gate cannot prove Forever secret-value edge cases; /aux smoke is the one in-game check.' -ForegroundColor DarkGray
        }
        else {
            Write-Host 'DE CONTRACT OK (pass -Prove for mutation + deploy gate)' -ForegroundColor Green
        }
        return 0
    }
    finally {
        Pop-Location
    }
}

$code = Invoke-DeGate
if (-not $Watch) { exit $code }

Write-Host 'Watching auxForever + tests for changes (Ctrl+C to stop)...'
$watchFiles = @(
    (Join-Path $addon 'util\info.lua'),
    (Join-Path $addon 'core\tooltip.lua'),
    (Join-Path $addon 'core\disenchant.lua'),
    (Join-Path $root 'tests\de_tooltip_test.lua'),
    (Join-Path $root 'tests\de_mutation_prove.lua')
)
$last = @{}
foreach ($f in $watchFiles) { $last[$f] = (Get-Item $f).LastWriteTimeUtc }

while ($true) {
    Start-Sleep -Seconds 1
    $changed = $false
    foreach ($f in $watchFiles) {
        $t = (Get-Item $f).LastWriteTimeUtc
        if ($t -ne $last[$f]) {
            $last[$f] = $t
            $changed = $true
        }
    }
    if ($changed) {
        Write-Host ''
        Write-Host "$(Get-Date -Format 'HH:mm:ss') change detected" -ForegroundColor DarkGray
        Invoke-DeGate | Out-Null
    }
}
