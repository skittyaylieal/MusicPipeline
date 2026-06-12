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
    
    # FIX: Scoped directly to the runspace script instance so sub-actions can access it natively
    $script:ErrorLogPath = Join-Path $using:LocalConfigDir "playlist${LoopIndex}_run_errors.txt"
    if (Test-Path -LiteralPath $script:ErrorLogPath) { Remove-Item -LiteralPath $script:ErrorLogPath -Force -ErrorAction SilentlyContinue }

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

        # Configuration: Launch yt-dlp natively
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = $using:LocalYTDLPPath
        $psi.UseShellExecute        = $false  
        $psi.CreateNoWindow         = $true   
        $psi.WindowStyle            = [System.Diagnostics.ProcessWindowStyle]::Hidden

        # Inject environment variables directly into process memory context
        $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"
        $psi.EnvironmentVariables["YTDLP_UNBUFFERED"] = "1"
        $psi.EnvironmentVariables["NO_COLOR"]         = "1"

        # Pass arguments safely as an explicit array literal
        foreach ($arg in $YTDLArgs) { $psi.ArgumentList.Add($arg) }

        # Redirect standard output streams to handle them asynchronously
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        
        # FIX: Changed references to use $script: scope visibility inside event execution hooks
        $OutputAction = {
            if ($EventArgs.Data) {
                Invoke-LogMsg $EventArgs.Data
                if ($EventArgs.Data -match "Finished downloading playlist:") { $script:Capture = $true }
                if ($script:Capture) {
                    [System.IO.File]::AppendAllText($script:ErrorLogPath, ($EventArgs.Data + [System.Environment]::NewLine))
                }
            }
        }
        
        $ErrorAction = {
            if ($EventArgs.Data) {
                Invoke-LogMsg $EventArgs.Data
                [System.IO.File]::AppendAllText($script:ErrorLogPath, ($EventArgs.Data + [System.Environment]::NewLine))
            }
        }

        # Bind event handles natively inside the parallel pipeline context
        $OutEvent = Register-ObjectEvent -InputObject $proc -EventName 'OutputDataReceived' -Action $OutputAction
        $ErrEvent = Register-ObjectEvent -InputObject $proc -EventName 'ErrorDataReceived' -Action $ErrorAction

        # Initialize the actual process
        [void]$proc.Start()
        
        # Start asynchronous, non-blocking readings on both channels immediately
        $proc.BeginOutputReadLine()
        $proc.BeginErrorReadLine()

        # wait rule to let the events run naturally
        while (-not $proc.HasExited) {
            [System.Threading.Thread]::Sleep(200)
        }

        # Safe settling buffer window
        [System.Threading.Thread]::Sleep(500)

        # Cleanup monitoring event handlers cleanly
        Unregister-Event -SourceIdentifier $OutEvent.Name
        Unregister-Event -SourceIdentifier $ErrEvent.Name

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