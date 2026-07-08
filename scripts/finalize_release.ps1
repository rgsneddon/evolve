param(
  [string]$Version = '',
  [string]$ScratchDir = 'C:\Users\rgsne\AppData\Local\Temp\grok-goal-5c94fa09228d\implementer',
  [string]$BaseRef = 'aacca1a',
  [switch]$RecreateRelease
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$versionJsonPath = Join-Path $Root 'version.json'
if (-not $Version) {
  if (-not (Test-Path $versionJsonPath)) {
    throw 'version.json missing and -Version not supplied'
  }
  $Version = (Get-Content $versionJsonPath -Raw | ConvertFrom-Json).version
}
$build = (Get-Content $versionJsonPath -Raw | ConvertFrom-Json).build_number
$env:EVOLVE_RELEASE_PINNED = "$Version+$build"

New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

function Invoke-StepLog([string]$Name, [scriptblock]$Block) {
  Write-Host "=== $Name ===" -ForegroundColor Cyan
  $logPath = Join-Path $ScratchDir "$Name.log"
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  $exitCode = 0
  try {
    & $Block 2>&1 | ForEach-Object {
      if ($_ -is [System.Management.Automation.ErrorRecord]) {
        $msg = $_.ToString()
        if ($msg -match 'Warning:') {
          Write-Host $msg -ForegroundColor Yellow
          $msg
        } else {
          Write-Error $_
        }
      } else {
        $_
      }
    } | Tee-Object -FilePath $logPath
    $exitCode = $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $prevEap
  }
  if ($exitCode -ne 0) {
    throw "$Name failed with exit $exitCode"
  }
}

# (a) Require clean working tree
$dirty = git status --porcelain
if ($dirty) {
  Write-Error @"
Working tree is not clean. Commit or revert before finalize:
$dirty
"@
  exit 1
}

$headAtStart = (git rev-parse HEAD).Trim()
Write-Host "Finalize v$Version+$build at HEAD $headAtStart (base $BaseRef)" -ForegroundColor Cyan

# (b) Full test suite — authoritative post-fix gate
Invoke-StepLog 'evolve_test' {
  flutter test --reporter expanded
}

# (c) Full build (web, windows, apk when JDK present)
Invoke-StepLog 'build_all' {
  & "$PSScriptRoot\build_all.ps1" -SkipTests
}

# (d) Installers + publish with gh-pages enabled (no skip flags)
$publishArgs = @{
  Version     = $Version
  EvidenceDir = $ScratchDir
}
if ($RecreateRelease) { $publishArgs.RecreateRelease = $true }

Invoke-StepLog 'publish' {
  $publishParams = @{
    Version     = $Version
    EvidenceDir = $ScratchDir
    SkipTests   = $true
  }
  if ($RecreateRelease) { $publishParams.RecreateRelease = $true }
  & "$PSScriptRoot\publish_github_release.ps1" @publishParams
}

# (e) GitHub release API/asset probe
& "$PSScriptRoot\verify_github_release.ps1" -Version $Version -ScratchDir $ScratchDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# (f) Live gh-pages downloads proof
& "$PSScriptRoot\verify_ghpages_downloads.ps1" -Version $Version -Build $build -ScratchDir $ScratchDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# (g) Ensure tag v$Version points at HEAD (force-move when drifted)
$tag = "v$Version"
$head = (git rev-parse HEAD).Trim()
git show-ref --verify --quiet "refs/tags/$tag"
if ($LASTEXITCODE -eq 0) {
  $localTag = (git rev-parse "${tag}^{commit}").Trim()
  if ($localTag -ne $head) {
    Write-Host "Moving tag $tag from $localTag to HEAD $head" -ForegroundColor Yellow
    git tag -f $tag $head
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    git push origin $tag --force
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
  else {
    $remoteTagLine = git ls-remote --tags origin "refs/tags/$tag" 2>$null
    if (-not $remoteTagLine) {
      git push origin $tag
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } elseif ($remoteTagLine -notmatch $head) {
      git push origin $tag --force
      if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
  }
} else {
  git tag -a $tag -m "Evolve Chronoflux $tag (build $build)"
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  git push origin $tag
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# Re-probe after tag move
& "$PSScriptRoot\verify_github_release.ps1" -Version $Version -ScratchDir $ScratchDir
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# (h) Evidence bundle for session goal
& "$PSScriptRoot\capture_release_evidence.ps1" -ScratchDir $ScratchDir -BaseRef $BaseRef -Version $Version

Write-Host "Finalize complete. Evidence: $ScratchDir" -ForegroundColor Green
Write-Host "Release: https://github.com/rgsneddon/evolve/releases/tag/$tag" -ForegroundColor Green
Write-Host "Downloads: https://rgsneddon.github.io/evolve/downloads/" -ForegroundColor Green