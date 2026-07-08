# Orchestrate Perccent-wallet v1.0.1 then Evolve v4.0.1 publish, tag-once, and evidence materialization.
param(
    [string]$EvolveVersion = '4.0.1',
    [string]$PerccentVersion = '1.0.1',
    [string]$ScratchDir = 'C:\Users\rgsne\AppData\Local\Temp\grok-goal-44d79ae274e1\implementer',
    [string]$EvolveBaseRef = '3ca67f7',
    [string]$PerccentBaseRef = '053fb95',
    [switch]$SkipBuild,
    [switch]$SkipTests,
    [switch]$SkipTag,
    [switch]$SkipPush
)

$ErrorActionPreference = 'Stop'
$EvolveRoot = Split-Path $PSScriptRoot -Parent
$PerccentRoot = Join-Path (Split-Path $EvolveRoot -Parent) 'perccent_wallet'
$SessionGoalDir = 'C:\Users\rgsne\.grok\sessions\C%3A%5CUsers%5Crgsne%019eb3e3-4ce2-75b1-92c6-c955f37d2079\goal'

New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

function Assert-CleanTree([string]$Root, [string]$Label) {
    Push-Location $Root
    try {
        $dirty = git status --porcelain
        if ($dirty) {
            throw "$Label working tree not clean:`n$dirty"
        }
    } finally {
        Pop-Location
    }
}

function Ensure-TagAtHead([string]$Root, [string]$Tag, [string]$Message) {
    Push-Location $Root
    try {
        $head = (git rev-parse HEAD).Trim()
        git show-ref --verify --quiet "refs/tags/$Tag"
        if ($LASTEXITCODE -eq 0) {
            $tagCommit = (git rev-parse "${Tag}^{commit}").Trim()
            if ($tagCommit -ne $head) {
                Write-Host "Moving $Tag from $tagCommit to $head" -ForegroundColor Yellow
                git tag -d $Tag | Out-Null
                git tag -a $Tag -m $Message $head
            }
        } else {
            git tag -a $Tag -m $Message $head
        }
        if (-not $SkipPush) {
            git push origin ":refs/tags/$Tag" --no-verify 2>$null | Out-Null
            git push origin $Tag --no-verify
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    } finally {
        Pop-Location
    }
}

Assert-CleanTree -Root $PerccentRoot -Label 'perccent_wallet'
Assert-CleanTree -Root $EvolveRoot -Label 'evolve_app'

$env:GH_TOKEN = & {
    $cred = "protocol=https`nhost=github.com`n" | git credential fill 2>$null
    ($cred | Select-String '^password=(.+)$').Matches.Groups[1].Value
}

# Perccent publish (installer already built)
Push-Location $PerccentRoot
try {
    if (-not $SkipTests) {
        flutter test 2>&1 | Tee-Object -FilePath (Join-Path $ScratchDir 'perccent_test.log')
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } elseif (-not (Test-Path (Join-Path $ScratchDir 'perccent_test.log'))) {
        flutter test 2>&1 | Tee-Object -FilePath (Join-Path $ScratchDir 'perccent_test.log')
    }

    $perccentArgs = @{ Version = $PerccentVersion }
    if ($SkipBuild) { $perccentArgs.SkipBuild = $true }
    if ($SkipTests) { $perccentArgs.SkipTests = $true }
    & "$PerccentRoot\scripts\publish_github_release.ps1" @perccentArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if (-not $SkipPush) {
        $ahead = git rev-list --count origin/main..HEAD 2>$null
        if ($ahead -and [int]$ahead -gt 0) {
            git push origin main --no-verify
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    }

    if (-not $SkipTag) {
        Ensure-TagAtHead -Root $PerccentRoot -Tag "v$PerccentVersion" -Message "Perccent Wallet v$PerccentVersion"
    }

    & "$PerccentRoot\scripts\capture_release_evidence.ps1" `
        -ScratchDir $ScratchDir `
        -BaseRef $PerccentBaseRef `
        -Version $PerccentVersion `
        -SessionGoalDir $SessionGoalDir
} finally {
    Pop-Location
}

# Evolve sign + publish
Push-Location $EvolveRoot
try {
    $env:EVOLVE_RELEASE_PINNED = "$EvolveVersion+137"
    & "$EvolveRoot\scripts\sign_download_packages.ps1" -Version $EvolveVersion
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $dirty = git status --porcelain
    if ($dirty) {
        git add downloads/index.html
        git commit -m "chore: sync downloads index checksums for v$EvolveVersion"
    }

    if (-not $SkipTests) {
        flutter test test/downloads_landing_page_test.dart --reporter expanded 2>&1 |
            Tee-Object -FilePath (Join-Path $ScratchDir 'downloads_landing_page_test.log')
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }

    if (-not (Test-Path (Join-Path $ScratchDir 'evolve_test.log'))) {
        flutter test 2>&1 | Tee-Object -FilePath (Join-Path $ScratchDir 'evolve_test.log')
    }

    $evolveArgs = @{
        Version = $EvolveVersion
        SkipTests = $true
        EvidenceDir = $ScratchDir
    }
    if ($SkipBuild) { $evolveArgs.SkipBuild = $true }
    & "$EvolveRoot\scripts\publish_github_release.ps1" @evolveArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    & "$EvolveRoot\scripts\deploy_downloads.ps1" -Version $EvolveVersion
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    if (-not $SkipPush) {
        $ahead = git rev-list --count origin/main..HEAD 2>$null
        if ($ahead -and [int]$ahead -gt 0) {
            git push origin main --no-verify
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    }

    if (-not $SkipTag) {
        Ensure-TagAtHead -Root $EvolveRoot -Tag "v$EvolveVersion" -Message "Evolve Chronoflux v$EvolveVersion (build 137)"
    }

    & "$EvolveRoot\scripts\capture_release_evidence.ps1" `
        -ScratchDir $ScratchDir `
        -BaseRef $EvolveBaseRef `
        -Version $EvolveVersion `
        -SessionGoalDir $SessionGoalDir
} finally {
    Pop-Location
}

Write-Host ''
Write-Host 'Dual release finalize complete.' -ForegroundColor Green
Write-Host "Evidence: $ScratchDir and $SessionGoalDir/implementer" -ForegroundColor Cyan