Param (
    [string]$CookiePath,
    [string]$YTDLPPath,
    [string]$TestURL
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Clear-Host

Write-Output "============================================="
Write-Output "    PowerShell Module: Cookie Validator"
Write-Output "============================================="

if (-not (Test-Path -LiteralPath $CookiePath -PathType Leaf)) {
    Write-Output "[ERROR] Target cookie file couldn't be found"
    Exit 1
}

if (-not (Test-Path -LiteralPath $YTDLPPath -PathType Leaf)) {
    Write-Output "[ERROR] yt-dlp executable couldn't be found"
    Exit 1
}

Write-Output "[+] Cookie and yt-dlp files located successfully"
Write-Output "[*] Testing YouTube cookie status"

& $YTDLPPath --cookies "$CookiePath" --simulate --quiet $TestURL 2>$null

if ($LastExitCode -ne 0) {
    Write-Output "============================================="
    Write-Output "[ERROR] YouTube authentication failed!"
    Write-Output "The cookies.txt has expired or is invalid."
    Write-Output "============================================="
    Exit 1
}

Write-Output "[+] Cookies authenticated successfully."
$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] $Elapsed"
Write-Output "============================================="
Exit 0