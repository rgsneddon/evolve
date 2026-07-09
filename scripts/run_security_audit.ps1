# run security audit — regular orchestrated security checks for Evolve Chronoflux.
param(
    [string]$LogPath = '',
    [switch]$SkipDefender
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib\dependency_audit.ps1')
. (Join-Path $PSScriptRoot 'lib\security_scan.ps1')
. (Join-Path $PSScriptRoot 'lib\package_checksum.ps1')
Set-Location $Root

if (-not $LogPath) {
    $LogPath = Join-Path $Root "build\security_audit_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
}

$report = [System.Collections.Generic.List[string]]::new()
$report.Add("=== run security audit $(Get-Date -Format o) ===")
$report.Add("repo=$Root")

$depLog = Join-Path $env:TEMP "evolve_dep_audit_$([Guid]::NewGuid()).log"
$null = Invoke-DependencyAudit -Root $Root -LogPath $depLog
$depText = Get-Content $depLog -Raw
$report.Add('')
$report.Add('--- dependency audit ---')
$report.Add($depText.Trim())
if ($depText -notmatch 'dependency_audit=(PASS|PASS_WITH_DOCUMENTED_EXCEPTIONS)') {
    throw 'Dependency audit failed; see log above'
}

$downloadsRoot = Join-Path $Root 'build\downloads'
$versionDir = $null
if (Test-Path $downloadsRoot) {
    $latest = Get-ChildItem $downloadsRoot -Directory -Filter 'v*' -ErrorAction SilentlyContinue |
        Sort-Object { [version]($_.Name -replace '^v', '') } -Descending |
        Select-Object -First 1
    if ($latest) { $versionDir = $latest.FullName }
}

$binaries = @()
if ($versionDir) {
    $binaries = @(Get-ChildItem $versionDir -File | Where-Object {
        $_.Extension -in '.exe', '.apk', '.msi', '.msix' -and $_.Name -notlike 'CHECKSUMS*'
    })
}

$report.Add('')
if ($binaries.Count -eq 0) {
    $report.Add('artifact_scan=SKIPPED (no build/downloads)')
} else {
    $scanLog = Join-Path $env:TEMP "evolve_scan_$([Guid]::NewGuid()).log"
    $null = Invoke-ReleaseArtifactSecurityScan `
        -Root $Root `
        -VersionDir $versionDir `
        -ExpectedApkPackage 'com.evolve.chronoflux' `
        -LogPath $scanLog `
        -SkipDefender:$SkipDefender
    $scanText = Get-Content $scanLog -Raw
    $report.Add('--- artifact scan ---')
    $report.Add($scanText.Trim())
    if ($scanText -notmatch 'result=PASS') {
        throw 'Artifact security scan failed'
    }
}

$report.Add('')
$sidecars = @()
if ($versionDir) {
    $sidecars = @(Get-ChildItem $versionDir -File -Filter '*.sha256' -ErrorAction SilentlyContinue)
}
if ($sidecars.Count -eq 0) {
    $report.Add('checksum_verify=SKIPPED (no checksum sidecars)')
} else {
    Test-VersionPackageChecksums -VersionDir $versionDir -RequireSidecars | Out-Null
    $report.Add("checksum_verify=PASS ($($sidecars.Count) sidecar(s) in $versionDir)")
}

$report.Add('')
$report.Add('--- policy and README checks ---')
$securityDoc = Join-Path $Root 'SECURITY.md'
$readmeDoc = Join-Path $Root 'README.md'
if (-not (Test-Path $securityDoc)) { throw 'Missing SECURITY.md' }
if (-not (Test-Path $readmeDoc)) { throw 'Missing README.md' }
$securityText = Get-Content $securityDoc -Raw
$readmeText = Get-Content $readmeDoc -Raw
if ($securityText -notmatch 'EX-dart_pub_audit_unavailable') {
    throw 'SECURITY.md missing EX-dart_pub_audit_unavailable'
}
if ($readmeText -notmatch '(?i)security\s*/\s*safe use') {
    throw 'README missing Security / Safe use section'
}
if ($readmeText -notmatch '(?i)checked regularly') {
    throw 'README missing regular security check disclaimer'
}

$prevEap = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$testOut = & flutter test test/security_readme_test.dart --reporter compact 2>&1
$testExit = $LASTEXITCODE
$ErrorActionPreference = $prevEap
$testJoined = ($testOut | ForEach-Object { "$_" }) -join [Environment]::NewLine
$report.Add($testJoined.Trim())
if ($testExit -ne 0) {
    throw "security_readme_test.dart failed with exit $testExit"
}
$report.Add('policy_checks=PASS')

$report.Add('')
$report.Add('run_security_audit=PASS')

$text = $report -join [Environment]::NewLine
$parent = Split-Path $LogPath -Parent
if ($parent -and -not (Test-Path $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
Set-Content -Path $LogPath -Value $text -Encoding utf8
Write-Host $text
Write-Host "run security audit passed. Log: $LogPath" -ForegroundColor Green