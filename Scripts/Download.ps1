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

    # Inter-thread safe terminal string injection
    [Console]::WriteLine("[*] Processing Playlist $Index...")
    [Console]::WriteLine("URL: $PlaylistURL")

    # Arguments array tailored for real-time unbuffered stream printing
    $YTDLArgs = @(
        "--no-buf",                     # Force unbuffered stdout/stderr delivery across streams
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
        "--download-archive", $using:LocalActiveHistoryLog, 
        "--ignore-errors",
        $PlaylistURL
    )

    # Process start architecture to force thread-independent line capturing
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName               = $using:LocalYTDLPPath
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    
    foreach ($arg in $YTDLArgs) { $psi.ArgumentList.Add($arg) }

    $proc = [System.Diagnostics.Process]::Start($psi)
    
    # Stream-reader loop: Catches live fragments instantly before buffers can lock them down
    while (-not $proc.HasExited) {
        $line = $proc.StandardOutput.ReadLine()
        if ($null -ne $line) {
            $CleanText = $line -replace '\r', '' -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
            if (-not [string]::IsNullOrWhiteSpace($CleanText)) {
                # Writes directly to the underlying host process tracking your console monitor
                [Console]::WriteLine("[Playlist $Index] $CleanText")
            }
        }
    }
    
    # Empty trailing lines out of buffer cache post-completion
    $remaining = $proc.StandardOutput.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($remaining)) {
        $CleanText = $remaining -replace '\r', '' -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
        [Console]::WriteLine("[Playlist $Index] $CleanText")
    }

    # Dump streaming error stack to local disk logs seamlessly
    $errs = $proc.StandardError.ReadToEnd()
    if (-not [string]::IsNullOrWhiteSpace($errs)) {
        Set-Content -LiteralPath $ErrorLogPath -Value $errs -Force
    }

    if ($proc.ExitCode -eq 0) {
        [Console]::WriteLine("[+] Playlist Music $Index sync completed successfully!")
    } else {
        [Console]::WriteLine("[!] Playlist Music $Index finished with warnings/errors.")
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