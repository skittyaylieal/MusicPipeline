param (
    [string]$CookiePath,
    [string]$YTDLPPath,
    [string]$TestURL
)

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Cookie Validator" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Verify cookie path isn't empty
# FIX: Swapped to -LiteralPath to protect against bracketed directory names
if (-not (Test-Path -LiteralPath $CookiePath -PathType Leaf)) {
    Write-Host "[ERROR] Target cookie file couldn't be found" -ForegroundColor Red
    Write-Host "Checked Path: $CookiePath" -ForegroundColor Yellow
    # Output failure and report back to main script
    Exit 1
}

# Verify yt-dlp path isn't empty
# FIX: Swapped to -LiteralPath to protect against bracketed directory names
if (-not (Test-Path -LiteralPath $YTDLPPath -PathType Leaf)) {
    # Note: Fixed a small native typo in your original file ("-ForgroundColor" -> "-ForegroundColor")
    Write-Host "[ERROR] yt-dlp executable couldn't be found" -ForegroundColor Red
    Write-Host "Checked Path: $YTDLPPath" -ForegroundColor Yellow
    Exit 1
}

Write-Host "[+] Cookie and yt-dlp files located successfully" -ForegroundColor Green
Write-Host "[*] Testing Youtube cookie status" -ForegroundColor Yellow

# Run yt-dlp with a silent test to validate cookies
# FIX: Wrapped paths in explicit string quotes to freeze them for the external executable call
& $YTDLPPath --cookies "$CookiePath" --simulate --quiet $TestURL 2>$null

# Check result
if ($LastExitCode -ne 0) {
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host "[ERROR] YouTube authentication failed!" -ForegroundColor Red
    Write-Host "The cookies.txt has expired or is invalid." -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Red
    Exit 1
}

Write-Host "[+] Cookies authenticated successfully." -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0