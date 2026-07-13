# End-to-end iOS packaging verification: stage dummy IPA, run build_ios_installer.ps1 -SkipIosBuild.
param(
    [string]$EvidenceDir = ''
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
Set-Location $Root

$pubspec = Get-Content (Join-Path $Root 'pubspec.yaml') -Raw
if ($pubspec -notmatch 'version:\s*([0-9.]+)\+(\d+)') {
    throw 'Could not read version from pubspec.yaml'
}
$Version = $Matches[1]
$Build = $Matches[2]
$ProductPrefix = 'evolve'
$publishedName = "$ProductPrefix-v$Version-ios-setup.ipa"

$ipaDir = Join-Path $Root 'build\ios\ipa'
New-Item -ItemType Directory -Path $ipaDir -Force | Out-Null
$stagedIpa = Join-Path $ipaDir 'staged-flutter-output.ipa'
[System.IO.File]::WriteAllBytes($stagedIpa, [byte[]](,0x50 * 4096))

$log = [System.Collections.Generic.List[string]]::new()
$log.Add("verify_ios_packaging evolve v$Version+$Build")
$log.Add("staged_ipa=$stagedIpa")

& "$PSScriptRoot\build_ios_installer.ps1" -SkipIosBuild -Version $Version -Build $Build
if ($LASTEXITCODE) { $exitCode = $LASTEXITCODE } else { $exitCode = 0 }
$log.Add("build_ios_installer_exit=$exitCode")
if ($exitCode -ne 0) {
    if ($EvidenceDir) {
        New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
        $log | Set-Content (Join-Path $EvidenceDir 'evolve_ios_packaging_verify.log') -Encoding utf8
    }
    exit $exitCode
}

$versionedDir = Join-Path $Root "build\downloads\v$Version"
$publishedPath = Join-Path $versionedDir $publishedName
$metaJson = Join-Path $Root "installer\ios\$ProductPrefix-v$Version-ios.json"
$checksumsJson = Join-Path $versionedDir 'checksums.json'

$checks = @{
    published_ipa = (Test-Path $publishedPath)
    sha256_sidecar = (Test-Path "$publishedPath.sha256")
    sha512_sidecar = (Test-Path "$publishedPath.sha512")
    installer_meta_json = (Test-Path $metaJson)
    checksums_json = (Test-Path $checksumsJson)
    installer_ios_dir = (Test-Path (Join-Path $Root 'installer\ios'))
}

foreach ($key in $checks.Keys) {
    $log.Add("${key}=$($checks[$key])")
    if (-not $checks[$key]) {
        throw "Packaging verification failed: $key missing"
    }
}

$manifest = Get-Content $checksumsJson -Raw | ConvertFrom-Json
$iosEntry = $manifest.packages | Where-Object { $_.file -eq $publishedName } | Select-Object -First 1
if (-not $iosEntry) {
    throw "checksums.json missing entry for $publishedName"
}
$log.Add("checksums_sha256=$($iosEntry.sha256)")
$log.Add('result=PASS')

if ($EvidenceDir) {
    New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null
    $log | Set-Content (Join-Path $EvidenceDir 'evolve_ios_packaging_verify.log') -Encoding utf8
    Get-ChildItem $versionedDir -File | ForEach-Object { $_.Name } |
        Out-File (Join-Path $EvidenceDir 'evolve_ios_packaging_artifacts.txt') -Encoding utf8
    Copy-Item $metaJson (Join-Path $EvidenceDir "evolve-v$Version-ios.json") -Force
}

Write-Host 'iOS packaging verification passed.' -ForegroundColor Green
exit 0