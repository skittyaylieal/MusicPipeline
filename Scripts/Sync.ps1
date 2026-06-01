Param (
    [string]$MobileDir,
    [string]$PhoneIP,
    [int]$TermuxPort = 8022,
    [string]$SSHKeyPath = "$env:USERPROFILE\.ssh\id_ed25519",
    [string]$RemoteTarget
)

# Fake clear
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Compressed Music Syncer" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Verifying compressed path
if (-not (Test-Path -LiteralPath $MobileDir -PathType Container)) {
    Write-Host "[ERROR] Compressed directory could not be found: $MobileDir" -ForegroundColor Red
    Exit 1
}

# Check phone is online

try (-not (Test-Connection -ComputerName $PhoneIP -Count 1 -Quiet)) {
    Write-Host "[ERROR] Phone not online on network" -ForegroundColor Red
    Exit 1

