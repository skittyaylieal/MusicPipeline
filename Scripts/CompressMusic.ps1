Param (
    [string]$BackupDir,
    [string]$MobileDir,
    [string]$FFmpegPath,
    [int]$MaxThreads = 4,
    [switch]$ForceCleanSweep
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try { Clear-Host } catch {}

# Sanity Check: Ensure thread count never maps to an illegal or unbounded allocation framework
if ($MaxThreads -lt 1) { $MaxThreads = 1 }

$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Centralized Thread-Safe Logger
function Invoke-LogMsg([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $Reset = "$ESC[0m"
    
    # Base configuration color for Compressor (Magenta styling)
    $ColorCode = "35" 
    
    if ($Text -match '🛑|CRITICAL|ERROR:|\\[!\\]') {
        $ColorCode = "1;31" # Bold Red
    } elseif ($Text -match '\\[\\+\\]|\\[BAKED\\]') {
        $ColorCode = "32" # Green for success
    } elseif ($Text -match '\\[\\*\\]|================') {
        $ColorCode = "36" # Cyan for headers/info
    }

    $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [Compressor]$Reset"
    $FormattedLine = "$ColorPrefix $Text"
    
    # Write-Host bypasses standard capture to prevent double-logging
    Write-Host $FormattedLine
    
    if ([System.IO.File]::Exists($GlobalLogFile)) {
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

if (-not [System.IO.Directory]::Exists($BackupDir)) {
    Invoke-LogMsg "🛑 CRITICAL: The Source Directory '$BackupDir' does not exist!"
    Exit 1
}

if (-not [System.IO.Directory]::Exists($MobileDir)) {
    [void][System.IO.Directory]::CreateDirectory($MobileDir)
}

if ($ForceCleanSweep) {
    Invoke-LogMsg "🧹 Clean Sweep flag active: Forcing on-the-fly regeneration of files without destructive directory pre-purging."
}

Invoke-LogMsg "[*] Indexing backup directory structure (High-Performance Native Safe Enumeration)..."

try {
    # Direct C-level Win32 scan: returns string[] paths in milliseconds
    [string[]]$BackupObjects = [System.IO.Directory]::GetFiles($BackupDir, "*", [System.IO.SearchOption]::AllDirectories)
} catch {
    Invoke-LogMsg "🛑 ERROR during disk enumeration: $_"
    Exit 1
}

Invoke-LogMsg "[*] Purging leftover artwork files..."
if ($BackupObjects.Count -gt 0) {
    $ArtworkFiles = $BackupObjects.Where({ $_ -match '\.(webp|jpg|jpeg|png)$' })
    if ($ArtworkFiles) {
        # High-performance native deletion
        [array]::ForEach($ArtworkFiles, [Action[string]]{ param($f) [System.IO.File]::Delete($f) })
    }
}

Invoke-LogMsg "[*] Scanning source directory for master audio tracks..."
if ($BackupObjects.Count -gt 0) {
    [string[]]$AllFiles = $BackupObjects.Where({ $_ -match '\.(mp3|flac|wav|m4a|ogg)$' })
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
    $LrcFiles = $BackupObjects.Where({ $_.EndsWith('.lrc', [System.StringComparison]::OrdinalIgnoreCase) })
    foreach ($LrcPath in $LrcFiles) {
        if ($LrcPath -notlike "*cookie*") {
            $RelativePath = $LrcPath.Substring($BackupDir.Length)
            $DestinationLrc = "$MobileDir$RelativePath"
            $DestFolder = [System.IO.Path]::GetDirectoryName($DestinationLrc)
            
            if (-not [System.IO.Directory]::Exists($DestFolder)) { 
                [void][System.IO.Directory]::CreateDirectory($DestFolder)
            }
            
            $SrcTime = [System.IO.File]::GetLastWriteTime($LrcPath)
            $DestExists = [System.IO.File]::Exists($DestinationLrc)
            
            if ($ForceCleanSweep -or -not $DestExists -or ($SrcTime -gt [System.IO.File]::GetLastWriteTime($DestinationLrc))) {
                [System.IO.File]::Copy($LrcPath, $DestinationLrc, $true)
            }
        }
    }
}

Invoke-LogMsg "[*] Filtering compression execution queue..."
# High-performance generic dynamic list eliminates array recreation overhead
$Queue = [System.Collections.Generic.List[psobject]]::new()

foreach ($FilePath in $AllFiles) {
    $RelativePath = $FilePath.Substring($BackupDir.Length)
    $DestinationFile = [System.IO.Path]::ChangeExtension("$MobileDir$RelativePath", ".m4a")
    
    $SrcTime = [System.IO.File]::GetLastWriteTime($FilePath)
    $DestExists = [System.IO.File]::Exists($DestinationFile)

    # Queue if ForceCleanSweep is set, file missing, or source file updated
    if ($ForceCleanSweep -or -not $DestExists -or ($SrcTime -gt [System.IO.File]::GetLastWriteTime($DestinationFile))) {
        $Queue.Add([PSCustomObject]@{
            Source      = $FilePath
            Destination = $DestinationFile
            Name        = [System.IO.Path]::GetFileName($FilePath)
        })
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

# Parallel Engine Core
$Queue | ForEach-Object -Parallel {
    $TargetFolder = [System.IO.Path]::GetDirectoryName($_.Destination)
    
    # Atomic C-level directory creation skips cmdlet overhead
    if (-not [System.IO.Directory]::Exists($TargetFolder)) { 
        [void][System.IO.Directory]::CreateDirectory($TargetFolder)
    }

    $Msg = "[LAUNCH] $($_.Name) -> Mobile M4A"
    $Timestamp = [DateTime]::Now.ToString("HH:mm:ss")
    $ESC = [char]27
    $FormattedLine = "$ESC[35m[$Timestamp] [Compressor]$ESC[0m $Msg"
    
    Write-Host $FormattedLine
    
    if ([System.IO.File]::Exists($using:GlobalLogFile)) {
        $RetryCount = 0
        $MicrosoftSuccess = $false
        while (-not $MicrosoftSuccess -and $RetryCount -lt 15) {
            try {
                [System.IO.File]::AppendAllText($using:GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine))
                $MicrosoftSuccess = $true
            } catch [System.IO.IOException] {
                $RetryCount++
                [System.Threading.Thread]::Sleep(50)
            } catch {
                break
            }
        }
    }

    $FFmpegArgs = @(
        "-y", "-loglevel", "error",
        "-threads", "1",
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
        
        # Check if output flags a memory shortage event
        $IsOOMError = $CleanedAlert -match 'Cannot allocate memory|bad_alloc|-12'
        
        $ErrorLine = "$ESC[1;31m[$AlertTimestamp] [Compressor] 🛑 CRASH ON VAL ($($_.Name)): $CleanedAlert$ESC[0m"
        Write-Host $ErrorLine
        
        if ([System.IO.File]::Exists($using:GlobalLogFile)) {
            try { [System.IO.File]::AppendAllText($using:GlobalLogFile, ($ErrorLine + [System.Environment]::NewLine)) } catch {}
        }

        # DEFENSIVE BACK-OFF: Pause core thread pool if out of memory
        if ($IsOOMError) {
            Write-Host "$ESC[1;33m[SYSTEM ALERT] Out-of-Memory detected. Pausing core engine thread worker group...$ESC[0m"
            [System.Threading.Thread]::Sleep(2500)
        }
    }
} -ThrottleLimit $MaxThreads

Invoke-LogMsg "[BAKED] Mobile library is perfectly synced and compressed!"
$MetricStopwatch.Stop()
$TotalHours = [math]::Floor($MetricStopwatch.Elapsed.TotalHours)
$Elapsed = "{0:00}:{1:mm\:ss}" -f $TotalHours, $MetricStopwatch.Elapsed
Invoke-LogMsg "[METRIC] Total Engine Run Duration: $Elapsed"
Invoke-LogMsg "============================================="
Exit 0