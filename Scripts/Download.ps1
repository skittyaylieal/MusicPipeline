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
    [int]$MaxDownloadThreads = 1,
    [switch]$CleanSweep,
    [int]$Index
)

# THREADING SAFETIES (Root Context Map)
$LocalYTDLPPath        = $YTDLPPath
$LocalBackupDir        = $BackupDir
$LocalCookiePath       = $CookiePath
$LocalConfigDir        = $ConfigDir
$LocalSleepInterval    = $SleepInterval
$LocalMaxSleepInterval = $MaxSleepInterval
$LocalSleepRequests    = $SleepRequests

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Clear-Host

Write-Output "============================================="
Write-Output "    PowerShell Module: Media Downloader"
Write-Output "============================================="

if (-not (Test-Path -LiteralPath $BackupDir)) {
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
}

$OutputTemplate = "$BackupDir/%(artist|uploader)s/%(album|playlist)s/%(title)s.%(ext)s"

# Safe parenthetical array compilation
$SanitizedURLs = $(foreach ($URL in $PlaylistURLs) {
    if ($URL -match ',') {
        $URL -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
    } else {
        $URL.Trim().Trim('"').Trim("'")
    }
}) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

[System.Collections.Generic.List[string]]$GlobalURLsCopy = $SanitizedURLs
$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Optimization: Parallel Playlist Auditing (Sequenced cleanly via ThrottleLimit 1)
$SanitizedURLs | ForEach-Object -Parallel {
    $PlaylistURL = $_
    
    $LocalList = $using:GlobalURLsCopy
    $LoopIndex = $LocalList.IndexOf($PlaylistURL) + 1
    
    # Move History File allocation inside the runspace to prevent thread collisions
    $LocalActiveHistoryLog = if ($using:CleanSweep) {
        Join-Path $env:TEMP "pipeline_null_history_$([Guid]::NewGuid().Guid)_$LoopIndex.txt"
    } else {
        $using:HistoryPath
    }

    $ErrorLogPath = Join-Path $using:LocalConfigDir "playlist${LoopIndex}_run_errors.txt"
    if (Test-Path -LiteralPath $ErrorLogPath) { Remove-Item -LiteralPath $ErrorLogPath -Force -ErrorAction SilentlyContinue }

    # Core Thread-Safe Logger Matrix - FIXED: Explicitly scoped $LoopIndex access
    function Invoke-LogMsg([string]$Text, [int]$Idx) {
        if ([string]::IsNullOrWhiteSpace($Text)) { return }
        $Timestamp = (Get-Date).ToString("HH:mm:ss")
        
        $ESC = [char]27
        $Reset = "$ESC[0m"
        
        $ColorCode = switch ($Idx) {
            1 { "36" }  # Cyan
            2 { "35" }  # Magenta
            3 { "33" }  # Yellow
            default { "32" } # Green fallback
        }
        
        if ($Text -match '🛑|THREAD DEBUG ALERT|error:|ERROR:|Usage:') {
            $ColorCode = "1;31"
        }

        $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [Playlist $Idx]$Reset"
        $FormattedLine = "$ColorPrefix $Text"
        
        Write-Output $FormattedLine
        
        if (Test-Path -LiteralPath $using:GlobalLogFile) {
            $RetryCount = 0
            $MaxRetries = 15
            $Success    = $false
            while (-not $Success -and $RetryCount -lt $MaxRetries) {
                try {
                    [System.IO.File]::AppendAllText($using:GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine))
                    $Success = $true
                } catch [System.IO.IOException] {
                    $RetryCount++
                    [System.Threading.Thread]::Sleep(50)
                } catch {
                    break
                }
            }
        }
    }

    try {
        if ([string]::IsNullOrWhiteSpace($PlaylistURL)) { return }

        Invoke-LogMsg "Processing Playlist URL: $PlaylistURL" $LoopIndex

        $YTDLArgs = @(
            "--no-colors",
            "--verbose",
            "--newline",
            "--sleep-interval", $using:LocalSleepInterval,
            "--max-sleep-interval", $using:LocalMaxSleepInterval,
            "--sleep-requests", $using:LocalSleepRequests,
            "--embed-thumbnail",
            "--convert-thumbnails", "jpg",
            "--ppa", "EmbedThumbnail+ffmpeg_o:-vf crop=ih:ih",
            "--embed-metadata",
            "--no-keep-video",
            "--force-overwrites",
            "--cookies", $using:LocalCookiePath,
            "-P", $using:LocalBackupDir,
            "-o", $using:OutputTemplate,
            "--cache-dir", $using:LocalCacheDir,
            "--geo-bypass",
            "--js-runtime", "deno",
            "--extractor-args", "youtube:player_js_variant=tv",
            
            # --- MAXIMUM QUALITY REMUX ARCHITECTURE ---
            "-f", "bestaudio/best",              # Capture the absolute highest bitrate track (bypasses 128kbps container restriction)
            "--extract-audio",                   # Extract audio stream explicitly 
            "--audio-format", "m4a",             # Instruct ffmpeg to copy/remux the best audio track into clean M4A
            "--audio-quality", "0",              # Force highest variable/constant audio processing rules
            # ------------------------------------------

            "--download-archive", $LocalActiveHistoryLog, 
            "--ignore-errors",
            "--no-abort-on-error",
            "--legacy-server-connect",
            "--socket-timeout", "30",
            $PlaylistURL
        )

        # FIX: Explicitly escape double quotes around individual arguments to protect spaces/backslashes from splitting
        $EscapedArgs = @()
        foreach ($Arg in $YTDLArgs) {
            if ($Arg -match '[\s\\]' -and -not ($Arg -match '^".*"$')) {
                $EscapedArgs += "`"$Arg`""
            } else {
                $EscapedArgs += $Arg
            }
        }
        $YTDLArgsString = $EscapedArgs -join " "
        
        # Build a safely nested executable execution string for CMD processing (Merging 2>&1 into output stream)
        $CommandLine = "`"`"$using:LocalYTDLPPath`" $YTDLArgsString 2>&1`""
        
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = "cmd.exe"
        $psi.Arguments              = "/c $CommandLine"
        $psi.UseShellExecute        = $false  
        $psi.CreateNoWindow         = $true   
        $psi.WindowStyle            = [System.Diagnostics.ProcessWindowStyle]::Hidden
        $psi.RedirectStandardOutput = $true   # Stream output straight into system memory buffers

        # Remove log buffer
        $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"

        # Launch the executable engine
        $proc = [System.Diagnostics.Process]::Start($psi)


        # LIVE REDIRECTION ENGINE: Streams text lines directly to logger and session log in real-time
        while (-not $proc.StandardOutput.EndOfStream) {
            $CurrentLine = $proc.StandardOutput.ReadLine()
            
            if ($null -ne $CurrentLine) {
                # 1. Flash it to your master console/global log stream
                Invoke-LogMsg $CurrentLine $LoopIndex

                # 2. Instantly append it to the dedicated playlist log for deep diagnostics
                [System.IO.File]::AppendAllText($ErrorLogPath, ($CurrentLine + [System.Environment]::NewLine))
            }
        }

        # Native handle wait synchronization
        $proc.WaitForExit()

        if ($proc.ExitCode -eq 0) {
            Invoke-LogMsg "Sync completed successfully!" $LoopIndex
        } else {
            Invoke-LogMsg "Finished with warnings/errors. Exit Code: $($proc.ExitCode)" $LoopIndex
        }

    } catch {
        $InternalErrMsg = $_.Exception.Message
        $FailedLineNum  = $_.InvocationInfo.ScriptLineNumber
        Invoke-LogMsg "[🛑 THREAD DEBUG ALERT] Runspace collapsed on script line $FailedLineNum. Error: $InternalErrMsg" $LoopIndex
    } finally {
        # Secure Clean Sweep File Removal directly inside the individual runspace loop
        if ($using:CleanSweep -and (Test-Path -LiteralPath $LocalActiveHistoryLog)) {
            Remove-Item -LiteralPath $LocalActiveHistoryLog -Force -ErrorAction SilentlyContinue
        }
    }
} -ThrottleLimit $MaxDownloadThreads

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] Total Run Duration: $Elapsed"
Write-Output "`n============================================="
Exit 0