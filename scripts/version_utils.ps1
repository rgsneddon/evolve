# Shared Evolve version parsing and max-version discovery.

function Parse-AppVersion {
    param([string]$Text)
    if ($Text -match '(\d+)\.(\d+)\.(\d+)\+(\d+)') {
        return [pscustomobject]@{
            Major = [int]$Matches[1]
            Minor = [int]$Matches[2]
            Patch = [int]$Matches[3]
            Build = [int]$Matches[4]
        }
    }
    return $null
}

function Format-AppVersion {
    param(
        [int]$Major,
        [int]$Minor,
        [int]$Patch,
        [int]$Build
    )
    $release = "$Major.$Minor.$Patch"
    return [pscustomobject]@{
        Release = $release
        Full    = "$release+$Build"
    }
}

function Compare-AppVersion {
    param($Left, $Right)
    foreach ($part in @('Major', 'Minor', 'Patch', 'Build')) {
        $delta = $Left.$part - $Right.$part
        if ($delta -ne 0) { return $delta }
    }
    return 0
}

function Get-MaxAppVersion {
    param(
        [string]$Root,
        [string[]]$ExtraTexts = @(),
        [switch]$ExcludeLocalPubspec
    )

    $candidates = New-Object System.Collections.Generic.List[object]

    $pubspecPath = Join-Path $Root 'pubspec.yaml'
    if (-not $ExcludeLocalPubspec -and (Test-Path $pubspecPath)) {
        $parsed = Parse-AppVersion (Get-Content $pubspecPath -Raw)
        if ($parsed) { $candidates.Add($parsed) }
    }

    foreach ($text in $ExtraTexts) {
        $parsed = Parse-AppVersion $text
        if ($parsed) { $candidates.Add($parsed) }
    }

    $git = Get-Command git -ErrorAction SilentlyContinue
    if ($git) {
        Push-Location $Root
        try {
            $null = git rev-parse --git-dir 2>$null
            if ($LASTEXITCODE -eq 0) {
                $refs = @('origin/main')
                if (-not $ExcludeLocalPubspec) {
                    $refs += @('main', 'HEAD')
                }
                foreach ($ref in $refs) {
                    $raw = git show "${ref}:pubspec.yaml" 2>$null
                    if ($LASTEXITCODE -eq 0 -and $raw) {
                        $parsed = Parse-AppVersion $raw
                        if ($parsed) { $candidates.Add($parsed) }
                    }
                }

                $tags = git tag -l 'v*' 2>$null
                foreach ($tag in $tags) {
                    $tagText = $tag -replace '^v', ''
                    $parsed = Parse-AppVersion "${tagText}+0"
                    if ($parsed) { $candidates.Add($parsed) }
                }

                $logVersions = git log -n 50 --pretty=format:%s 2>$null |
                    ForEach-Object {
                        if ($_ -match 'bump version to (\d+\.\d+\.\d+\+\d+)') { $Matches[1] }
                    }
                foreach ($entry in $logVersions) {
                    $parsed = Parse-AppVersion $entry
                    if ($parsed) { $candidates.Add($parsed) }
                }
            }
        } finally {
            Pop-Location
        }
    }

    if ($candidates.Count -eq 0) {
        throw 'No app version candidates found'
    }

    $max = $candidates[0]
    foreach ($candidate in $candidates) {
        if ((Compare-AppVersion $candidate $max) -gt 0) {
            $max = $candidate
        }
    }
    return $max
}

function Get-PublishedMaxAppVersion {
    param([string]$Root)

    $candidates = New-Object System.Collections.Generic.List[object]
    $git = Get-Command git -ErrorAction SilentlyContinue
    if (-not $git) {
        return Get-MaxAppVersion -Root $Root -ExcludeLocalPubspec
    }

    Push-Location $Root
    try {
        $null = git rev-parse --git-dir 2>$null
        if ($LASTEXITCODE -ne 0) {
            return Get-MaxAppVersion -Root $Root -ExcludeLocalPubspec
        }

        $raw = git show 'origin/main:pubspec.yaml' 2>$null
        if ($LASTEXITCODE -eq 0 -and $raw) {
            $parsed = Parse-AppVersion $raw
            if ($parsed) { $candidates.Add($parsed) }
        }

        $tags = git tag -l 'v*' 2>$null
        foreach ($tag in $tags) {
            $tagText = $tag -replace '^v', ''
            $parsed = Parse-AppVersion "${tagText}+0"
            if ($parsed) { $candidates.Add($parsed) }
        }

        $logVersions = git log origin/main -n 50 --pretty=format:%s 2>$null |
            ForEach-Object {
                if ($_ -match 'bump version to (\d+\.\d+\.\d+\+\d+)') { $Matches[1] }
            }
        foreach ($entry in $logVersions) {
            $parsed = Parse-AppVersion $entry
            if ($parsed) { $candidates.Add($parsed) }
        }
    } finally {
        Pop-Location
    }

    if ($candidates.Count -eq 0) {
        return Get-MaxAppVersion -Root $Root -ExcludeLocalPubspec
    }

    $max = $candidates[0]
    foreach ($candidate in $candidates) {
        if ((Compare-AppVersion $candidate $max) -gt 0) {
            $max = $candidate
        }
    }
    return $max
}

function Get-NextAppVersion {
    param(
        [string]$Root,
        [switch]$PatchOnly,
        [switch]$BuildOnly,
        [switch]$FromPublishedMax
    )

    if ($FromPublishedMax) {
        $max = Get-PublishedMaxAppVersion -Root $Root
    } else {
        $max = Get-MaxAppVersion -Root $Root
    }
    $major = $max.Major
    $minor = $max.Minor
    $patch = $max.Patch
    $build = $max.Build

    if ($BuildOnly) {
        $build += 1
    } elseif ($PatchOnly) {
        $patch += 1
        $build += 1
    } else {
        $patch += 1
        $build += 1
    }

    return Format-AppVersion -Major $major -Minor $minor -Patch $patch -Build $build
}