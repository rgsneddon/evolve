# Shared SHA-256 / SHA-512 checksum helpers for downloadable packages.

function Get-AllowedChecksumAlgorithms {
    return @('SHA256', 'SHA512')
}

function Get-PackageFileHash {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [ValidateSet('SHA256', 'SHA512')][string]$Algorithm = 'SHA256'
    )
    if (-not (Test-Path $Path)) {
        throw "Missing package file: $Path"
    }
    return (Get-FileHash -Path $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
}

function Write-PackageChecksumSidecar {
    param(
        [Parameter(Mandatory = $true)][string]$PackagePath,
        [string]$Version = '',
        [string]$Build = '',
        [string]$Platform = '',
        [string]$Url = '',
        [string[]]$ExtraMetadata = @()
    )

    if (-not (Test-Path $PackagePath)) {
        throw "Missing package file: $PackagePath"
    }

    $fileName = [IO.Path]::GetFileName($PackagePath)
    $sha256 = Get-PackageFileHash -Path $PackagePath -Algorithm SHA256
    $sha512 = Get-PackageFileHash -Path $PackagePath -Algorithm SHA512

    $sha256Path = "$PackagePath.sha256"
    $sha512Path = "$PackagePath.sha512"

    $meta = [System.Collections.Generic.List[string]]::new()
    $meta.Add("$sha256  $fileName")
    $meta.Add("algorithm=SHA256")
    $meta.Add("algorithm_secondary=SHA512")
    $meta.Add("sha512=$sha512")
    if ($Version) { $meta.Add("version=$Version") }
    if ($Build) { $meta.Add("build=$Build") }
    if ($Platform) { $meta.Add("platform=$Platform") }
    if ($Url) { $meta.Add("url=$Url") }
    foreach ($line in $ExtraMetadata) {
        if ($line) { $meta.Add($line) }
    }
    $meta | Set-Content -Path $sha256Path -Encoding utf8

    @(
        "$sha512  $fileName",
        'algorithm=SHA512',
        "sha256=$sha256"
    ) | Set-Content -Path $sha512Path -Encoding utf8

    return [PSCustomObject]@{
        FileName = $fileName
        Path = $PackagePath
        Sha256 = $sha256
        Sha512 = $sha512
        Sha256Path = $sha256Path
        Sha512Path = $sha512Path
    }
}

function Write-VersionChecksumManifest {
    param(
        [Parameter(Mandatory = $true)][string]$VersionDir,
        [string]$BaseUrl = ''
    )

    if (-not (Test-Path $VersionDir)) {
        throw "Missing version directory: $VersionDir"
    }

    $packages = Get-ChildItem $VersionDir -File | Where-Object {
        $_.Extension -notin '.sha256', '.sha512', '.json' -and
        $_.Name -notlike 'CHECKSUMS*'
    }

    $sha256Lines = [System.Collections.Generic.List[string]]::new()
    $sha512Lines = [System.Collections.Generic.List[string]]::new()
    $entries = @()

    foreach ($pkg in $packages) {
        $sha256 = Get-PackageFileHash -Path $pkg.FullName -Algorithm SHA256
        $sha512 = Get-PackageFileHash -Path $pkg.FullName -Algorithm SHA512
        $sha256Lines.Add("$sha256  $($pkg.Name)")
        $sha512Lines.Add("$sha512  $($pkg.Name)")
        $entries += [PSCustomObject]@{
            file = $pkg.Name
            bytes = $pkg.Length
            sha256 = $sha256
            sha512 = $sha512
            url = if ($BaseUrl) { "$BaseUrl/$($pkg.Name)" } else { '' }
        }
    }

    $sha256Manifest = Join-Path $VersionDir 'CHECKSUMS.sha256'
    $sha512Manifest = Join-Path $VersionDir 'CHECKSUMS.sha512'
    $sha256Lines | Set-Content -Path $sha256Manifest -Encoding utf8
    $sha512Lines | Set-Content -Path $sha512Manifest -Encoding utf8

    $jsonManifest = Join-Path $VersionDir 'checksums.json'
    @{
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        algorithms = @('SHA256', 'SHA512')
        minimumAlgorithm = 'SHA256'
        packages = $entries
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $jsonManifest -Encoding utf8

    return $entries
}

function Update-DownloadsIndexPage {
    param(
        [Parameter(Mandatory = $true)][string]$VersionDir,
        [string]$DownloadsIndex = '',
        [string]$Version = '',
        [string]$Build = ''
    )

    $Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    if (-not $DownloadsIndex) {
        $DownloadsIndex = Join-Path $Root 'downloads\index.html'
    }
    if (-not (Test-Path $DownloadsIndex)) {
        throw "Missing downloads index: $DownloadsIndex"
    }

    $manifestPath = Join-Path $VersionDir 'checksums.json'
    if (-not (Test-Path $manifestPath)) {
        throw "Missing checksum manifest: $manifestPath"
    }
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

    if (-not $Version) {
        if ($VersionDir -match 'v([0-9.]+)$') {
            $Version = $Matches[1]
        } else {
            throw 'Could not infer version from VersionDir'
        }
    }
    if (-not $Build) {
        $pubspec = Join-Path $Root 'pubspec.yaml'
        if (Test-Path $pubspec) {
            $pub = Get-Content $pubspec -Raw
            if ($pub -match 'version:\s*[0-9.]+\+(\d+)') {
                $Build = $Matches[1]
            }
        }
        if (-not $Build) { $Build = '0' }
    }

    $win = $manifest.packages | Where-Object { $_.file -match 'evolve.*windows' } | Select-Object -First 1
    $apk = $manifest.packages | Where-Object { $_.file -match 'evolve.*android|evolve.*apk' } | Select-Object -First 1
    $ios = $manifest.packages | Where-Object { $_.file -match 'evolve.*ios|\.ipa$' } | Select-Object -First 1
    if (-not $win -or -not $apk) {
        throw 'checksums.json must include windows and android packages'
    }

    $winMb = [math]::Round($win.bytes / 1MB, 1)
    $apkMb = [math]::Round($apk.bytes / 1MB, 1)
    $iosMb = if ($ios) { [math]::Round($ios.bytes / 1MB, 1) } else { 0 }
    $vPrefix = "v$Version"

    . (Join-Path $PSScriptRoot 'github.ps1')
    $owner = Get-GitHubOwner -Root $Root
    $releaseBase = "https://github.com/$owner/evolve/releases/download/v$Version"
    $releasePage = "https://github.com/$owner/evolve/releases/tag/v$Version"

    $html = Get-Content $DownloadsIndex -Raw
    $html = $html -replace 'Latest release: <strong>v[0-9.]+</strong> \(build \d+\)',
        "Latest release: <strong>v$Version</strong> (build $Build)"

    $html = $html -replace 'evolve-v[0-9.]+-windows-x64-setup\.exe &middot; ~[0-9.]+ MB',
        "$($win.file) &middot; ~$winMb MB"
    $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)evolve-v[0-9.]+-windows-x64-setup\.exe"',
        "href=`"$releaseBase/$($win.file)`""
    $html = $html -replace '(?s)(<div class="grid">.*?<article class="card windows">.*?SHA-256:\s*<code[^>]*>)[a-f0-9]{64}(</code>)',
        "`${1}$($win.sha256)`${2}"
    $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)evolve-v[0-9.]+-windows-x64-setup\.exe\.sha256"',
        "href=`"$releaseBase/$($win.file).sha256`""

    $html = $html -replace 'evolve-v[0-9.]+-android-setup\.apk &middot; ~[0-9.]+ MB',
        "$($apk.file) &middot; ~$apkMb MB"
    $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)evolve-v[0-9.]+-android-setup\.apk"',
        "href=`"$releaseBase/$($apk.file)`""
    $html = $html -replace '(?s)(<article class="card android">.*?SHA-256:\s*<code[^>]*>)[a-f0-9]{64}(</code>)',
        "`${1}$($apk.sha256)`${2}"
    $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)evolve-v[0-9.]+-android-setup\.apk\.sha256"',
        "href=`"$releaseBase/$($apk.file).sha256`""

    $html = $html -replace '<code>evolve-v[0-9.]+-windows-x64-setup\.exe</code>',
        "<code>$($win.file)</code>"
    $html = $html -replace '<code>evolve-v[0-9.]+-android-setup\.apk</code>',
        "<code>$($apk.file)</code>"
    $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)CHECKSUMS\.sha256"',
        "href=`"$releaseBase/CHECKSUMS.sha256`""
    $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)CHECKSUMS\.sha512"',
        "href=`"$releaseBase/CHECKSUMS.sha512`""
    $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)checksums\.json"',
        "href=`"$releaseBase/checksums.json`""

    . (Join-Path $PSScriptRoot 'release_signing_status.ps1')
    Update-DownloadsInstallNotesForSigning -Root $Root -DownloadsIndex $DownloadsIndex -VersionDir $VersionDir | Out-Null
    $html = Get-Content $DownloadsIndex -Raw

    if ($ios) {
        $html = $html -replace 'evolve-v[0-9.]+-ios-setup\.ipa &middot; ~[0-9.]+ MB',
            "$($ios.file) &middot; ~$iosMb MB"
        $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)evolve-v[0-9.]+-ios-setup\.ipa"',
            "href=`"$releaseBase/$($ios.file)`""
        $html = $html -replace '(?s)(<article class="card ios">.*?SHA-256:\s*<code[^>]*>)[a-f0-9]{64}(</code>)',
            "`${1}$($ios.sha256)`${2}"
        $html = $html -replace 'href="(?:v[0-9.]+/|https://github\.com/[^/]+/evolve/releases/download/v[0-9.]+/)evolve-v[0-9.]+-ios-setup\.ipa\.sha256"',
            "href=`"$releaseBase/$($ios.file).sha256`""
        $html = $html -replace '<code>evolve-v[0-9.]+-ios-setup\.ipa</code>',
            "<code>$($ios.file)</code>"
    }

    Set-Content -Path $DownloadsIndex -Value $html -NoNewline
    return [PSCustomObject]@{
        Version = $Version
        Build = $Build
        Windows = $win.file
        Android = $apk.file
        iOS = if ($ios) { $ios.file } else { '' }
    }
}

function Resolve-PerccentPackageReleaseUrl {
    param(
        [Parameter(Mandatory = $true)]$Package,
        [Parameter(Mandatory = $true)][string]$DefaultReleaseBase,
        [string]$Owner = 'rgsneddon',
        [string]$RepoName = 'perccent-wallet'
    )

    if ($Package.url -and "$($Package.url)".Trim()) {
        return "$($Package.url)".Trim()
    }
    if ($Package.file -match 'perccent-wallet-v([0-9.]+)-') {
        $pkgVersion = $Matches[1]
        return "https://github.com/$Owner/$RepoName/releases/download/v$pkgVersion/$($Package.file)"
    }
    return "$DefaultReleaseBase/$($Package.file)"
}

function Resolve-PerccentChecksumsManifest {
    param(
        [string]$Root = '',
        [string]$ManifestPath = ''
    )

    if ($ManifestPath -and (Test-Path $ManifestPath)) {
        return $ManifestPath
    }

    if (-not $Root) {
        $Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    $walletRoot = Join-Path (Split-Path $Root -Parent) 'perccent_wallet'
    $downloadsRoot = Join-Path $walletRoot 'build\downloads'
    if (-not (Test-Path $downloadsRoot)) {
        return $null
    }

    $latest = Get-ChildItem $downloadsRoot -Directory -Filter 'v*' |
        Sort-Object { [version]($_.Name -replace '^v', '') } -Descending |
        Select-Object -First 1
    if (-not $latest) { return $null }

    $candidate = Join-Path $latest.FullName 'checksums.json'
    if (Test-Path $candidate) { return $candidate }
    return $null
}

function Update-PerccentDownloadsIndexSection {
    param(
        [string]$ManifestPath = '',
        [string]$DownloadsIndex = '',
        [string]$Owner = 'rgsneddon',
        [string]$RepoName = 'perccent-wallet'
    )

    $Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    if (-not $DownloadsIndex) {
        $DownloadsIndex = Join-Path $Root 'downloads\index.html'
    }
    if (-not (Test-Path $DownloadsIndex)) {
        throw "Missing downloads index: $DownloadsIndex"
    }

    $ManifestPath = Resolve-PerccentChecksumsManifest -Root $Root -ManifestPath $ManifestPath
    if (-not $ManifestPath) {
        Write-Host 'Perccent checksums manifest not found; skipping perccent-wallet section update.' -ForegroundColor Yellow
        return $null
    }

    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $win = $manifest.packages | Where-Object { $_.file -match 'perccent-wallet.*windows' } | Select-Object -First 1
    if (-not $win) {
        throw "Perccent manifest missing windows package: $ManifestPath"
    }
    $apk = $manifest.packages | Where-Object { $_.file -match 'perccent-wallet.*android|perccent-wallet.*apk' } | Select-Object -First 1
    if (-not $apk) {
        throw "Perccent manifest missing android package: $ManifestPath"
    }
    $ios = $manifest.packages | Where-Object { $_.file -match 'perccent-wallet.*ios|perccent-wallet.*\.ipa$' } | Select-Object -First 1

    if ($win.file -notmatch 'perccent-wallet-v([0-9.]+)-') {
        throw "Could not parse Perccent version from $($win.file)"
    }
    $version = $Matches[1]
    $winMb = [math]::Round($win.bytes / 1MB, 1)
    $apkMb = [math]::Round($apk.bytes / 1MB, 1)
    $releaseBase = "https://github.com/$Owner/$RepoName/releases/download/v$version"

    $html = Get-Content $DownloadsIndex -Raw
    if ($html -notmatch '<section class="perccent-wallet">') {
        throw 'downloads/index.html missing <section class="perccent-wallet">'
    }

    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card windows">.*?<p class="meta">)perccent-wallet-v[0-9.]+-windows-x64-setup\.exe &middot; ~[0-9.]+ MB(</p>)',
        "`${1}$($win.file) &middot; ~$winMb MB`${2}"
    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card windows">.*?href=")https://github\.com/[^/]+/[^/]+/releases/download/v[0-9.]+/perccent-wallet-v[0-9.]+-windows-x64-setup\.exe(")',
        "`${1}$releaseBase/$($win.file)`${2}"
    $html = $html -replace '(<code id="perccent-sha256"[^>]*>)[a-f0-9]{64}(</code>)',
        "`${1}$($win.sha256)`${2}"
    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card windows">.*?href=")https://github\.com/[^/]+/[^/]+/releases/download/v[0-9.]+/perccent-wallet-v[0-9.]+-windows-x64-setup\.exe\.sha256(")',
        "`${1}$releaseBase/$($win.file).sha256`${2}"
    $html = $html -replace '(<code id="perccent-setup-name">)perccent-wallet-v[0-9.]+-windows-x64-setup\.exe(</code>)',
        "`${1}$($win.file)`${2}"

    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card android">.*?<p class="meta">)perccent-wallet-v[0-9.]+-android-setup\.apk &middot; ~[0-9.]+ MB( &middot; arm64, arm32, x86_64)?(</p>)',
        "`${1}$($apk.file) &middot; ~$apkMb MB &middot; arm64, arm32, x86_64`${3}"
    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card android">.*?href=")https://github\.com/[^/]+/[^/]+/releases/download/v[0-9.]+/perccent-wallet-v[0-9.]+-android-setup\.apk(")',
        "`${1}$releaseBase/$($apk.file)`${2}"
    $html = $html -replace '(<code id="perccent-apk-sha256"[^>]*>)[a-f0-9]{64}(</code>)',
        "`${1}$($apk.sha256)`${2}"
    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card android">.*?href=")https://github\.com/[^/]+/[^/]+/releases/download/v[0-9.]+/perccent-wallet-v[0-9.]+-android-setup\.apk\.sha256(")',
        "`${1}$releaseBase/$($apk.file).sha256`${2}"
    $html = $html -replace '(<code id="perccent-apk-name">)perccent-wallet-v[0-9.]+-android-setup\.apk(</code>)',
        "`${1}$($apk.file)`${2}"

    if ($ios) {
        $iosMb = [math]::Round($ios.bytes / 1MB, 1)
        $iosReleaseUrl = Resolve-PerccentPackageReleaseUrl -Package $ios -DefaultReleaseBase $releaseBase -Owner $Owner -RepoName $RepoName
        $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card ios">.*?<p class="meta">)perccent-wallet-v[0-9.]+-ios-setup\.ipa &middot; ~[0-9.]+ MB(</p>)',
            "`${1}$($ios.file) &middot; ~$iosMb MB`${2}"
        $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card ios">.*?href=")https://github\.com/[^/]+/[^/]+/releases/download/v[0-9.]+/perccent-wallet-v[0-9.]+-ios-setup\.ipa(")',
            "`${1}$iosReleaseUrl`${2}"
        $html = $html -replace '(<code id="perccent-ios-sha256"[^>]*>)[a-f0-9]{64}(</code>)',
            "`${1}$($ios.sha256)`${2}"
        $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<article class="card ios">.*?href=")https://github\.com/[^/]+/[^/]+/releases/download/v[0-9.]+/perccent-wallet-v[0-9.]+-ios-setup\.ipa\.sha256(")',
            "`${1}$iosReleaseUrl.sha256`${2}"
        $html = $html -replace '(<code id="perccent-ios-name">)perccent-wallet-v[0-9.]+-ios-setup\.ipa(</code>)',
            "`${1}$($ios.file)`${2}"
    }

    Set-Content -Path $DownloadsIndex -Value $html -NoNewline
    return [PSCustomObject]@{
        Version = $version
        Windows = $win.file
        Android = $apk.file
        iOS = if ($ios) { $ios.file } else { '' }
        Sha256 = $win.sha256
        AndroidSha256 = $apk.sha256
        iOSSha256 = if ($ios) { $ios.sha256 } else { '' }
        ManifestPath = $ManifestPath
    }
}

function Test-VersionPackageChecksums {
    param(
        [Parameter(Mandatory = $true)][string]$VersionDir,
        [switch]$RequireSidecars
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $packages = Get-ChildItem $VersionDir -File | Where-Object {
        $_.Extension -notin '.sha256', '.sha512', '.json' -and
        $_.Name -notlike 'CHECKSUMS*'
    }

    foreach ($pkg in $packages) {
        $expected256 = Get-PackageFileHash -Path $pkg.FullName -Algorithm SHA256
        $expected512 = Get-PackageFileHash -Path $pkg.FullName -Algorithm SHA512

        $sidecar256 = "$($pkg.FullName).sha256"
        $sidecar512 = "$($pkg.FullName).sha512"

        if ($RequireSidecars -and -not (Test-Path $sidecar256)) {
            $errors.Add("Missing sidecar: $sidecar256")
            continue
        }
        if ($RequireSidecars -and -not (Test-Path $sidecar512)) {
            $errors.Add("Missing sidecar: $sidecar512")
            continue
        }

        if (Test-Path $sidecar256) {
            $line = (Get-Content $sidecar256 -TotalCount 1).Trim()
            if ($line -notmatch '^([a-f0-9]{64})\s+') {
                $errors.Add("Invalid SHA-256 sidecar format: $sidecar256")
            } elseif ($Matches[1] -ne $expected256) {
                $errors.Add("SHA-256 mismatch for $($pkg.Name)")
            }
        }

        if (Test-Path $sidecar512) {
            $line = (Get-Content $sidecar512 -TotalCount 1).Trim()
            if ($line -notmatch '^([a-f0-9]{128})\s+') {
                $errors.Add("Invalid SHA-512 sidecar format: $sidecar512")
            } elseif ($Matches[1] -ne $expected512) {
                $errors.Add("SHA-512 mismatch for $($pkg.Name)")
            }
        }
    }

    $manifest256 = Join-Path $VersionDir 'CHECKSUMS.sha256'
    if ($RequireSidecars -and -not (Test-Path $manifest256)) {
        $errors.Add("Missing manifest: $manifest256")
    }

    if ($errors.Count -gt 0) {
        throw ($errors -join [Environment]::NewLine)
    }

    return $true
}