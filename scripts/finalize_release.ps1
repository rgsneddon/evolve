param(
  [string]$Version = "4.0.0",
  [string]$ScratchDir = "C:\Users\rgsne\AppData\Local\Temp\grok-goal-81e471764cf8\implementer",
  [string]$BaseRef = "3d09a3f"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null

function Write-StepLog([string]$Name, [scriptblock]$Block) {
  Write-Host "=== $Name ===" -ForegroundColor Cyan
  $logPath = Join-Path $ScratchDir "$Name.log"
  & $Block *>&1 | Tee-Object -FilePath $logPath
  if ($LASTEXITCODE -ne 0) {
    throw "$Name failed with exit $LASTEXITCODE"
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

# (b) Tests and doc/version audits
Write-StepLog "test_results" {
  flutter test --reporter expanded
}

$auditFiles = @("pubspec.yaml", "lib/perc/perc_app_version.dart", "version.json", "download.html", "downloads/index.html", "README.md")
$audit = @("=== version audit $(Get-Date -Format o) ===")
foreach ($f in $auditFiles) {
  $audit += "---- $f ----"
  $audit += (Select-String -Path $f -Pattern '4\.0\.0|3\.4\.8|136|135' | ForEach-Object { $_.Line })
}
$audit | Set-Content (Join-Path $ScratchDir "version_audit.log") -Encoding utf8

$doc = @("=== doc spotcheck $(Get-Date -Format o) ===")
$doc += (Select-String -Path README.md -Pattern 'Security tab|treasury|scenario-only|v4\.0\.0|build 136' | ForEach-Object { $_.Line })
$doc += "--- privacy_policy.txt ---"
$doc += (Select-String -Path privacy_policy.txt -Pattern 'Last updated|Security tab|treasury|scenario-only' | ForEach-Object { $_.Line })
$doc | Set-Content (Join-Path $ScratchDir "doc_spotcheck.log") -Encoding utf8

flutter test test/downloads_landing_page_test.dart --reporter expanded 2>&1 |
  Set-Content (Join-Path $ScratchDir "landing_page_test.log") -Encoding utf8
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# (c) Full build + installers + publish (no manual gh release delete)
Write-StepLog "build_all" {
  powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\build_all.ps1" -SkipTests
}

Write-StepLog "build_installers" {
  powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\build_installers.ps1" -SkipWindowsBuild -SkipApkBuild -SkipDeploy -SkipCodeSign
}

# Re-check tree after builds (fixture may change during tests in build_all if not skipped)
$dirtyAfter = git status --porcelain
if ($dirtyAfter) {
  git add -A
  git commit -m "chore: sync post-build downloads index and relay fixture for v$Version"
  if ($LASTEXITCODE -ne 0) { throw "Post-build commit failed" }
}

Write-StepLog "publish" {
  powershell -ExecutionPolicy Bypass -File "$PSScriptRoot\publish_github_release.ps1" -Version $Version -SkipBuild -EvidenceDir $ScratchDir
}

# (d) Mirror evidence to C:\Users\rgsne\goal\ and scratch
& "$PSScriptRoot\capture_release_evidence.ps1" -ScratchDir $ScratchDir -BaseRef $BaseRef -Version $Version

# (e) Push main and tag once (no force, no --no-verify)
$ahead = git rev-list --count origin/main..HEAD 2>$null
if ($ahead -and [int]$ahead -gt 0) {
  git push origin main
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$tag = "v$Version"
git show-ref --verify --quiet "refs/tags/$tag"
if ($LASTEXITCODE -eq 0) {
  $localTag = (git rev-parse $tag^{commit}).Trim()
  $remoteTag = (git ls-remote --tags origin "refs/tags/$tag" 2>$null) -replace ".*refs/tags/$tag", ""
  if ($remoteTag) { $remoteTag = $remoteTag.Trim() }
  if ($localTag -ne $remoteTag) {
    Write-Host "Tag $tag exists locally at $localTag; remote at $remoteTag — skipping tag push (no force)." -ForegroundColor Yellow
  } else {
    git push origin $tag
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  }
}

Write-Host "Finalize complete. Evidence: $ScratchDir and C:\Users\rgsne\goal" -ForegroundColor Green