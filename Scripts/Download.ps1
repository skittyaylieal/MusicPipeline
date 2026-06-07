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
        $psi.RedirectStandardInput  = $true 
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
        $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"

        foreach ($arg in $YTDLArgs) { $psi.ArgumentList.Add($arg) }

        $proc = [System.Diagnostics.Process]::Start($psi)
        
        $proc.StandardInput.Close()

        # NATIVE REAL-TIME LINE READER (Natively preservation tracking)
        while (-not $proc.HasExited) {
            if ($proc.StandardOutput.Peek() -ge 0) {
                $Line = $proc.StandardOutput.ReadLine()
                if ($Line) {
                    Invoke-LogMsg $Line
                }
            }
            if ($proc.StandardError.Peek() -ge 0) {
                $ErrLine = $proc.StandardError.ReadLine()
                if ($ErrLine) {
                    Invoke-LogMsg $ErrLine
                    [System.IO.File]::AppendAllText($ErrorLogPath, ($ErrLine + [System.Environment]::NewLine))
                }
            }
            [System.Threading.Thread]::Sleep(30)
        }

        # Final queue purge block post-execution exit
        while ($proc.StandardOutput.Peek() -ge 0) {
            $Line = $proc.StandardOutput.ReadLine()
            if ($Line) { Invoke-LogMsg $Line }
        }
        while ($proc.StandardError.Peek() -ge 0) {
            $ErrLine = $proc.StandardError.ReadLine()
            if ($ErrLine) { Invoke-LogMsg $ErrLine }
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