# Supply-chain audit: Dart pub audit (or SDK fallback) + npm audit in perc_chain.

function Get-DocumentedSecurityExceptionIds {
    param([string]$SecurityText)

    $ids = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($SecurityText -split "`r?`n")) {
        if ($line -match 'EX-([a-z0-9_]+)') {
            [void]$ids.Add($Matches[1])
        }
    }
    return $ids
}

function Test-FindingsDocumentedInSecurityPolicy {
    param(
        [System.Collections.IEnumerable]$RecordedFindings,
        [Parameter(Mandatory = $true)][string]$SecurityText
    )

    if (-not $RecordedFindings -or @($RecordedFindings).Count -eq 0) {
        return $true
    }

    $documented = Get-DocumentedSecurityExceptionIds -SecurityText $SecurityText
    foreach ($finding in $RecordedFindings) {
        if ($documented -notcontains $finding.Id) {
            return $false
        }
    }
    return $true
}

function Merge-AuditSectionResult {
    param(
        [System.Collections.Generic.List[string]]$TargetLog,
        [System.Collections.Generic.List[object]]$TargetFindings,
        [psobject]$SectionResult
    )

    foreach ($entry in $SectionResult.LogEntries) {
        [void]$TargetLog.Add($entry)
    }
    foreach ($finding in $SectionResult.Findings) {
        [void]$TargetFindings.Add($finding)
    }
}

function Invoke-DartPubAuditSection {
    $sectionLog = [System.Collections.Generic.List[string]]::new()
    $sectionFindings = [System.Collections.Generic.List[object]]::new()

    if (-not (Get-Command dart -ErrorAction SilentlyContinue)) {
        $sectionFindings.Add([PSCustomObject]@{
            Id = 'dart_cli_missing'
            Detail = 'dart CLI not found on PATH'
        }) | Out-Null
        $sectionLog.Add('dart pub audit: SKIPPED (dart CLI missing)')
        return [PSCustomObject]@{
            LogEntries = $sectionLog
            Findings = $sectionFindings
        }
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $pubLines = & dart pub audit 2>&1
    $pubExit = $LASTEXITCODE
    $ErrorActionPreference = $prevEap

    $pubOut = ($pubLines | ForEach-Object { "$_" }) -join [Environment]::NewLine
    $sectionLog.Add('')
    $sectionLog.Add('--- dart pub audit ---')
    $sectionLog.Add($pubOut.Trim())

    if ($pubOut -match 'Could not find a subcommand named "audit"') {
        $sectionLog.Add('fallback: dart pub audit unavailable on this SDK; running flutter pub outdated snapshot')
        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $outdatedLines = & flutter pub outdated --show-all 2>&1
        $ErrorActionPreference = $prevEap
        $outdated = ($outdatedLines | ForEach-Object { "$_" }) -join [Environment]::NewLine
        $sectionLog.Add($outdated.Trim())
        $sectionLog.Add('flutter_pub_outdated_snapshot=recorded (manual advisory review before release)')
        $sectionFindings.Add([PSCustomObject]@{
            Id = 'dart_pub_audit_unavailable'
            Detail = 'dart pub audit subcommand not available on installed Dart SDK'
        }) | Out-Null
        return [PSCustomObject]@{
            LogEntries = $sectionLog
            Findings = $sectionFindings
        }
    }

    if ($pubExit -ne 0) {
        $sectionFindings.Add([PSCustomObject]@{
            Id = "dart_pub_audit_exit_$pubExit"
            Detail = "dart pub audit exited with code $pubExit"
        }) | Out-Null
        return [PSCustomObject]@{
            LogEntries = $sectionLog
            Findings = $sectionFindings
        }
    }

    if ($pubOut -match '(?i)(critical|high)\s+vulnerabilit') {
        $sectionFindings.Add([PSCustomObject]@{
            Id = 'dart_pub_audit_high_critical'
            Detail = 'dart pub audit reported critical/high vulnerabilities'
        }) | Out-Null
    }

    return [PSCustomObject]@{
        LogEntries = $sectionLog
        Findings = $sectionFindings
    }
}

function Invoke-NpmAuditSection {
    param([Parameter(Mandatory = $true)][string]$PercChainDir)

    $sectionLog = [System.Collections.Generic.List[string]]::new()
    $sectionFindings = [System.Collections.Generic.List[object]]::new()

    if (-not (Test-Path (Join-Path $PercChainDir 'package.json'))) {
        $sectionLog.Add('')
        $sectionLog.Add('--- npm audit skipped (no perc_chain/package.json) ---')
        return [PSCustomObject]@{
            LogEntries = $sectionLog
            Findings = $sectionFindings
        }
    }

    Push-Location $PercChainDir
    try {
        if (-not (Test-Path 'node_modules')) {
            $sectionLog.Add('npm install (perc_chain, first-time lockfile sync)')
            $prevEap = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $null = & npm install 2>&1
            $installExit = $LASTEXITCODE
            $ErrorActionPreference = $prevEap
            if ($installExit -ne 0) {
                $sectionFindings.Add([PSCustomObject]@{
                    Id = 'npm_install_failed'
                    Detail = "npm install failed with exit $installExit"
                }) | Out-Null
                return [PSCustomObject]@{
                    LogEntries = $sectionLog
                    Findings = $sectionFindings
                }
            }
        }

        $prevEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $npmLines = & npm audit --audit-level=high 2>&1
        $npmExit = $LASTEXITCODE
        $ErrorActionPreference = $prevEap

        $npmOut = ($npmLines | ForEach-Object { "$_" }) -join [Environment]::NewLine
        $sectionLog.Add('')
        $sectionLog.Add('--- npm audit (perc_chain, --audit-level=high) ---')
        $sectionLog.Add($npmOut.Trim())

        if ($npmExit -ne 0) {
            $sectionFindings.Add([PSCustomObject]@{
                Id = "npm_audit_exit_$npmExit"
                Detail = "npm audit --audit-level=high exited with code $npmExit"
            }) | Out-Null
        }
    } finally {
        Pop-Location
    }

    return [PSCustomObject]@{
        LogEntries = $sectionLog
        Findings = $sectionFindings
    }
}

function Invoke-DependencyAudit {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [string]$LogPath = '',
        [string]$SecurityDocPath = ''
    )

    if (-not $SecurityDocPath) {
        $SecurityDocPath = Join-Path $Root 'SECURITY.md'
    }

    $repoLog = [System.Collections.Generic.List[string]]::new()
    $repoFindings = [System.Collections.Generic.List[object]]::new()
    $repoLog.Add("=== Dependency audit $(Get-Date -Format o) ===")
    $repoLog.Add("root=$Root")

    Push-Location $Root
    try {
        $dartSection = Invoke-DartPubAuditSection
        Merge-AuditSectionResult -TargetLog $repoLog -TargetFindings $repoFindings -SectionResult $dartSection
    } finally {
        Pop-Location
    }

    $npmSection = Invoke-NpmAuditSection -PercChainDir (Join-Path $Root 'perc_chain')
    Merge-AuditSectionResult -TargetLog $repoLog -TargetFindings $repoFindings -SectionResult $npmSection

    $securityText = ''
    if (Test-Path $SecurityDocPath) {
        $securityText = Get-Content $SecurityDocPath -Raw
    }

    $allDocumented = if ($repoFindings.Count -eq 0) {
        $true
    } else {
        Test-FindingsDocumentedInSecurityPolicy -RecordedFindings @($repoFindings) -SecurityText $securityText
    }

    $repoLog.Add('')
    if ($repoFindings.Count -eq 0) {
        $repoLog.Add('dependency_audit=PASS')
    } elseif ($allDocumented) {
        $repoLog.Add('dependency_audit=PASS_WITH_DOCUMENTED_EXCEPTIONS')
        foreach ($finding in $repoFindings) {
            $repoLog.Add("documented_exception: EX-$($finding.Id) - $($finding.Detail)")
        }
    } else {
        $repoLog.Add('dependency_audit=FAIL')
        foreach ($finding in $repoFindings) {
            $repoLog.Add("unmitigated: EX-$($finding.Id) - $($finding.Detail)")
        }
        $missing = @($repoFindings | ForEach-Object { $_.Id } | Where-Object {
            (Get-DocumentedSecurityExceptionIds -SecurityText $securityText) -notcontains $_
        })
        if ($missing.Count -gt 0) {
            $repoLog.Add("missing_security_md_ids: $($missing -join ', ')")
        }
    }

    $text = $repoLog -join [Environment]::NewLine
    if ($LogPath) {
        $parent = Split-Path $LogPath -Parent
        if ($parent -and -not (Test-Path $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -Path $LogPath -Value $text -Encoding utf8
    } else {
        Write-Host $text
    }

    if ($repoFindings.Count -gt 0 -and -not $allDocumented) {
        throw "Dependency audit failed: unmitigated findings without matching EX-* ids in SECURITY.md"
    }

    return [PSCustomObject]@{
        FindingCount = $repoFindings.Count
        AllDocumented = $allDocumented
        LogPath = $LogPath
    }
}