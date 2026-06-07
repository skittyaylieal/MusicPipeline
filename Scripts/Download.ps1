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

# THREADING SAFETIES
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

# Optimization: Parallel Playlist Auditing
$SanitizedURLs | ForEach-Object -Parallel {
    $PlaylistURL = $_
    
    $LocalList = $using:GlobalURLsCopy
    $LoopIndex = $LocalList.IndexOf($PlaylistURL) + 1
    
    $ErrorLogPath = Join-Path $env:TEMP "playlist${LoopIndex}_run_errors.txt"
    if (Test-Path -LiteralPath $ErrorLogPath) { Remove-Item -LiteralPath $ErrorLogPath -Force -ErrorAction SilentlyContinue }

    # Thread-Safe Real-Time Logger
    function Invoke-LogMsg([string]$Text) {
        $Timestamp = (Get-Date).ToString("HH:mm:ss")
        $FormattedLine = "[$Timestamp] [Playlist $LoopIndex] $Text"
        
        Write-Output $FormattedLine
        
        if (Test-Path -LiteralPath $using:GlobalLogFile) {
            # Use Out-File with safe sharing policies to prevent multi-thread cross-locking deadlocks
            $FormattedLine | Out-File -FilePath $using:GlobalLogFile -Append -Encoding utf8 -ErrorAction SilentlyContinue
        }
    }

    try {
        if ([string]::IsNullOrWhiteSpace($PlaylistURL)) { return }

        Invoke-LogMsg "Processing Playlist URL: $PlaylistURL"

        # Explicitly added --no-interactive to force immediate failures on headless blocks
        $YTDLArgs = @(
            "--no-buf",                      
            "--no-colors",
            "--no-progress",
            "--no-interactive",
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
        $psi.FileName               = $using:LocalYTDLPPath
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true 
        $psi.RedirectStandardInput  = $true # Force input redirection to prevent headless freezing
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
        $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"

        foreach ($arg in $YTDLArgs) { $psi.ArgumentList.Add($arg) }

        $proc = [System.Diagnostics.Process]::Start($psi)
        
        # Kill standard input instantly so the process knows no human is typing responses
        $proc.StandardInput.Close()

        # NATIVE REAL-TIME LINE READER: Pushes to the log file the exact millisecond a line forms
        while (-not $proc.HasExited) {
            if ($proc.StandardOutput.Peek() -ge 0) {
                $Line = $proc.StandardOutput.ReadLine()
                if ($Line) {
                    $CleanLine = $Line -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
                    Invoke-LogMsg $CleanLine
                }
            }
            if ($proc.StandardError.Peek() -ge 0) {
                $ErrLine = $proc.StandardError.ReadLine()
                if ($ErrLine) {
                    $CleanErr = $ErrLine -replace '\x1b\[[0-9;]*[a-zA-Z]', ''
                    Invoke-LogMsg $CleanErr
                    [System.IO.File]::AppendAllText($ErrorLogPath, ($CleanErr + [System.Environment]::NewLine))
                }
            }
            [System.Threading.Thread]::Sleep(30)
        }

        # Flush any trailing lines remaining post-execution
        while ($proc.StandardOutput.Peek() -ge 0) {
            $Line = $proc.StandardOutput.ReadLine()
            if ($Line) { Invoke-LogMsg ($Line -replace '\x1b\[[0-9;]*[a-zA-Z]', '') }
        }
        while ($proc.StandardError.Peek() -ge 0) {
            $ErrLine = $proc.StandardError.ReadLine()
            if ($ErrLine) { Invoke-LogMsg ($ErrLine -replace '\x1b\[[0-9;]*[a-zA-Z]', '') }
        }

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
} -ThrottleLimit 3

if ($CleanSweep -and (Test-Path -LiteralPath $ActiveHistoryLog)) {
    Remove-Item -LiteralPath $ActiveHistoryLog -Force -ErrorAction SilentlyContinue
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] $Elapsed"
Write-Output "`n============================================="
Exit 0