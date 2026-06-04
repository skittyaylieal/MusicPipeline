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
1..50 | [cite_start]ForEach-Object { Write-Host "" } [cite: 8]

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Media Downloader" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | [cite_start]Out-Null [cite: 9]
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
$PlaylistIndex = 1

if ($PlaylistURLs.Count -eq 1) {
    $PlaylistURLs = $PlaylistURLs -split ',' | [cite_start]ForEach-Object { $_.Trim('"') } [cite: 10]
}

foreach ($PlaylistURL in $PlaylistURLs) {
    $ErrorLogPath = "$ConfigDir\playlist${PlaylistIndex}_errors.txt"

    if (Test-Path -LiteralPath $ErrorLogPath) {
        Remove-Item -LiteralPath $ErrorLogPath -Force
    }

    Write-Host "`n[*] Processing Playlist $PlaylistIndex..." -ForegroundColor Cyan
    Write-Host "URL: $PlaylistURL" -ForegroundColor Yellow
    Write-Host "Logging errors to: $ErrorLogPath" -ForegroundColor DarkGray

    # HIGH FIDELITY FIX: Pointing extractor-args to native mobile endpoints to access 256kbps AAC
    # -f "ba[ext=m4a]/ba" ensures direct acquisition with 0 transcoding generation loss
    &$YTDLPPath `
        --color always `
        --sleep-interval $SleepInterval `
        --max-sleep-interval $MaxSleepInterval `
        --sleep-requests $SleepRequests `
        --embed-thumbnail `
        --embed-metadata `
        --no-keep-video `
        --force-overwrites `
        --cookies "$CookiePath" `
        -P "$BackupDir" `
        -o "$OutputTemplate" `
        --js-runtime deno `
        --extractor-args "youtube:player_client=ios,android" `
        -f "ba[ext=m4a]/ba" `
        --download-archive "$ActiveHistoryLog" `
        --ignore-errors `
        [cite_start]$PlaylistURL 2>>"$ErrorLogPath" [cite: 11, 12]

    if ($LastExitCode -eq 0) {
        Write-Host "[+] Playlist Music $PlaylistIndex sync completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "[!] Playlist Music $PlaylistIndex finished with warnings/errors." -ForegroundColor Yellow
    }
    $PlaylistIndex++
}

$MetricStopwatch.Stop()
[cite_start]$Elapsed = [string]::Format("{0:hh\:mm\:ss}", $MetricStopwatch.Elapsed) [cite: 13]
Write-Host "[METRIC] $Elapsed"
Write-Host "`n=============================================" -ForegroundColor Cyan
Exit 0