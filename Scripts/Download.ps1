Param (
    [string]$BackupDir,
    [string]$YTDLPPath,
    [string]$CookiePath,
    [string]$HistoryPath,
    [string[]]$PlaylistURLs,
    [string]$ConfigDir,
    [int]$SleepInterval,
    [int]$MaxSleepInterval,
    [int]$SleepRequests,
    [switch]$CleanSweep
)

# THREADING SAFETIES: Copy everything to explicit script-scope variables 
# so the ForEach-Object -Parallel threads can grab them reliably
$LocalYTDLPPath      = $YTDLPPath
$LocalBackupDir      = $BackupDir
$LocalCookiePath     = $CookiePath
$LocalConfigDir      = $ConfigDir
$LocalSleepInterval  = $SleepInterval
$LocalMaxSleepInterval = $MaxSleepInterval
$LocalSleepRequests  = $SleepRequests

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Clear-Host

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Media Downloader" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# Dynamic Architecture Rule for Clean Sweep
$ActiveHistoryLog = if ($CleanSweep) {
    Write-Host "[🔥 CLEAN SWEEP ACTIVE] Generating temporary execution archive log..." -ForegroundColor Orange
    Join-Path $env:TEMP "pipeline_null_history_$([Guid]::NewGuid().Guid).txt"
} else {
    $HistoryPath
}

Write-Host "[*] Updating yt-dlp to nightly" -ForegroundColor Yellow
& $YTDLPPath --update-to nightly

$OutputTemplate = "$BackupDir/%(artist|uploader)s/%(album|playlist)s/%(title)s.%(ext)s"

# Always sanitize quotes out of all incoming URLs regardless of array size
$SanitizedURLs = foreach ($URL in $PlaylistURLs) {
    if ($URL -match ',') {
        $URL -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
    } else {
        $URL.Trim().Trim('"').Trim("'")
    }
}

# Store a strict array copy for tracking the loop positions inside threads
$GlobalURLsCopy = $SanitizedURLs

# Optimization: Parallel Playlist Auditing Capability via PS7 thread pooling
$SanitizedURLs | ForEach-Object -Parallel {
    $PlaylistURL = $_
    if ([string]::IsNullOrWhiteSpace($PlaylistURL)) { return }
    
    # Calculate index safely by referencing our clean array copy
    $Index = [array]::IndexOf($using:GlobalURLsCopy, $PlaylistURL) + 1
    $ErrorLogPath = Join-Path $using:LocalConfigDir "playlist${Index}_errors.txt"

    if (Test-Path -LiteralPath $ErrorLogPath) {
        Remove-Item -LiteralPath $ErrorLogPath -Force
    }

    Write-Host "`n[*] Processing Playlist $Index..." -ForegroundColor Cyan
    Write-Host "URL: $PlaylistURL" -ForegroundColor Yellow

    $YTDLArgs = @(
        "--color", "always",
        "--sleep-interval", $using:LocalSleepInterval,
        "--max-sleep-interval", $using:LocalMaxSleepInterval,
        "--sleep-requests", $using:LocalSleepRequests,
        "--embed-thumbnail",
        "--embed-metadata",
        "--no-keep-video",
        "--force-overwrites",
        "--cookies", $using:LocalCookiePath,
        "-P", $using:LocalBackupDir,
        "-o", $using:OutputTemplate,
        "--js-runtime", "deno",
        "--extractor-args", "youtube:player_client=ios,android",
        "-f", "ba[ext=m4a]/ba",
        "--download-archive", $using:ActiveHistoryLog,
        "--ignore-errors",
        $PlaylistURL
    )

    # Execute with verified threading context and error streams
    & $using:LocalYTDLPPath $YTDLArgs 2>>"$ErrorLogPath"

    if ($LastExitCode -eq 0) {
        Write-Host "[+] Playlist Music $Index sync completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "[!] Playlist Music $Index finished with warnings/errors." -ForegroundColor Yellow
    }
} -ThrottleLimit 3

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Host "[METRIC] $Elapsed"
Write-Host "`n=============================================" -ForegroundColor Cyan
Exit 0