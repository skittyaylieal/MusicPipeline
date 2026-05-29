param (
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

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Media Downloader" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Ensure backup dir exists
# FIX: Swapped to -LiteralPath
if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

Write-Host "[*] Updating yt-dlp to nightly" -ForegroundColor Yellow
& $YTDLPPath --update-to nightly

# Define output naming template
$OutputTemplate = "$BackupDir/%(artist|uploader)s/%(album|playlist)s/%(title)s.%(ext)s"

$PlaylistIndex = 1

# Clean up incoming array string if CMD mashed them into a single comma-separated block
if ($PlaylistURLs.Count -eq 1) {
    $PlaylistURLs = $PlaylistURLs -split ',' | ForEach-Object { $_.Trim('"') }
}

# Loop through playlist URLS
foreach ($PlaylistURL in $PlaylistURLs) {

    # Fix CMD array flattening: split by comma if they got joined as one string
    if ($PlaylistURL -match ',http') {
        # Re-inject the elements back into the execution loop safely
        $SubURLs = $PlaylistURL -split ','
        foreach ($SubURL in $SubURLs) {
            # FIX: Changed Get-Content to use -LiteralPath to prevent bracket errors when self-invoking
            Invoke-Expression -Command (Get-Content -LiteralPath $MyInvocation.MyCommand.Path -Raw) 
        }
        continue
    }

    # FIX: Replaced Join-Path with raw string interpolation
    $ErrorLogPath = "$ConfigDir\playlist${PlaylistIndex}_errors.txt"

    # Clean up the old error log if exists
    # FIX: Swapped to -LiteralPath
    if (Test-Path -LiteralPath $ErrorLogPath) {
        Remove-Item -LiteralPath $ErrorLogPath -Force
    }

    Write-Host "`n[*] Processing Playlist $PlaylistIndex..." -ForegroundColor Cyan
    Write-Host "URL: $PlaylistURL" -ForegroundColor Yellow
    Write-Host "Logging errors to: $ErrorLogPath" -ForegroundColor DarkGray

    # Execute yt-dlp with our given flags
    # NOTE: Enclosing variables inside double quotes inside the arguments handles literal brackets for CLI strings
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

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "    All playlist download tasks completed!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0