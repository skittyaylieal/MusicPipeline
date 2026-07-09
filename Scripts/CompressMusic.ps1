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

# Sanity Check: Ensure thread count never maps to an illegal or unbounded allocation framework
if ($MaxThreads -lt 1) { $MaxThreads = 1 }

$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Unified Thread-Safe Logger
function Invoke-LogMsg([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $Reset = "$ESC[0m"
    
    # Base configuration color for Compressor (Magenta styling)
    $ColorCode = "35" 
    
    if ($Text -match '🛑|CRITICAL|ERROR:|\\[!\\]') {
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
    New-Item -ItemType Directory -Path $MobileDir -Force | Out-Null
}

Invoke-LogMsg "[*] Indexing backup directory structure (High-Performance Native Safe Enumeration)..."

try {
    $DirectoryInfo = [System.IO.DirectoryInfo]::new($BackupDir)
    $RawFiles = $DirectoryInfo.EnumerateFiles("*", [System.IO.SearchOption]::AllDirectories) | 
        Where-Object { $_.Attributes -notmatch 'ReparsePoint' } | 
        ForEach-Object { $_.FullName }
        
    [string[]]$BackupObjects = if ($RawFiles) { @($RawFiles) } else { @() }
} catch {
    Invoke-LogMsg "🛑 ERROR during disk enumeration: $_"
    Exit 1
}

Invoke-LogMsg "[*] Purging leftover artwork files..."
if ($BackupObjects.Count -gt 0) {
    # FIXED: Single backslash for literal dot matching
    $ArtworkFiles = $BackupObjects | Where-Object { $_ -match '\.(webp|jpg|jpeg|png)$' }
    if ($ArtworkFiles) {
        @($ArtworkFiles) | ForEach-Object { Remove-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue }
    }
}

Invoke-LogMsg "[*] Scanning source directory for master audio tracks..."
if ($BackupObjects.Count -gt 0) {
    # FIXED: Single backslash for literal dot matching
    $AudioMatch = $BackupObjects | Where-Object { $_ -match '\.(mp3|flac|wav|m4a|ogg)$' }
    [string[]]$AllFiles = if ($AudioMatch) { @($AudioMatch) } else { @() }
} else {
    [string[]]$AllFiles = @()
}

if ($AllFiles.Count -eq 0) {
    Invoke-LogMsg "[+] No source audio tracks found to process!"
    $MetricStopwatch.Stop()
    Invoke-LogMsg "[METRIC] 00:00:00"
    Exit 0
}

Invoke-LogMsg "[*] Syncing timed lyric (.lrc) files..."
if ($BackupObjects.Count -gt 0) {
    $LrcFiles = $BackupObjects | Where-Object { $_ -like '*.lrc' }
    if ($LrcFiles) {
        @($LrcFiles) | ForEach-Object {
            if ($_ -notlike "*cookie*") {
                $RelativePath = $_.Substring($BackupDir.Length)
                $DestinationLrc = "$MobileDir$RelativePath"
                $DestFolder = [System.IO.Path]::GetDirectoryName($DestinationLrc)
                
                if (-not (Test-Path -LiteralPath $DestFolder)) { 
                    New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null 
                }
                
                $SrcTime = [System.IO.File]::GetLastWriteTime($_)
                if (-not (Test-Path -LiteralPath $DestinationLrc) -or ($SrcTime -gt [System.IO.File]::GetLastWriteTime($DestinationLrc))) {
                    Copy-Item -LiteralPath $_ -Destination $DestinationLrc -Force
                }
            }
        }
    }
}

Invoke-LogMsg "[*] Filtering out already compressed files..."
$Queue = @()
foreach ($FilePath in $AllFiles) {
    $RelativePath = $FilePath.SubString($BackupDir.Length)
    $DestinationFile = [System.IO.Path]::ChangeExtension("$MobileDir$RelativePath", ".m4a")
    
    $SrcTime = [System.IO.File]::GetLastWriteTime($FilePath)

    if (-not (Test-Path -LiteralPath $DestinationFile) -or ($SrcTime -gt [System.IO.File]::GetLastWriteTime($DestinationFile))) {
        $Queue += [PSCustomObject]@{
            Source      = $FilePath
            Destination = $DestinationFile
            Name        = [System.IO.Path]::GetFileName($FilePath)
        }
    }
}

if ($Queue.Count -eq 0) {
    Invoke-LogMsg "[+] Mobile folder completely up to date. 0 tracks queued."
    $MetricStopwatch.Stop()
    # FIXED: Single backslashes for string format escaping
    Invoke-LogMsg "[METRIC] $("{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed)"
    Exit 0
}

Invoke-LogMsg "[+] Filtering complete! $($Queue.Count) tracks require compression."
Invoke-LogMsg "[+] Spawning parallel ffmpeg processing threads (Max Workers: $MaxThreads)`n"

# Optimization: Modern Parallel Multi-threaded Core Architecture
$Queue | ForEach-Object -Parallel {
    $TargetFolder = [System.IO.Path]::GetDirectoryName($_.Destination)
    
    if (-not (Test-Path -LiteralPath $TargetFolder)) { 
        New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null 
    }

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

    # Execute FFmpeg securely inside tracking wrapper
    $FFmpegOutput = & $using:FFmpegPath @FFmpegArgs 2>&1

    if ($LASTEXITCODE -ne 0) {
        $AlertTimestamp = (Get-Date).ToString("HH:mm:ss")
        $CleanedAlert = $FFmpegOutput -join " "
        
        # Check if the output explicitly flags a memory shortage event
        $IsOOMError = $CleanedAlert -match 'Cannot allocate memory|bad_alloc|-12'
        
        $ErrorLine = "$ESC[1;31m[$AlertTimestamp] [Compressor] 🛑 CRASH ON VAL ($($_.Name)): $CleanedAlert$ESC[0m"
        Write-Host $ErrorLine
        
        if (Test-Path -LiteralPath $using:GlobalLogFile) {
            try { [System.IO.File]::AppendAllText($using:GlobalLogFile, ($ErrorLine + [System.Environment]::NewLine)) } catch {}
        }

        # DEFENSIVE BACK-OFF: If system memory is exhausted, enforce an immediate 2.5 second sleep
        if ($IsOOMError) {
            Write-Host "$ESC[1;33m[SYSTEM ALERT] Out-of-Memory detected. Pausing core engine thread worker group...$ESC[0m"
            [System.Threading.Thread]::Sleep(2500)
        }
    }

    # Routine Cleanup: Periodically flush thread context memory to keep the runspace clean
    if ((Get-Random -Min 1 -Max 100) -le 15) {
        [System.GC]::Collect()
    }
} -ThrottleLimit $MaxThreads

$MetricStopwatch.Stop()
# FIXED: Single backslashes for string format escaping
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Invoke-LogMsg "[BAKED] Mobile library is perfectly synced and compressed!"
Invoke-LogMsg "[METRIC] $Elapsed"
Invoke-LogMsg "============================================="
Exit 0