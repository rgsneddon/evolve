# Stage bundled WireGuard runtime + full-tunnel profile into the Windows Release folder.
# Operator secrets (demo1.conf) are copied at build time only — never committed to git.
param(
    [string]$ReleaseDir = '',
    [string]$VpnSecretsConf = '',
    [switch]$SkipWireGuardDownload
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent

if (-not $ReleaseDir) {
    $ReleaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
}

$vpnDir = Join-Path $ReleaseDir 'vpn'
New-Item -ItemType Directory -Path $vpnDir -Force | Out-Null

function Find-VpnProfileSource {
    param([string]$Explicit)
    $candidates = @()
    if ($Explicit) { $candidates += $Explicit }
    if ($env:EVOLVE_VPN_SECRETS_CONF) { $candidates += $env:EVOLVE_VPN_SECRETS_CONF }
    $candidates += @(
        (Join-Path $Root '..\VPN-RASKUL\secrets\demo1.conf'),
        (Join-Path $env:USERPROFILE 'VPN-RASKUL\secrets\demo1.conf')
    )
    foreach ($p in $candidates) {
        if ($p -and (Test-Path $p)) { return (Resolve-Path $p).Path }
    }
    return $null
}

function Ensure-WireGuardMsi {
    $cache = Join-Path $Root 'build\vpn-cache'
    New-Item -ItemType Directory -Path $cache -Force | Out-Null
    $msi = Get-ChildItem $cache -Filter '*.msi' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($msi) { return $msi.FullName }

    Write-Host 'Downloading WireGuard MSI (winget)...' -ForegroundColor Cyan
    winget download --id WireGuard.WireGuard --download-directory $cache --accept-package-agreements
    if ($LASTEXITCODE -ne 0) { throw 'winget download WireGuard.WireGuard failed' }
    $msi = Get-ChildItem $cache -Filter '*.msi' | Select-Object -First 1
    if (-not $msi) { throw "WireGuard MSI not found under $cache" }
    return $msi.FullName
}

function Extract-WireGuardBinaries {
    param([string]$MsiPath, [string]$DestDir)
    $extractRoot = Join-Path (Split-Path $MsiPath -Parent) 'extract'
    if (Test-Path $extractRoot) { Remove-Item $extractRoot -Recurse -Force }
    New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
    $args = @('/a', "`"$MsiPath`"", '/qn', "TARGETDIR=`"$extractRoot`"")
    Start-Process msiexec.exe -ArgumentList $args -Wait -NoNewWindow | Out-Null
    $wgSource = Join-Path $extractRoot 'WireGuard'
    if (-not (Test-Path $wgSource)) { throw "WireGuard extract folder missing: $wgSource" }
    foreach ($name in @('wireguard.exe', 'wg.exe')) {
        $src = Join-Path $wgSource $name
        if (-not (Test-Path $src)) { throw "Missing $name in WireGuard MSI extract" }
        Copy-Item $src (Join-Path $DestDir $name) -Force
    }
}

# WireGuard runtime
if (-not $SkipWireGuardDownload) {
    $programWg = Join-Path ${env:ProgramFiles} 'WireGuard\wireguard.exe'
    if (Test-Path $programWg) {
        Copy-Item $programWg (Join-Path $vpnDir 'wireguard.exe') -Force
        $programCli = Join-Path ${env:ProgramFiles} 'WireGuard\wg.exe'
        if (Test-Path $programCli) {
            Copy-Item $programCli (Join-Path $vpnDir 'wg.exe') -Force
        }
    } else {
        $msiPath = Ensure-WireGuardMsi
        Extract-WireGuardBinaries -MsiPath $msiPath -DestDir $vpnDir
    }
}

# Full-tunnel profile (build-time secrets only)
$profileSrc = Find-VpnProfileSource -Explicit $VpnSecretsConf
$profileDest = Join-Path $vpnDir 'demo1.conf'
if ($profileSrc) {
    Copy-Item $profileSrc $profileDest -Force
    Write-Host "Staged VPN profile from $profileSrc" -ForegroundColor Green
} else {
    Write-Warning 'No operator VPN profile found (VPN-RASKUL/secrets/demo1.conf). VPN tab will need EVOLVE_TUNNEL_CONF.'
}

# Manifest for packaging audit tests
$manifest = @{
    bundle_version = 1
    vpn_dir = 'vpn'
    runtime_files = @('wireguard.exe', 'wg.exe')
    profile_file = 'demo1.conf'
    node_endpoint = '104.156.224.47:51820'
    staged_at = (Get-Date).ToUniversalTime().ToString('o')
    profile_staged = [bool](Test-Path $profileDest)
    runtime_staged = (Test-Path (Join-Path $vpnDir 'wireguard.exe'))
}
$manifestPath = Join-Path $vpnDir 'bundle.manifest.json'
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Path $manifestPath -Encoding UTF8

Write-Host "VPN bundle staged under $vpnDir" -ForegroundColor Green
Get-ChildItem $vpnDir | ForEach-Object { Write-Host "  $($_.Name) ($($_.Length) bytes)" }
exit 0