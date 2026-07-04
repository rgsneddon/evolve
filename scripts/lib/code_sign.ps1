# Authenticode signing for Windows PE binaries (exe, dll, …).
# Requires a code-signing certificate that chains to the Microsoft Trusted Root Program.

function Find-SignTool {
    if ($env:SIGNTOOL_PATH -and (Test-Path $env:SIGNTOOL_PATH)) {
        return $env:SIGNTOOL_PATH
    }

    $kitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    if (Test-Path $kitsRoot) {
        $tool = Get-ChildItem $kitsRoot -Recurse -Filter signtool.exe -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -match '\\x64\\signtool\.exe$' } |
            Sort-Object { try { [version]$_.Directory.Name } catch { [version]'0.0' } } -Descending |
            Select-Object -First 1
        if ($tool) { return $tool.FullName }
    }

    throw @'
signtool.exe not found. Install the Windows SDK (Signing Tools for Desktop Apps)
or set SIGNTOOL_PATH to your signtool.exe path.
'@
}

function Import-CodeSignLocalEnv {
    param([string]$Root)

    $path = Join-Path $Root 'code_sign.local.env'
    if (-not (Test-Path $path)) { return $false }

    Get-Content $path | ForEach-Object {
        $line = $_.Trim()
        if (-not $line -or $line.StartsWith('#')) { return }
        $idx = $line.IndexOf('=')
        if ($idx -lt 1) { return }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()
        if ($val.StartsWith('"') -and $val.EndsWith('"')) {
            $val = $val.Substring(1, $val.Length - 2)
        }
        Set-Item -Path "env:$key" -Value $val
    }
    return $true
}

function Get-CodeSignConfig {
    param([string]$Root)

    Import-CodeSignLocalEnv -Root $Root | Out-Null

    $mode = if ($env:CODE_SIGN_MODE) { $env:CODE_SIGN_MODE.Trim().ToLowerInvariant() } else { '' }
    if (-not $mode) {
        if ($env:CODE_SIGN_PFX_PATH) { $mode = 'pfx' }
        elseif ($env:CODE_SIGN_CERT_THUMBPRINT -or $env:CODE_SIGN_CERT_SUBJECT) { $mode = 'store' }
        elseif ($env:AZURE_CODESIGN_METADATA_PATH) { $mode = 'azure' }
    }

    if (-not $mode) {
        throw @'
No code signing configuration found.

Copy code_sign.local.env.example to code_sign.local.env and set one of:
  - CODE_SIGN_MODE=pfx with CODE_SIGN_PFX_PATH + CODE_SIGN_PFX_PASSWORD
  - CODE_SIGN_MODE=store with CODE_SIGN_CERT_THUMBPRINT (or CODE_SIGN_CERT_SUBJECT)
  - CODE_SIGN_MODE=azure with AZURE_CODESIGN_DLIB_PATH + AZURE_CODESIGN_METADATA_PATH

The certificate must be a valid Authenticode code-signing cert issued by a CA in the
Microsoft Trusted Root Program (e.g. DigiCert, Sectigo, SSL.com, or Azure Trusted Signing).
'@
    }

    $timestamp = if ($env:CODE_SIGN_TIMESTAMP_URL) { $env:CODE_SIGN_TIMESTAMP_URL.Trim() } else { 'http://timestamp.digicert.com' }
    $description = if ($env:CODE_SIGN_DESCRIPTION) { $env:CODE_SIGN_DESCRIPTION.Trim() } else { 'Evolve Chronoflux' }
    $url = if ($env:CODE_SIGN_URL) { $env:CODE_SIGN_URL.Trim() } else { 'https://rgsneddon.github.io/evolve/' }

    return [PSCustomObject]@{
        Mode        = $mode
        Timestamp   = $timestamp
        Description = $description
        Url         = $url
        PfxPath     = $env:CODE_SIGN_PFX_PATH
        PfxPassword = $env:CODE_SIGN_PFX_PASSWORD
        Thumbprint  = $env:CODE_SIGN_CERT_THUMBPRINT
        Subject     = $env:CODE_SIGN_CERT_SUBJECT
        AzureDlib   = $env:AZURE_CODESIGN_DLIB_PATH
        AzureMeta   = $env:AZURE_CODESIGN_METADATA_PATH
    }
}

function Get-PeFilesInDirectory {
    param([string]$Directory)

    if (-not (Test-Path $Directory)) {
        throw "Directory not found: $Directory"
    }

    $extensions = @('.exe', '.dll', '.sys', '.ocx', '.cpl', '.efi', '.mui')
    return Get-ChildItem $Directory -Recurse -File |
        Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object FullName
}

function Test-AuthenticodeTrustedSignature {
    param(
        [string]$FilePath,
        [string]$SignTool
    )

    if (-not (Test-Path $FilePath)) {
        throw "File not found: $FilePath"
    }

    $prevEap = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        & $SignTool verify /pa $FilePath *> $null
        $exitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevEap
    }

    if ($exitCode -ne 0) {
        return [PSCustomObject]@{
            Valid   = $false
            Message = 'No Authenticode signature found'
        }
    }

    $sig = Get-AuthenticodeSignature -FilePath $FilePath
    if ($sig.Status -ne 'Valid') {
        return [PSCustomObject]@{
            Valid   = $false
            Message = "Authenticode status: $($sig.Status)"
        }
    }

    $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
    $chain.ChainPolicy.RevocationMode = [System.Security.Cryptography.X509Certificates.X509RevocationMode]::Online
    $chain.ChainPolicy.RevocationFlag = [System.Security.Cryptography.X509Certificates.X509RevocationFlag]::ExcludeRoot
    $chain.ChainPolicy.VerificationTime = [DateTime]::Now
    $chain.ChainPolicy.UrlRetrievalTimeout = New-TimeSpan -Minutes 1

    $built = $chain.Build($sig.SignerCertificate)
    if (-not $built) {
        $errors = $chain.ChainStatus | ForEach-Object { $_.StatusInformation } | Where-Object { $_ }
        return [PSCustomObject]@{
            Valid   = $false
            Message = ($errors -join '; ')
        }
    }

    return [PSCustomObject]@{
        Valid      = $true
        Message    = 'Valid Authenticode signature with trusted CA chain'
        Signer     = $sig.SignerCertificate.Subject
        Thumbprint = $sig.SignerCertificate.Thumbprint
    }
}

function Get-SignToolArguments {
    param(
        [object]$Config,
        [string]$FilePath
    )

    $common = @(
        'sign',
        '/fd', 'sha256',
        '/td', 'sha256',
        '/tr', $Config.Timestamp,
        '/d', $Config.Description,
        '/du', $Config.Url,
        '/v'
    )

    switch ($Config.Mode) {
        'pfx' {
            if (-not $Config.PfxPath -or -not (Test-Path $Config.PfxPath)) {
                throw "CODE_SIGN_PFX_PATH is missing or not found: $($Config.PfxPath)"
            }
            if (-not $Config.PfxPassword) {
                throw 'CODE_SIGN_PFX_PASSWORD is required for PFX signing.'
            }
            return $common + @('/f', $Config.PfxPath, '/p', $Config.PfxPassword, $FilePath)
        }
        'store' {
            if ($Config.Thumbprint) {
                return $common + @('/sha1', $Config.Thumbprint, $FilePath)
            }
            if ($Config.Subject) {
                return $common + @('/n', $Config.Subject, $FilePath)
            }
            throw 'CODE_SIGN_CERT_THUMBPRINT or CODE_SIGN_CERT_SUBJECT is required for store signing.'
        }
        'azure' {
            if (-not $Config.AzureDlib -or -not (Test-Path $Config.AzureDlib)) {
                throw "AZURE_CODESIGN_DLIB_PATH is missing or not found: $($Config.AzureDlib)"
            }
            if (-not $Config.AzureMeta -or -not (Test-Path $Config.AzureMeta)) {
                throw "AZURE_CODESIGN_METADATA_PATH is missing or not found: $($Config.AzureMeta)"
            }
            if (-not $Config.Timestamp) {
                $Config.Timestamp = 'http://timestamp.integrity.microsoft.com'
            }
            return @(
                'sign',
                '/fd', 'sha256',
                '/td', 'sha256',
                '/tr', $Config.Timestamp,
                '/dlib', $Config.AzureDlib,
                '/dmdf', $Config.AzureMeta,
                '/v',
                $FilePath
            )
        }
        default {
            throw "Unsupported CODE_SIGN_MODE: $($Config.Mode). Use pfx, store, or azure."
        }
    }
}

function Sign-AuthenticodeFile {
    param(
        [string]$FilePath,
        [object]$Config,
        [string]$SignTool
    )

    if (-not (Test-Path $FilePath)) {
        throw "Cannot sign missing file: $FilePath"
    }

    $args = Get-SignToolArguments -Config $Config -FilePath $FilePath
    Write-Host "Signing: $FilePath" -ForegroundColor Cyan
    & $SignTool @args
    if ($LASTEXITCODE -ne 0) {
        throw "signtool failed ($LASTEXITCODE) for $FilePath"
    }

    $verify = Test-AuthenticodeTrustedSignature -FilePath $FilePath -SignTool $SignTool
    if (-not $verify.Valid) {
        throw "Signature verification failed for ${FilePath}: $($verify.Message)"
    }

    Write-Host "  OK: $($verify.Signer)" -ForegroundColor Green
    return $verify
}

function Sign-WindowsPeBinaries {
    param(
        [string]$Directory,
        [string]$Root,
        [switch]$SkipCodeSign
    )

    if ($SkipCodeSign) {
        Write-Host 'Skipping Authenticode signing (-SkipCodeSign).' -ForegroundColor Yellow
        return
    }

    $signTool = Find-SignTool
    $config = Get-CodeSignConfig -Root $Root
    $files = Get-PeFilesInDirectory -Directory $Directory

    if (-not $files) {
        Write-Host "No PE files found under $Directory" -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host ('=== Authenticode signing ({0} PE binaries) ===' -f $files.Count) -ForegroundColor Cyan
    Write-Host "Mode: $($config.Mode)" -ForegroundColor Cyan

    foreach ($file in $files) {
        Sign-AuthenticodeFile -FilePath $file.FullName -Config $config -SignTool $signTool | Out-Null
    }

    Write-Host ''
    Write-Host 'All PE binaries signed and verified.' -ForegroundColor Green
}

function Test-WindowsPeBinariesSigned {
    param(
        [string]$Directory,
        [switch]$AllowUnsigned
    )

    $signTool = Find-SignTool
    $files = Get-PeFilesInDirectory -Directory $Directory
    $unsigned = @()

    foreach ($file in $files) {
        $verify = Test-AuthenticodeTrustedSignature -FilePath $file.FullName -SignTool $signTool
        if (-not $verify.Valid) {
            $unsigned += [PSCustomObject]@{
                File    = $file.FullName
                Message = $verify.Message
            }
        }
    }

    if ($unsigned.Count -eq 0) {
        Write-Host ('All {0} PE binaries are Authenticode-signed with a trusted CA chain.' -f $files.Count) -ForegroundColor Green
        return $true
    }

    Write-Host ('Unsigned or untrusted PE binaries: {0}' -f $unsigned.Count) -ForegroundColor Red
    $unsigned | ForEach-Object { Write-Host "  $($_.File): $($_.Message)" -ForegroundColor Red }

    if ($AllowUnsigned) { return $false }
    throw 'One or more PE binaries lack a valid Authenticode signature. Configure code_sign.local.env and rebuild.'
}