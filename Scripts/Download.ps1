Param (
    [string]$BackupDir,
    [string]$YTDLPPath,
    [string]$CookiePath,
    [string]$HistoryPath,
    [string[]]$PlaylistURLs,
    [string]$ConfigDir,
    [int]$SleepInterval,
    [int]$MaxSleepInterval,
    [int]$SleepRequests
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Media Downloader" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

Write-Host "[*] Updating yt-dlp to nightly" -ForegroundColor Yellow
& $YTDLPPath --update-to nightly

$OutputTemplate = "$BackupDir/%(artist|uploader)s/%(album|playlist)s/%(title)s.%(ext)s"
$PlaylistIndex = 1

if ($PlaylistURLs.Count -eq 1) {
    $PlaylistURLs = $PlaylistURLs -split ',' | ForEach-Object { $_.Trim('"') }
}

foreach ($PlaylistURL in $PlaylistURLs) {
    $ErrorLogPath = "$ConfigDir\playlist${PlaylistIndex}_errors.txt"

    if (Test-Path -LiteralPath $ErrorLogPath) {
        Remove-Item -LiteralPath $ErrorLogPath -Force
    }

    Write-Host "`n[*] Processing Playlist $PlaylistIndex..." -ForegroundColor Cyan
    Write-Host "URL: $PlaylistURL" -ForegroundColor Yellow
    Write-Host "Logging errors to: $ErrorLogPath" -ForegroundColor DarkGray

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
        --extractor-args "youtube:player_client=web,web_safari" `
        -x `
        --audio-format m4a `
        --download-archive "$HistoryPath" `
        --ignore-errors `
        $PlaylistURL 2>>"$ErrorLogPath"

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