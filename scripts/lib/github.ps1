# GitHub owner/repo helpers for Evolve deploy scripts.

function Get-GitHubOwner {
    param(
        [string]$Root = (Get-Location).Path,
        [string]$Fallback = 'rgsneddon'
    )

    if ($env:GITHUB_REPOSITORY_OWNER) {
        return $env:GITHUB_REPOSITORY_OWNER.Trim()
    }

    Push-Location $Root
    try {
        $url = git remote get-url origin 2>$null
        if ($url -match 'github\.com[:/]([^/]+)/') {
            return $Matches[1]
        }
    } finally {
        Pop-Location
    }

    return $Fallback
}

function Ensure-GitIdentity {
    param(
        [string]$Root = (Get-Location).Path,
        [string]$Owner = $(Get-GitHubOwner -Root $Root)
    )

    Push-Location $Root
    try {
        if (-not (git config user.email)) {
            git config user.email "$Owner@users.noreply.github.com"
        }
        if (-not (git config user.name)) {
            git config user.name $Owner
        }
    } finally {
        Pop-Location
    }
}

function Get-GitHubToken {
    $cred = "protocol=https`nhost=github.com`n" | git credential fill 2>$null
    if (-not $cred) {
        throw 'GitHub credentials not found. Run: gh auth login (or configure git credential helper).'
    }
    $token = ($cred | Select-String '^password=(.+)$').Matches.Groups[1].Value
    if (-not $token) {
        throw 'Could not read GitHub token from git credential helper.'
    }
    return $token
}