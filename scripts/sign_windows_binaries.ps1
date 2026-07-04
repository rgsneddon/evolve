# Sign all PE binaries in the Windows Release folder (or a custom directory).
param(
    [string]$Directory = '',
    [switch]$SkipCodeSign,
    [switch]$VerifyOnly
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
. "$PSScriptRoot\lib\code_sign.ps1"

if (-not $Directory) {
    $Directory = Join-Path $Root 'build\windows\x64\runner\Release'
}

Set-Location $Root

if ($VerifyOnly) {
    Test-WindowsPeBinariesSigned -Directory $Directory -AllowUnsigned
    exit 0
}

Sign-WindowsPeBinaries -Directory $Directory -Root $Root -SkipCodeSign:$SkipCodeSign