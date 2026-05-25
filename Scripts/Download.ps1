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
if (-not (Test-Path -Path $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force |Out-Null
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
            # Run the existing loop logic for each cleanly separated URL
            Invoke-Expression -Command (Get-Content -Path $MyInvocation.MyCommand.Path -Raw) 
        }
        continue
    }


    # Generate new error log
    $ErrorLogPath = Join-Path -Path $ConfigDir -ChildPath "playlist${PlaylistIndex}_errors.txt"

    # Clean up the old error log if exists
    if (Test-Path -Path $ErrorLogPath) {
        Remove-Item -Path $ErrorLogPath -Force
    }

    Write-Host "`n[*] Processing Playlist $PlaylistIndex..." -ForegroundColor Cyan
    Write-Host "URL: $PlaylistURL" -ForegroundColor Yellow
    Write-Host "Logging errors to: $ErrorLogPath" -ForegroundColor DarkGray

    # Execute yt-dlp with our given flags

    &$YTDLPPath `
        --color always `
        --sleep-interval $SleepInterval `
        --max-sleep-interval $MaxSleepInterval `
        --sleep-requests $SleepRequests `
        --embed-thumbnail `
        --embed-metadata `
        --no-keep-video `
        --force-overwrites `
        --cookies $CookiePath `
        -P $BackupDir `
        -o $OutputTemplate `
        --js-runtime deno `
        --extractor-args "youtube:player_client=web,safari" `
        -x `
        --audio-format m4a `
        --download-archive $HistoryPath `
        --ignore-errors `
        $PlaylistURL 2>$ErrorLogPath

        # Flag info
        # Gives output appropriate colouring
        # A random sleep interval to prevent bot detection 
        # Maximum sleep interval
        # Sleep between any API requests
        # Embed youtube thumbnail as album art
        # Embed artist album and comment metadata 
        # Ignore the video stream of the video; only include audio
        # If a file already exists and isn't in the download archive remake it entirely; for tag fixing purposes and broken files
        # Where to find the given cookies
        # Output directory
        # Template to use for the folder structure of the output
        # Which JavaScript runtime to use for solving youtube captcha challenges
        # Device to impersonate
        # Only extract audio to begin with
        # Output audio file format
        # Download History file to avoid repeat downloading songs unnecessaril
        # Don't halt execution for errors
        # Send all errors to the appropriate error log file



    if ($LastExitCode -eq 0) {
        Write-Host "[+] Playlist Music $PlaylistIndex sync completed successfully!" -ForegroundColor Green
    } else {
        Write-Host "[!] Playlist Music $PlaylistIndex finished with warnings/errors." -ForegroundColor Yellow
    }

    $PlaylistIndex++

}


Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "   All playlist download tasks completed!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0
