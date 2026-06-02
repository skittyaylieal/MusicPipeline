Param (
    [string]$CookiePath,
    [string]$YTDLPPath,
    [string]$TestURL
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Cookie Validator" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $CookiePath -PathType Leaf)) {
    Write-Host "[ERROR] Target cookie file couldn't be found" -ForegroundColor Red
    Exit 1
}

if (-not (Test-Path -LiteralPath $YTDLPPath -PathType Leaf)) {
    Write-Host "[ERROR] yt-dlp executable couldn't be found" -ForegroundColor Red
    Exit 1
}

Write-Host "[+] Cookie and yt-dlp files located successfully" -ForegroundColor Green
Write-Host "[*] Testing YouTube cookie status" -ForegroundColor Yellow

& $YTDLPPath --cookies "$CookiePath" --simulate --quiet $TestURL 2>$null

if ($LastExitCode -ne 0) {
    Write-Host "=============================================" -ForegroundColor Red
    Write-Host "[ERROR] YouTube authentication failed!" -ForegroundColor Red
    Write-Host "The cookies.txt has expired or is invalid." -ForegroundColor Yellow
    Write-Host "=============================================" -ForegroundColor Red
    Exit 1
}

Write-Host "[+] Cookies authenticated successfully." -ForegroundColor Green
$MetricStopwatch.Stop()
$Elapsed =  String -Format "{0:hh\:mm\:ss}" $MetricStopwatch.Elapsed
Write-Host "[METRIC] $Elapsed"
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0