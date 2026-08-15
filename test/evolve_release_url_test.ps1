# Drive shipped URL helpers: canonical vX.Y.Z only, never a platform-suffix tag.
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. (Join-Path $Root 'scripts\lib\package_checksum.ps1')

function Assert-Eq([string]$Actual, [string]$Expected, [string]$Label) {
    if ($Actual -ne $Expected) {
        throw "$Label`n  expected: $Expected`n  actual:   $Actual"
    }
}

Assert-Eq (Get-EvolveCanonicalReleaseTag -Version '4.1.12') 'v4.1.12' 'plain version'
Assert-Eq (Get-EvolveCanonicalReleaseTag -Version 'v4.1.12') 'v4.1.12' 'already-tagged'
Assert-Eq (Get-EvolveCanonicalReleaseTag -Version '4.1.12-macos-ios-android') 'v4.1.12' 'suffix version stripped'
Assert-Eq (Get-EvolveCanonicalReleaseTag -Version 'v4.1.12-windows') 'v4.1.12' 'windows suffix stripped'
Assert-Eq (Get-EvolveCanonicalReleaseTag -Version '4.1.11') 'v4.1.11' '4.1.11 stays vX.Y.Z'

$base = Get-EvolveReleaseDownloadBase -Version '4.1.12-macos-ios-android'
Assert-Eq $base 'https://github.com/rgsneddon/evolve/releases/download/v4.1.12' 'download base never emits platform suffix'

$dirty = @(
    'https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-android-setup.apk'
    'https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-macos-x64.zip'
    'https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-ios-setup.ipa'
    'https://github.com/rgsneddon/evolve/releases/download/v4.1.12/evolve-v4.1.12-windows-x64-setup.exe'
    'https://github.com/rgsneddon/evolve/releases/tag/v4.1.12-macos-ios-android'
) -join "`n"

$clean = Rewrite-EvolveReleaseDownloadUrls -Text $dirty -Version '4.1.12'
if ($clean -match 'releases/(?:download|tag)/v4\.1\.12-[A-Za-z]') {
    throw "Rewrite left a platform-suffix tag:`n$clean"
}
Assert-Eq ($clean -split "`n")[0] 'https://github.com/rgsneddon/evolve/releases/download/v4.1.12/evolve-v4.1.12-android-setup.apk' 'apk href'
Assert-Eq ($clean -split "`n")[1] 'https://github.com/rgsneddon/evolve/releases/download/v4.1.12/evolve-v4.1.12-macos-x64.zip' 'macos href'
Assert-Eq ($clean -split "`n")[2] 'https://github.com/rgsneddon/evolve/releases/download/v4.1.12/evolve-v4.1.12-ios-setup.ipa' 'ios href'
Assert-Eq ($clean -split "`n")[3] 'https://github.com/rgsneddon/evolve/releases/download/v4.1.12/evolve-v4.1.12-windows-x64-setup.exe' 'windows href'
Assert-Eq ($clean -split "`n")[4] 'https://github.com/rgsneddon/evolve/releases/tag/v4.1.12' 'tag href'

$scratch = Join-Path $env:TEMP 'evolve-release-url-index-test'
if (Test-Path $scratch) { Remove-Item $scratch -Recurse -Force }
New-Item -ItemType Directory -Path $scratch | Out-Null
$versionDir = Join-Path $scratch 'v4.1.12'
New-Item -ItemType Directory -Path $versionDir | Out-Null

# Minimal checksums.json so Update-DownloadsIndexPage can rewrite a suffix-tag page.
$winBytes = 14126446
$apkBytes = 80286079
$iosBytes = 23259771
$macosBytes = 22319295
@{
    packages = @(
        @{ file = 'evolve-v4.1.12-windows-x64-setup.exe'; bytes = $winBytes; sha256 = 'a' * 64; sha512 = 'b' * 128 }
        @{ file = 'evolve-v4.1.12-android-setup.apk'; bytes = $apkBytes; sha256 = 'c' * 64; sha512 = 'd' * 128 }
        @{ file = 'evolve-v4.1.12-ios-setup.ipa'; bytes = $iosBytes; sha256 = 'e' * 64; sha512 = 'f' * 128 }
        @{ file = 'evolve-v4.1.12-macos-x64.zip'; bytes = $macosBytes; sha256 = '1' * 64; sha512 = '2' * 128 }
    )
} | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $versionDir 'checksums.json') -Encoding utf8

$index = Join-Path $scratch 'landing.html'
@(
    '<p class="version">Latest release: <strong>v4.1.10</strong> (build 1)</p>'
    '<div class="grid">'
    '<article class="card windows"><p class="meta">evolve-v4.1.10-windows-x64-setup.exe &middot; ~1.0 MB</p>'
    '<a href="https://github.com/rgsneddon/evolve/releases/download/v4.1.10/evolve-v4.1.10-windows-x64-setup.exe">w</a>'
    '<p>SHA-256: <code>aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa</code>'
    '(<a href="https://github.com/rgsneddon/evolve/releases/download/v4.1.10/evolve-v4.1.10-windows-x64-setup.exe.sha256">.sha256</a>)</p></article>'
    '<article class="card android"><p class="meta">evolve-v4.1.10-android-setup.apk &middot; ~1.0 MB</p>'
    '<a href="https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-android-setup.apk">a</a>'
    '<p>SHA-256: <code>cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc</code>'
    '(<a href="https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-android-setup.apk.sha256">.sha256</a>)</p></article>'
    '<article class="card macos"><p class="meta">evolve-v4.1.10-macos-x64.zip &middot; ~1.0 MB</p>'
    '<a href="https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-macos-x64.zip">m</a>'
    '<p>SHA-256: <code>1111111111111111111111111111111111111111111111111111111111111111</code>'
    '(<a href="https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-macos-x64.zip.sha256">.sha256</a>)</p></article>'
    '<article class="card ios"><p class="meta">evolve-v4.1.10-ios-setup.ipa &middot; ~1.0 MB</p>'
    '<a href="https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-ios-setup.ipa">i</a>'
    '<p>SHA-256: <code>eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee</code>'
    '(<a href="https://github.com/rgsneddon/evolve/releases/download/v4.1.12-macos-ios-android/evolve-v4.1.12-ios-setup.ipa.sha256">.sha256</a>)</p></article>'
    '</div>'
) -join "`n" | Set-Content $index -Encoding utf8

Update-DownloadsIndexPage -VersionDir $versionDir -DownloadsIndex $index -Version '4.1.12' -Build '179' -SkipSigningNotes | Out-Null
$rewritten = Get-Content $index -Raw
if ($rewritten -match 'releases/(?:download|tag)/v4\.1\.12-[A-Za-z]') {
    throw "Update-DownloadsIndexPage left a platform-suffix tag:`n$rewritten"
}
foreach ($file in @(
    'evolve-v4.1.12-windows-x64-setup.exe',
    'evolve-v4.1.12-android-setup.apk',
    'evolve-v4.1.12-macos-x64.zip',
    'evolve-v4.1.12-ios-setup.ipa'
)) {
    $want = "https://github.com/rgsneddon/evolve/releases/download/v4.1.12/$file"
    if ($rewritten -notlike "*$want*") {
        throw "Update-DownloadsIndexPage missing $want"
    }
}

Write-Host 'evolve_release_url_test PASS' -ForegroundColor Green
