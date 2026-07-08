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

    $win = $manifest.packages | Where-Object { $_.file -match 'windows' } | Select-Object -First 1
    $apk = $manifest.packages | Where-Object { $_.file -match 'android|apk' } | Select-Object -First 1
    if (-not $win -or -not $apk) {
        throw 'checksums.json must include windows and android packages'
    }

    $winMb = [math]::Round($win.bytes / 1MB, 1)
    $apkMb = [math]::Round($apk.bytes / 1MB, 1)
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

    Set-Content -Path $DownloadsIndex -Value $html -NoNewline
    return [PSCustomObject]@{
        Version = $Version
        Build = $Build
        Windows = $win.file
        Android = $apk.file
    }
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
    $pkg = $manifest.packages | Where-Object { $_.file -match 'perccent-wallet.*windows' } | Select-Object -First 1
    if (-not $pkg) {
        throw "Perccent manifest missing windows package: $ManifestPath"
    }

    if ($pkg.file -notmatch 'perccent-wallet-v([0-9.]+)-') {
        throw "Could not parse Perccent version from $($pkg.file)"
    }
    $version = $Matches[1]
    $winMb = [math]::Round($pkg.bytes / 1MB, 1)
    $releaseBase = "https://github.com/$Owner/$RepoName/releases/download/v$version"

    $html = Get-Content $DownloadsIndex -Raw
    if ($html -notmatch '<section class="perccent-wallet">') {
        throw 'downloads/index.html missing <section class="perccent-wallet">'
    }

    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?<p class="meta">)perccent-wallet-v[0-9.]+-windows-x64-setup\.exe(</p>)',
        "`${1}$($pkg.file)`${2}"
    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?href=")https://github\.com/[^/]+/[^/]+/releases/download/v[0-9.]+/perccent-wallet-v[0-9.]+-windows-x64-setup\.exe(")',
        "`${1}$releaseBase/$($pkg.file)`${2}"
    $html = $html -replace '(<code id="perccent-sha256"[^>]*>)[a-f0-9]{64}(</code>)',
        "`${1}$($pkg.sha256)`${2}"
    $html = $html -replace '(?s)(<section class="perccent-wallet">.*?href=")https://github\.com/[^/]+/[^/]+/releases/download/v[0-9.]+/perccent-wallet-v[0-9.]+-windows-x64-setup\.exe\.sha256(")',
        "`${1}$releaseBase/$($pkg.file).sha256`${2}"
    $html = $html -replace '(<code id="perccent-setup-name">)perccent-wallet-v[0-9.]+-windows-x64-setup\.exe(</code>)',
        "`${1}$($pkg.file)`${2}"

    Set-Content -Path $DownloadsIndex -Value $html -NoNewline
    return [PSCustomObject]@{
        Version = $version
        Windows = $pkg.file
        Sha256 = $pkg.sha256
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