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

# Dynamic Architecture Rule for Clean Sweep (Defined early for script scope safety)
$ActiveHistoryLog = if ($CleanSweep) {
    # Generate a temporary, isolated text file path in the system TEMP directory
    Join-Path $env:TEMP "pipeline_null_history_$([Guid]::NewGuid().Guid).txt"
} else {
    $HistoryPath
}

# THREADING SAFETIES: Copy everything to explicit script-scope variables 
# so the ForEach-Object -Parallel threads can grab them reliably
$LocalYTDLPPath        = $YTDLPPath
$LocalBackupDir        = $BackupDir
$LocalCookiePath       = $CookiePath
$LocalConfigDir        = $ConfigDir
$LocalSleepInterval    = $SleepInterval
$LocalMaxSleepInterval = $MaxSleepInterval
$LocalSleepRequests    = $SleepRequests
$LocalActiveHistoryLog = $ActiveHistoryLog # Safe thread assignment

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Clear-Host

Write-Output "============================================="
Write-Output "    PowerShell Module: Media Downloader"
Write-Output "============================================="

if ($CleanSweep) {
    Write-Output "[🔥 CLEAN SWEEP ACTIVE] Generating temporary execution archive log..."
}

if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

Write-Output "[*] Updating yt-dlp to nightly"
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

    Write-Output "`n[*] Processing Playlist $Index..."
    Write-Output "URL: $PlaylistURL"

    $YTDLArgs = @(
        "--no-colors",
        "--no-progress",
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
        "--download-archive", $using:LocalActiveHistoryLog, # <-- FIXED: Points to thread-safe mapped variable
        "--ignore-errors",
        $PlaylistURL
    )

    # Execute with verified threading context
    & $using:LocalYTDLPPath $YTDLArgs 2>>"$ErrorLogPath" | ForEach-Object {
        if ($null -ne $_) {
            $CleanText = $_.ToString() -replace '\r', '' -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
            if (-not [string]::IsNullOrWhiteSpace($CleanText)) {
                Write-Output $CleanText
            }
        }
    }

    if ($LastExitCode -eq 0) {
        Write-Output "[+] Playlist Music $Index sync completed successfully!"
    } else {
        Write-Output "[!] Playlist Music $Index finished with warnings/errors."
    }
} -ThrottleLimit 3

# Post-run cleanup: Clear out temporary history file if a Clean Sweep was active
if ($CleanSweep -and (Test-Path -LiteralPath $ActiveHistoryLog)) {
    Remove-Item -LiteralPath $ActiveHistoryLog -Force -ErrorAction SilentlyContinue
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] $Elapsed"
Write-Output "`n============================================="
Exit 0