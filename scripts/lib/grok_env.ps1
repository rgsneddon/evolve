# Shared Grok proxy environment helpers.

function Import-GrokLocalEnv {
    param([string]$Root)

    $envFile = Join-Path $Root 'grok_proxy.local.env'
    if (-not (Test-Path $envFile)) { return $false }

    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"')
            Set-Item -Path "env:$name" -Value $value
        }
    }
    return $true
}

function Set-GrokDartPath {
    $dartCandidates = @(
        'C:\src\flutter\bin\cache\dart-sdk\bin',
        (Join-Path $env:LOCALAPPDATA 'flutter\bin\cache\dart-sdk\bin')
    )
    foreach ($dartBin in $dartCandidates) {
        if (Test-Path $dartBin) {
            if ($env:Path -notlike "*$dartBin*") { $env:Path = "$dartBin;$env:Path" }
            return $dartBin
        }
    }
    return $null
}

function Stop-GrokProxy {
    param([int]$Port = 8787)

    Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty OwningProcess -Unique |
        Where-Object { $_ -gt 0 } |
        ForEach-Object { Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }
}

function Test-GrokProxyHealth {
    param([int]$Port = 8787)

    try {
        $res = Invoke-WebRequest -Uri "http://127.0.0.1:$Port/health" -UseBasicParsing -TimeoutSec 2
        return $res.StatusCode -eq 200
    } catch {
        return $false
    }
}