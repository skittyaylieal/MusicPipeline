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
    [switch]$CleanSweep,
    [int]$Index
)

# Dynamic Architecture Rule for Clean Sweep
$ActiveHistoryLog = if ($CleanSweep) {
    Join-Path $env:TEMP "pipeline_null_history_$([Guid]::NewGuid().Guid).txt"
} else {
    $HistoryPath
}

# THREADING SAFETIES: Local copies for thread extraction
$LocalYTDLPPath        = $YTDLPPath
$LocalBackupDir        = $BackupDir
$LocalCookiePath       = $CookiePath
$LocalConfigDir        = $ConfigDir
$LocalSleepInterval    = $SleepInterval
$LocalMaxSleepInterval = $MaxSleepInterval
$LocalSleepRequests    = $SleepRequests
$LocalActiveHistoryLog = $ActiveHistoryLog

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

# FIX: Native syntax correction. Group the loop statement inside parenthesis so it compiles perfectly to the pipeline stream
$SanitizedURLs = $(foreach ($URL in $PlaylistURLs) {
    if ($URL -match ',') {
        $URL -split ',' | ForEach-Object { $_.Trim().Trim('"').Trim("'") }
    } else {
        $URL.Trim().Trim('"').Trim("'")
    }
}) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }

# Strongly cast array directly into a Generic List to prevent thread constructor collapse
[System.Collections.Generic.List[string]]$GlobalURLsCopy = $SanitizedURLs

# WEB ENGINE WORKAROUND: Define a global log pointer if running inside a web job context
$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Optimization: Parallel Playlist Auditing
$SanitizedURLs | ForEach-Object -Parallel {
    $PlaylistURL = $_
    
    # Safety: Fetch loop index safely out of the shared memory frame
    $LocalList = $using:GlobalURLsCopy
    $LoopIndex = $LocalList.IndexOf($PlaylistURL) + 1
    
    $ErrorLogPath = Join-Path $env:TEMP "playlist${LoopIndex}_run_errors.txt"

    if (Test-Path -LiteralPath $ErrorLogPath) {
        Remove-Item -LiteralPath $ErrorLogPath -Force -ErrorAction SilentlyContinue
    }

    # Native local logging handler
    function Invoke-LogMsg([string]$Text) {
        $Timestamp = (Get-Date).ToString("HH:mm:ss")
        $FormattedLine = "[$Timestamp] [Playlist $LoopIndex] $Text"
        
        Write-Output $FormattedLine
        
        if (Test-Path -LiteralPath $using:GlobalLogFile) {
            try {
                [System.IO.File]::AppendAllText($using:GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine))
            } catch {}
        }
    }

    # ADVANCED DEBUG SYSTEM: Wrap the thread execution block in a diagnostic container
    try {
        if ([string]::IsNullOrWhiteSpace($PlaylistURL)) { 
            Invoke-LogMsg "Skipping blank or invalid configuration element row slot."
            return 
        }

        Invoke-LogMsg "Processing Playlist URL: $PlaylistURL"

        $YTDLArgs = @(
            "--no-buf",                      
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

        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true 
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        
        if ($IsWindows) {
            $psi.FileName = $using:LocalYTDLPPath
            foreach ($arg in $YTDLArgs) {
                $psi.ArgumentList.Add($arg)
            }
        } else {
            $psi.FileName = "sh"
            $EscapedArgs = @()
            foreach ($arg in $YTDLArgs) { $EscapedArgs += "'$arg'" }
            $CombinedArgs = $EscapedArgs -join ' '
            $psi.Arguments = "-c ""'$using:LocalYTDLPPath' $CombinedArgs 2>&1"""
        }

        $proc = [System.Diagnostics.Process]::Start($psi)
        
        # ASYNC CHAR BUFFER ENGINE: Intercept both streams character-by-character
        $StdoutReader = $proc.StandardOutput
        $StderrReader = $proc.StandardError
        $CharBuffer   = [char[]]::new(4096)
        $CurrentLine  = [System.Text.StringBuilder]::new()

        $ProcessStreamChunk = {
            param([System.IO.StreamReader]$Stream)
            if ($Stream.Peek() -ge 0) {
                $CharsRead = $Stream.Read($CharBuffer, 0, $CharBuffer.Length)
                for ($i = 0; $i -lt $CharsRead; $i++) {
                    $c = $CharBuffer[$i]

                    if ($c -eq "`n" -or $c -eq "`r") {
                        if ($CurrentLine.Length -gt 0) {
                            $LineText = $CurrentLine.ToString()
                            $CleanText = $LineText -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
                            
                            if (-not [string]::IsNullOrWhiteSpace($CleanText)) {
                                Invoke-LogMsg $CleanText
                                
                                if ($CleanText -match 'ERROR:|WARNING:|Executable|not found|Failed') {
                                    [System.IO.File]::AppendAllText($ErrorLogPath, ($CleanText + [System.Environment]::NewLine))
                                }
                            }
                            $CurrentLine.Clear()
                        }
                    } else {
                        $CurrentLine.Append($c) | Out-Null
                    }
                }
            }
        }

        while (-not $proc.HasExited) {
            & $ProcessStreamChunk $StdoutReader
            & $ProcessStreamChunk $StderrReader
            [System.Threading.Thread]::Sleep(50)
        }

        # Flush trailing data remaining inside buffers post-execution
        & $ProcessStreamChunk $StdoutReader
        & $ProcessStreamChunk $StderrReader

        if ($CurrentLine.Length -gt 0) {
            $CleanText = $CurrentLine.ToString() -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
            if (-not [string]::IsNullOrWhiteSpace($CleanText)) { 
                Invoke-LogMsg $CleanText 
                if ($CleanText -match 'ERROR:|WARNING:|Executable|not found|Failed') {
                    [System.IO.File]::AppendAllText($ErrorLogPath, ($CleanText + [System.Environment]::NewLine))
                }
            }
        }

        if ($proc.ExitCode -eq 0) {
            Invoke-LogMsg "Sync completed successfully!"
        } else {
            Invoke-LogMsg "Finished with warnings/errors."
        }

    } catch {
        # Catch and broadcast internal script runtime errors instantly to the stream log
        $InternalErrMsg = $_.Exception.Message
        $FailedLineNum  = $_.InvocationInfo.ScriptLineNumber
        Invoke-LogMsg "[🛑 THREAD DEBUG ALERT] Runspace collapsed on script line $FailedLineNum. Error: $InternalErrMsg"
        Invoke-LogMsg "Finished with warnings/errors."
    }
} -ThrottleLimit 3

if ($CleanSweep -and (Test-Path -LiteralPath $ActiveHistoryLog)) {
    Remove-Item -LiteralPath $ActiveHistoryLog -Force -ErrorAction SilentlyContinue
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] $Elapsed"
Write-Output "`n============================================="
Exit 0