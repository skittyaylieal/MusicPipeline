Param (
    [string]$BackupDir,
    [string]$YTDLPPath,
    [string]$CookiePath,
    [string]$HistoryPath,
    [string[]]$PlaylistURLs,
    [string]$ConfigDir,
    [string]$CacheDir,
    [int]$SleepInterval,
    [int]$MaxSleepInterval,
    [int]$SleepRequests,
    [switch]$CleanSweep,
    [int]$Index
)

# Dynamic Architecture Rule for Clean Sweep
$ActiveHistoryLog = if ($CleanSweep) {
    Join-Path $env:TEMP "pipeline_null_history_$([Guid]::NewGuid().Guid).txt"
} else {
    $HistoryPath
}

# THREADING SAFETIES
$LocalYTDLPPath        = $YTDLPPath
$LocalBackupDir        = $BackupDir
$LocalCookiePath       = $CookiePath
$LocalConfigDir        = $ConfigDir
$LocalCacheDir         = $CacheDir
$LocalSleepInterval    = $SleepInterval
$LocalMaxSleepInterval = $MaxSleepInterval
$LocalSleepRequests    = $SleepRequests
$LocalActiveHistoryLog = $ActiveHistoryLog

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
    
    $ErrorLogPath = Join-Path $using:LocalConfigDir "playlist${LoopIndex}_run_errors.txt"
    if (Test-Path -LiteralPath $ErrorLogPath) { Remove-Item -LiteralPath $ErrorLogPath -Force -ErrorAction SilentlyContinue }

    # Thread-Safe Real-Time Logger with Dynamic Retry Back-off and ANSI Color Matrix
    function Invoke-LogMsg([string]$Text) {
        $Timestamp = (Get-Date).ToString("HH:mm:ss")
        
        $ESC = [char]27
        $Reset = "$ESC[0m"
        
        # Color profile routing by playlist slot index
        $ColorCode = switch ($LoopIndex) {
            1 { "36" }  # Cyan
            2 { "35" }  # Magenta
            3 { "33" }  # Yellow
            default { "32" } # Green fallback
        }
        
        # Override styling to bold red if an engine failure or thread panic is hit
        if ($Text -match '🛑|THREAD DEBUG ALERT|error:|ERROR:|Usage:') {
            $ColorCode = "1;31"
        }

        $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [Playlist $LoopIndex]$Reset"
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

        Invoke-LogMsg "Processing Playlist URL: $PlaylistURL"

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
            "--extractor-args", "youtube:player_client=default",
            "-f", "ba[ext=m4a]/ba",
            "--download-archive", $using:LocalActiveHistoryLog, 
            "--ignore-errors",
            "--legacy-server-connect",
            "--socket-timeout", "5",
            $PlaylistURL
        )

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = $using:LocalYTDLPPath
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true 
        $psi.RedirectStandardInput  = $true 
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
        
        # Unbuffered variables bound inside ProcessStartInfo configuration space
        $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"
        $psi.EnvironmentVariables["YTDLP_UNBUFFERED"] = "1"

        foreach ($arg in $YTDLArgs) { $psi.ArgumentList.Add($arg) }

        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Close()

        # --- COMPLETE POST-FLUSH MONITOR ENGINE ---
        $LastActivityTime = [System.Diagnostics.Stopwatch]::StartNew()
        $MaxStallSeconds  = 30  # Safety fallback for true network socket lockups
        
        $LastSeenLine     = ""
        $DuplicateCount   = 0
        $MaxDuplicates    = 3   # Crash buffer trigger limit
        
        # State toggle switch flag for error routing
        $CaptureEverything = $false

        while (-not $proc.HasExited) {
            $GotNewLines = $false

            # Pump Standard Output Channel
            while ($proc.StandardOutput.Peek() -ne -1) {
                $Line = $proc.StandardOutput.ReadLine()
                if ($Line) { 
                    $CleanedLine = $Line.Trim()
                    Invoke-LogMsg $Line 
                    $GotNewLines = $true

                    # Check for milestone boundary string
                    if ($CleanedLine -match "Finished downloading playlist:") {
                        $CaptureEverything = $true
                    }

                    # Route post-flush output straight to the log file
                    if ($CaptureEverything) {
                        [System.IO.File]::AppendAllText($ErrorLogPath, ($Line + [System.Environment]::NewLine))
                    }

                    # Monitor repetitive lines to stop console crash spams
                    if ($CleanedLine -eq $LastSeenLine -and -not [string]::IsNullOrWhiteSpace($CleanedLine)) {
                        $DuplicateCount++
                    } else {
                        $LastSeenLine   = $CleanedLine
                        $DuplicateCount = 0
                    }
                }
            }

            # Pump Standard Error Channel (Always write stderr to log)
            while ($proc.StandardError.Peek() -ne -1) {
                $ErrLine = $proc.StandardError.ReadLine()
                if ($ErrLine) {
                    Invoke-LogMsg $ErrLine
                    [System.IO.File]::AppendAllText($ErrorLogPath, ($ErrLine + [System.Environment]::NewLine))
                    $GotNewLines = $true
                }
            }

            # Evaluation Loop Crash Guard
            if ($DuplicateCount -ge $MaxDuplicates) {
                Invoke-LogMsg "🛑 [Pipeline Guard] Infinite log repetition loop detected. Forcing process crash cycle..."
                [System.IO.File]::AppendAllText($ErrorLogPath, ("WARN: Infinite console loop caught on track at " + (Get-Date).ToString() + [System.Environment]::NewLine))
                try {
                    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
                    Get-Process -Name "deno", "yt-dlp", "ffmpeg" -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-10) } | Stop-Process -Force -ErrorAction SilentlyContinue
                } catch {}
                break
            }

            # Evaluation Network Stall Guard
            if ($GotNewLines) {
                $LastActivityTime.Restart()
            } else {
                if ($LastActivityTime.Elapsed.TotalSeconds -gt $MaxStallSeconds) {
                    Invoke-LogMsg "🛑 [Pipeline Guard] Track stalled for $MaxStallSeconds seconds of pure silence. Force-cycling process..."
                    [System.IO.File]::AppendAllText($ErrorLogPath, ("WARN: Connection stalled out at " + (Get-Date).ToString() + [System.Environment]::NewLine))
                    try {
                        $proc | Stop-Process -Force -ErrorAction SilentlyContinue
                        Get-Process -Name "deno", "yt-dlp", "ffmpeg" -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-10) } | Stop-Process -Force -ErrorAction SilentlyContinue
                    } catch {}
                    break
                }
            }

            [System.Threading.Thread]::Sleep(150)
        }

        # Clear remaining trailing standard output buffer blocks safely
        while (($Line = $proc.StandardOutput.ReadLine()) -ne $null) { 
            if ($Line) { 
                Invoke-LogMsg $Line 
                if ($Line -match "Finished downloading playlist:") { $CaptureEverything = $true }
                if ($CaptureEverything) {
                    [System.IO.File]::AppendAllText($ErrorLogPath, ($Line + [System.Environment]::NewLine))
                }
            } 
        }
        
        # Clear remaining trailing standard error buffer blocks safely
        while (($ErrLine = $proc.StandardError.ReadLine()) -ne $null) { 
            if ($ErrLine) {
                Invoke-LogMsg $ErrLine
                [System.IO.File]::AppendAllText($ErrorLogPath, ($ErrLine + [System.Environment]::NewLine))
            }
        }
        # --- END OF MONITOR ENGINE ---

        if ($proc.ExitCode -eq 0) {
            Invoke-LogMsg "Sync completed successfully!"
        } else {
            Invoke-LogMsg "Finished with warnings/errors. Exit Code: $($proc.ExitCode)"
        }

    } catch {
        $InternalErrMsg = $_.Exception.Message
        $FailedLineNum  = $_.InvocationInfo.ScriptLineNumber
        Invoke-LogMsg "[🛑 THREAD DEBUG ALERT] Runspace collapsed on script line $FailedLineNum. Error: $InternalErrMsg"
    }
} -ThrottleLimit 1

if ($CleanSweep -and (Test-Path -LiteralPath $ActiveHistoryLog)) {
    Remove-Item -LiteralPath $ActiveHistoryLog -Force -ErrorAction SilentlyContinue
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] $Elapsed"
Write-Output "`n============================================="
Exit 0