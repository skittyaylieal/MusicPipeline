Param (
    [string]$CookiePath,
    [string]$YTDLPPath,
    [string]$TestURL
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Clear-Host

Write-Output "=============================================" -ForegroundColor Cyan
Write-Output "    PowerShell Module: Cookie Validator" -ForegroundColor Cyan
Write-Output "=============================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $CookiePath -PathType Leaf)) {
    Write-Output "[ERROR] Target cookie file couldn't be found" -ForegroundColor Red
    Exit 1
}

if (-not (Test-Path -LiteralPath $YTDLPPath -PathType Leaf)) {
    Write-Output "[ERROR] yt-dlp executable couldn't be found" -ForegroundColor Red
    Exit 1
}

Write-Output "[+] Cookie and yt-dlp files located successfully" -ForegroundColor Green
Write-Output "[*] Testing YouTube cookie status" -ForegroundColor Yellow

& $YTDLPPath --cookies "$CookiePath" --simulate --quiet $TestURL 2>$null

if ($LastExitCode -ne 0) {
    Write-Output "=============================================" -ForegroundColor Red
    Write-Output "[ERROR] YouTube authentication failed!" -ForegroundColor Red
    Write-Output "The cookies.txt has expired or is invalid." -ForegroundColor Yellow
    Write-Output "=============================================" -ForegroundColor Red
    Exit 1
}

Write-Output "[+] Cookies authenticated successfully." -ForegroundColor Green
$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] $Elapsed"
Write-Output "=============================================" -ForegroundColor Cyan
Exit 0