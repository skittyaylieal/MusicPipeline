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

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Media Downloader" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

# Dynamic Architecture Rule for Clean Sweep
if ($CleanSweep) {
    Write-Host "[🔥 CLEAN SWEEP ACTIVE] Generating temporary execution archive log..." -ForegroundColor Orange
    $ActiveHistoryLog = "$env:TEMP\pipeline_null_history_$([Guid]::NewGuid().Guid).txt"
} else {
    $ActiveHistoryLog = $HistoryPath
}

Write-Host "[*] Updating yt-dlp to nightly" -ForegroundColor Yellow
& $YTDLPPath --update-to nightly

$OutputTemplate = "$BackupDir/%(artist|uploader)s/%(album|playlist)s/%(title)s.%(ext)s"

# Always sanitize quotes out of all incoming URLs regardless of array size
$SanitizedURLs = @()
foreach ($URL in $PlaylistURLs) {
    if ($URL -match ',') {
        $SanitizedURLs += $URL -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
    } else {
        $SanitizedURLs += $URL.Trim().Trim('"').Trim("'")
    }
}

$PlaylistIndex = 1
foreach ($PlaylistURL in $SanitizedURLs) {
    if ([string]::IsNullOrWhiteSpace($PlaylistURL)) { continue }
    
    $ErrorLogPath = "$ConfigDir\playlist${PlaylistIndex}_errors.txt"

    if (Test-Path -LiteralPath $ErrorLogPath) {
        Remove-Item -LiteralPath $ErrorLogPath -Force
    }

    Write-Host "`n[*] Processing Playlist $PlaylistIndex..." -ForegroundColor Cyan
    Write-Host "URL: $PlaylistURL" -ForegroundColor Yellow
    Write-Host "Logging errors to: $ErrorLogPath" -ForegroundColor DarkGray

    # HIGH FIDELITY FIX: Arguments packed into a Splatting Array to prevent backtick space parser failures
    $YTDLArgs = @(
        "--color", "always",
        "--sleep-interval", $SleepInterval,
        "--max-sleep-interval", $MaxSleepInterval,
        "--sleep-requests", $SleepRequests,
        "--embed-thumbnail",
        "--embed-metadata",
        "--no-keep-video",
        "--force-overwrites",
        "--cookies", $CookiePath,
        "-P", $BackupDir,
        "-o", $OutputTemplate,
        "--js-runtime", "deno",
        "--extractor-args", "youtube:player_client=ios,android",
        "-f", "ba[ext=m4a]/ba",
        "--download-archive", $ActiveHistoryLog,
        "--ignore-errors",
        $PlaylistURL
    )

    # Execute with error redirection
    & $YTDLPPath $YTDLArgs 2>>"$ErrorLogPath"

    if ($LastExitCode -eq 0) {
        Write-Host "[+] Playlist Music $PlaylistIndex sync completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "[!] Playlist Music $PlaylistIndex finished with warnings/errors." -ForegroundColor Yellow
    }
    $PlaylistIndex++
}

$MetricStopwatch.Stop()
$Elapsed = [string]::Format("{0:hh\:mm\:ss}", $MetricStopwatch.Elapsed)
Write-Host "[METRIC] $Elapsed"
Write-Host "`n=============================================" -ForegroundColor Cyan
Exit 0