Param (
    [string]$BackupDir,
    [string]$MobileDir,
    [string]$FFmpegPath,
    [int]$MaxThreads = 4
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Clear-Host
} catch {}

$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Unified Thread-Safe Logger
function Invoke-LogMsg([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $Reset = "$ESC[0m"
    
    # Base configuration color for Compressor (Magenta styling)
    $ColorCode = "35" 
    
    if ($Text -match '🛑|CRITICAL|ERROR:|\[!\]') {
        $ColorCode = "1;31" # Bold Red
    } elseif ($Text -match '\[\+\]|\[BAKED\]') {
        $ColorCode = "32" # Green for success
    } elseif ($Text -match '\[\*\]|================') {
        $ColorCode = "36" # Cyan for headers/info
    }

    $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [Compressor]$Reset"
    $FormattedLine = "$ColorPrefix $Text"
    
    # Write-Host bypasses standard capture to prevent double-logging
    Write-Host $FormattedLine
    
    if (Test-Path -LiteralPath $GlobalLogFile) {
        $RetryCount = 0
        $MaxRetries = 15
        $Success    = $false
        
        while (-not $Success -and $RetryCount -lt $MaxRetries) {
            try {
                [System.IO.File]::AppendAllText($GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine))
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

Invoke-LogMsg "============================================="
Invoke-LogMsg "    PowerShell Module: Parallel Audio Compressor"
Invoke-LogMsg "============================================="

if (-not (Test-Path -LiteralPath $BackupDir)) {
    Invoke-LogMsg "🛑 CRITICAL: The Source Directory '$BackupDir' does not exist!"
    Exit 1
}

if (-not (Test-Path -LiteralPath $MobileDir)) {
    New-Item -ItemType Directory -LiteralPath $MobileDir -Force | Out-Null
}

# --- OPTIMIZATION: SINGLE-PASS DISK EXTRACTION ---
Invoke-LogMsg "[*] Indexing backup directory structure (Single-Pass)..."
$BackupObjects = Get-ChildItem -LiteralPath $BackupDir -Recurse -File -ErrorAction SilentlyContinue

# 1. Filter and purge artwork directly out of the memory collection
Invoke-LogMsg "[*] Purging leftover artwork files..."
$BackupObjects | Where-Object { $_.Extension -match '^\.(webp|jpg|jpeg|png)$' } | 
    Remove-Item -Force -ErrorAction SilentlyContinue

# 2. Filter out audio files from the memory collection without touching the disk again
Invoke-LogMsg "[*] Scanning source directory for master audio tracks..."
$AllFiles = $BackupObjects | Where-Object { $_.Extension -match '^\.(mp3|flac|wav|m4a|ogg)$' }

if (-not $AllFiles -or $AllFiles.Count -eq 0) {
    Invoke-LogMsg "[+] No source audio tracks found to process!"
    $MetricStopwatch.Stop()
    Invoke-LogMsg "[METRIC] 00:00:00"
    Exit 0
}

# 3. Process timed lyrics (.lrc) out of the memory collection
Invoke-LogMsg "[*] Syncing timed lyric (.lrc) files..."
$BackupObjects | Where-Object { $_.Extension -eq '.lrc' } | 
ForEach-Object {
    if ($_.Name -notlike "*cookie*") {
        $RelativePath = $_.FullName.Substring($BackupDir.Length)
        $DestinationLrc = "$MobileDir$RelativePath"
        $DestFolder = [System.IO.Path]::GetDirectoryName($DestinationLrc)
        if (-not (Test-Path -LiteralPath $DestFolder)) { New-Item -ItemType Directory -LiteralPath $DestFolder -Force | Out-Null }
        if (-not (Test-Path -LiteralPath $DestinationLrc) -or ($_.LastWriteTime -gt (Get-Item -LiteralPath $DestinationLrc).LastWriteTime)) {
            Copy-Item -LiteralPath $_.FullName -Destination $DestinationLrc -Force
        }
    }
}

Invoke-LogMsg "[*] Filtering out already compressed files..."
$Queue = @()
foreach ($File in $AllFiles) {
    $RelativePath = $File.FullName.SubString($BackupDir.Length)
    $DestinationFile = [System.IO.Path]::ChangeExtension("$MobileDir$RelativePath", ".m4a")

    if (-not (Test-Path -LiteralPath $DestinationFile) -or ($File.LastWriteTime -gt (Get-Item -LiteralPath $DestinationFile).LastWriteTime)) {
        $Queue += [PSCustomObject]@{
            Source      = $File.FullName
            Destination = $DestinationFile
            Name        = $File.Name
        }
    }
}

if ($Queue.Count -eq 0) {
    Invoke-LogMsg "[+] Mobile folder completely up to date. 0 tracks queued."
    $MetricStopwatch.Stop()
    Invoke-LogMsg "[METRIC] $("{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed)"
    Exit 0
}

Invoke-LogMsg "[+] Filtering complete! $($Queue.Count) tracks require compression."
Invoke-LogMsg "[+] Spawning parallel ffmpeg processing threads (Max Workers: $MaxThreads)`n"

# Optimization: Modern Parallel Multi-threaded Core Architecture
$Queue | ForEach-Object -Parallel {
    $TargetFolder = [System.IO.Path]::GetDirectoryName($_.Destination)
    if (-not (Test-Path -LiteralPath $TargetFolder)) { New-Item -ItemType Directory -LiteralPath $TargetFolder -Force | Out-Null }

    # Inline thread-safe logger for parallel workers
    $Msg = "[LAUNCH] $($_.Name) -> Mobile M4A"
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $FormattedLine = "$ESC[35m[$Timestamp] [Compressor]$ESC[0m $Msg"
    
    Write-Host $FormattedLine
    
    if (Test-Path -LiteralPath $using:GlobalLogFile) {
        $RetryCount = 0
        $Success    = $false
        while (-not $Success -and $RetryCount -lt 15) {
            try {
                [System.IO.File]::AppendAllText($using:GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine))
                $Success = $true
            } catch {
                $RetryCount++
                [System.Threading.Thread]::Sleep(50)
            }
        }
    }

    $FFmpegArgs = @(
        "-y", "-loglevel", "error",
        "-i", $_.Source,
        "-c:a", "aac", "-vbr", "4",
        "-map", "0:a",
        "-map", "0:v?",
        "-c:v", "copy", "-disposition:v", "attached_pic",
        "-map_metadata", "0", "-id3v2_version", "3",
        $_.Destination
    )

    # --- DEBUG ENGINE: Capture standard error streams ---
    $FFmpegOutput = & $using:FFmpegPath @FFmpegArgs 2>&1

    # If FFmpeg exited with a code other than 0, it broke
    if ($LASTEXITCODE -ne 0) {
        $AlertTimestamp = (Get-Date).ToString("HH:mm:ss")
        $CleanedAlert = $FFmpegOutput -join " "
        $ErrorLine = "$ESC[1;31m[$AlertTimestamp] [Compressor] 🛑 CRASH ON VAL ($($_.Name)): $CleanedAlert$ESC[0m"
        
        # Spit it out to the console immediately
        Write-Host $ErrorLine
        
        # Force it into the web log stream so you can read it on your dashboard
        if (Test-Path -LiteralPath $using:GlobalLogFile) {
            try { [System.IO.File]::AppendAllText($using:GlobalLogFile, ($ErrorLine + [System.Environment]::NewLine)) } catch {}
        }
    }
} -ThrottleLimit $MaxThreads

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Invoke-LogMsg "[BAKED] Mobile library is perfectly synced and compressed!"
Invoke-LogMsg "[METRIC] $Elapsed"
Invoke-LogMsg "============================================="
Exit 0