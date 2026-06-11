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

    # Core Thread-Safe Logger Matrix
    function Invoke-LogMsg([string]$Text) {
        if ([string]::IsNullOrWhiteSpace($Text)) { return }
        $Timestamp = (Get-Date).ToString("HH:mm:ss")
        
        $ESC = [char]27
        $Reset = "$ESC[0m"
        
        $ColorCode = switch ($LoopIndex) {
            1 { "36" }  # Cyan
            2 { "35" }  # Magenta
            3 { "33" }  # Yellow
            default { "32" } # Green fallback
        }
        
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
            "--extractor-args", "youtube:player_js_variant=tv",
            "-f", "ba[ext=m4a]/ba",
            "--download-archive", $using:LocalActiveHistoryLog, 
            "--ignore-errors",
            "--no-abort-on-error",
            "--legacy-server-connect",
            "--socket-timeout", "30",
            $PlaylistURL
        )

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = $using:LocalYTDLPPath
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        
        # Unbuffered environment parameters forced to standard settings
        $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"
        $psi.EnvironmentVariables["YTDLP_UNBUFFERED"] = "1"

        foreach ($arg in $YTDLArgs) { $psi.ArgumentList.Add($arg) }

        # Setup explicit temporary files to intercept text blocks natively
        $OutFile = Join-Path $using:LocalConfigDir "playlist${LoopIndex}_stdout.tmp"
        $ErrFile = Join-Path $using:LocalConfigDir "playlist${LoopIndex}_stderr.tmp"
        if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $ErrFile) { Remove-Item -LiteralPath $ErrFile -Force -ErrorAction SilentlyContinue }

        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

        $proc = [System.Diagnostics.Process]::Start($psi)

        # Build real-time streaming text writers
        $OutStream = [System.IO.StreamWriter]::new($OutFile, $false, [System.Text.Encoding]::UTF8)
        $ErrStream = [System.IO.StreamWriter]::new($ErrFile, $false, [System.Text.Encoding]::UTF8)

        # Event bindings for processing unbuffered streams out of memory pipes instantly
        # (Using local references inside the blocks to comply with strict PowerShell scope syntax)
        $OutDataReceived = Register-ObjectEvent -InputObject $proc -EventName "OutputDataReceived" -Action {
            if ($EventArgs.Data) { 
                $Stream = $using:OutStream
                $Stream.WriteLine($EventArgs.Data)
                $Stream.Flush() 
            }
        }
        $ErrDataReceived = Register-ObjectEvent -InputObject $proc -EventName "ErrorDataReceived" -Action {
            if ($EventArgs.Data) { 
                $Stream = $using:ErrStream
                $Stream.WriteLine($EventArgs.Data)
                $Stream.Flush() 
            }
        }

        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        # Non-blocking, dynamic evaluation engine
        $LastLineCount = 0
        $TimeoutWatch = [System.Diagnostics.Stopwatch]::StartNew()

        while (-not $proc.HasExited) {
            [System.Threading.Thread]::Sleep(1000)
            
            # Stagnation ceiling check (Triggers only if output stops completely for 10 minutes)
            if ($TimeoutWatch.Elapsed.TotalMinutes -gt 10) {
                Invoke-LogMsg "🛑 [Pipeline Guard] Process stagnated or exceeded safety limits. Terminating instance..."
                try {
                    $proc | Stop-Process -Force -ErrorAction SilentlyContinue
                    Get-Process -Name "deno", "yt-dlp", "ffmpeg" -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -gt (Get-Date).AddMinutes(-10) } | Stop-Process -Force -ErrorAction SilentlyContinue
                } catch {}
                break
            }

            # Safely tail the text dump and flush lines back out to the web monitor
            if (Test-Path -LiteralPath $OutFile) {
                try {
                    $Lines = Get-Content -LiteralPath $OutFile -ErrorAction SilentlyContinue
                    if ($Lines -and $Lines.Count -gt $LastLineCount) {
                        for ($i = $LastLineCount; $i -lt $Lines.Count; $i++) {
                            $Line = $Lines[$i]
                            Invoke-LogMsg $Line
                            if ($Line -match "Finished downloading playlist:") { $script:Capture = $true }
                            if ($script:Capture) {
                                [System.IO.File]::AppendAllText($ErrorLogPath, ($Line + [System.Environment]::NewLine))
                            }
                        }
                        $LastLineCount = $Lines.Count
                        $TimeoutWatch.Restart() # Active progression detected, reset stagnation watch!
                    }
                } catch {}
            }
        }

        # Allow final streaming allocations to complete settling
        [System.Threading.Thread]::Sleep(500)

        # Clear event registrations and drop locks cleanly
        Unregister-Event -SourceIdentifier $OutDataReceived.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $ErrDataReceived.Name -ErrorAction SilentlyContinue
        $OutStream.Close(); $OutStream.Dispose()
        $ErrStream.Close(); $ErrStream.Dispose()

        # Compile trailing error data segments
        if (Test-Path -LiteralPath $ErrFile) {
            $Errors = Get-Content -LiteralPath $ErrFile -ErrorAction SilentlyContinue
            if ($Errors) {
                [System.IO.File]::AppendAllText($ErrorLogPath, ($Errors -join [System.Environment]::NewLine))
                foreach ($ErrLine in $Errors) { Invoke-LogMsg $ErrLine }
            }
        }

        # Wipe working stream files
        Remove-Item $OutFile, $ErrFile -Force -ErrorAction SilentlyContinue

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