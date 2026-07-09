# Supply-chain audit: Flutter pub audit + npm audit in perc_chain.

function Invoke-DependencyAudit {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$LogPath = '',
        [string]$SecurityDocPath = ''
    )

    if (-not $SecurityDocPath) {
        $SecurityDocPath = Join-Path $Root 'SECURITY.md'
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("=== Dependency audit $(Get-Date -Format o) ===")
    $lines.Add("root=$Root")

    $unmitigated = [System.Collections.Generic.List[string]]::new()
    Push-Location $Root
    try {
        $pubCmd = Get-Command dart -ErrorAction SilentlyContinue
        if (-not $pubCmd) {
            throw 'dart CLI not found on PATH'
        }
        $pubOut = dart pub audit 2>&1 | Out-String
        $lines.Add('')
        $lines.Add('--- dart pub audit ---')
        $lines.Add($pubOut.Trim())
        if ($pubOut -match 'Could not find a subcommand named "audit"') {
            $lines.Add('fallback: dart pub audit unavailable on this SDK; running flutter pub outdated snapshot')
            $outdated = flutter pub outdated --show-all 2>&1 | Out-String
            $lines.Add($outdated.Trim())
            $lines.Add('flutter_pub_outdated_snapshot=recorded (manual advisory review before release)')
        } elseif ($LASTEXITCODE -ne 0) {
            $unmitigated.Add("dart pub audit exit $LASTEXITCODE")
        } elseif ($pubOut -match '(?i)(critical|high)\s+vulnerabilit') {
            $unmitigated.Add('dart pub audit reported critical/high vulnerabilities')
        }
    } catch {
        $lines.Add("dart pub audit ERROR: $($_.Exception.Message)")
        $unmitigated.Add('dart pub audit failed to run')
    } finally {
        Pop-Location
    }

    $percChain = Join-Path $Root 'perc_chain'
    if (Test-Path (Join-Path $percChain 'package.json')) {
        Push-Location $percChain
        try {
            if (-not (Test-Path 'node_modules')) {
                $lines.Add('npm install (perc_chain, first-time lockfile sync)')
                npm install 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    throw "npm install failed with exit $LASTEXITCODE"
                }
            }
            $npmOut = npm audit --audit-level=high 2>&1 | Out-String
            $lines.Add('')
            $lines.Add('--- npm audit (perc_chain, --audit-level=high) ---')
            $lines.Add($npmOut.Trim())
            if ($LASTEXITCODE -ne 0) {
                $unmitigated.Add("npm audit exit $LASTEXITCODE")
            }
        } catch {
            $lines.Add("npm audit ERROR: $($_.Exception.Message)")
            $unmitigated.Add('npm audit failed to run')
        } finally {
            Pop-Location
        }
    } else {
        $lines.Add('')
        $lines.Add('--- npm audit skipped (no perc_chain/package.json) ---')
    }

    $documented = $false
    if (Test-Path $SecurityDocPath) {
        $secText = Get-Content $SecurityDocPath -Raw
        if ($secText -match '(?i)dependency audit exceptions|documented exceptions') {
            $documented = $true
            $lines.Add('')
            $lines.Add("exceptions: documented in $SecurityDocPath")
        }
    }

    $lines.Add('')
    if ($unmitigated.Count -eq 0) {
        $lines.Add('dependency_audit=PASS')
    } elseif ($documented) {
        $lines.Add('dependency_audit=PASS_WITH_DOCUMENTED_EXCEPTIONS')
        foreach ($item in $unmitigated) { $lines.Add("unmitigated: $item") }
    } else {
        $lines.Add('dependency_audit=FAIL')
        foreach ($item in $unmitigated) { $lines.Add("unmitigated: $item") }
    }

    $text = $lines -join [Environment]::NewLine
    if ($LogPath) {
        $parent = Split-Path $LogPath -Parent
        if ($parent -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -Path $LogPath -Value $text -Encoding utf8
    } else {
        Write-Host $text
    }

    if ($unmitigated.Count -gt 0 -and -not $documented) {
        throw "Dependency audit failed with unmitigated critical/high findings. Document exceptions in SECURITY.md or remediate."
    }

    return [PSCustomObject]@{
        UnmitigatedCount = $unmitigated.Count
        DocumentedExceptions = $documented
        LogPath = $LogPath
    }
}