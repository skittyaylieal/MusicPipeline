Param (
    [string]$BackupDir
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$env:PYTHONIOENCODING = "utf-8"
Clear-Host

Write-Output "============================================="
Write-Output "    PowerShell Module: Headless Lyric Engine & Tag Embedder"
Write-Output "============================================="

$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Unified Thread-Safe Logger matching the Downloader Engine (Fixed local scope tracking)
function Invoke-LogMsg([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $Reset = "$ESC[0m"
    
    # Base configuration color for Lyric Engine (Cyan-Blue styling)
    $ColorCode = "34" # Blue
    
    if ($Text -match '🛑|error:|ERROR:|Usage:|\[!\]') {
        $ColorCode = "1;31" # Bold Red
    } elseif ($Text -match '\[\+\]') {
        $ColorCode = "32" # Green for successful writes/finds
    }

    $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [LyricsEngine]$Reset"
    $FormattedLine = "$ColorPrefix $Text"
    
    Write-Output $FormattedLine
    
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

# Real-Time Execution Handler for tracking sub-Python tasks (Fixed asynchronous stream evaluation)
function Invoke-NativeProcess ([string]$Executable, [string[]]$ArgumentList) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName                = $Executable
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true 
    $psi.RedirectStandardInput  = $true 
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
    
    $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"

    foreach ($arg in $ArgumentList) { $psi.ArgumentList.Add($arg) }

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Close()

        while (-not $proc.HasExited) {
            [System.Threading.Thread]::Sleep(50)
            while (-not $proc.StandardOutput.EndOfStream) {
                $Line = $proc.StandardOutput.ReadLine()
                if ($Line) { Invoke-LogMsg "    [Python STDOUT] $Line" }
            }
            while (-not $proc.StandardError.EndOfStream) {
                $ErrLine = $proc.StandardError.ReadLine()
                if ($ErrLine) { Invoke-LogMsg "    [Python STDERR] $ErrLine" }
            }
        }

        while (-not $proc.StandardOutput.EndOfStream) {
            $Line = $proc.StandardOutput.ReadLine()
            if ($Line) { Invoke-LogMsg "    [Python STDOUT] $Line" }
        }
        while (-not $proc.StandardError.EndOfStream) {
            $ErrLine = $proc.StandardError.ReadLine()
            if ($ErrLine) { Invoke-LogMsg "    [Python STDERR] $ErrLine" }
        }

        return $proc.ExitCode
    } catch {
        Invoke-LogMsg "[🛑 PROCESS PANIC] Failed execution framework: $_"
        return -1
    }
}

Invoke-LogMsg "[*] Verifying background Python dependencies..."
$PipExit = Invoke-NativeProcess "pip" @("install", "--upgrade", "syncedlyrics", "mutagen", "--quiet")
Invoke-LogMsg "[*] Pip verification routine complete (Exit Code: $PipExit)."

if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    Invoke-LogMsg "[ERROR] Target backup directory could not be found: $BackupDir"
    Exit 1
}

Invoke-LogMsg "[*] Initializing ultra-fast deep database scan across: $BackupDir"

try {
    $AllFiles = [System.IO.Directory]::EnumerateFiles($BackupDir, "*.*", [System.IO.SearchOption]::AllDirectories)
} catch {
    Invoke-LogMsg "[ERROR] Failed to initialize deep directory enumeration: $_"
    Exit 1
}

$AudioFiles = [System.Collections.Generic.List[string]]::new()
foreach ($File in $AllFiles) {
    if ($File -match '\.(flac|mp3|m4a)$') {
        $AudioFiles.Add($File)
    }
}

if ($AudioFiles.Count -eq 0) {
    Invoke-LogMsg "[+] No audio tracks found across the system array."
    $MetricStopwatch.Stop()
    Invoke-LogMsg "[METRIC] 00:00:00"
    Exit 0
}

Invoke-LogMsg "[+] Deep scan complete. Found $($AudioFiles.Count) total track(s) to verify."
Invoke-LogMsg "---------------------------------------------"

$ScannedCount = 0
foreach ($FilePath in $AudioFiles) {
    $ScannedCount++
    $FileInfo = [System.IO.FileInfo]::new($FilePath)
    
    Invoke-LogMsg "[*] [$ScannedCount/$($AudioFiles.Count)] Evaluating: $($FileInfo.FullName)"
    
    $DirName = $FileInfo.DirectoryName
    $LrcFile = Join-Path $DirName "$($FileInfo.BaseName).lrc"
    $TxtFile = Join-Path $DirName "$($FileInfo.BaseName).txt"
    
    if (Test-Path -LiteralPath $LrcFile) {
         Invoke-LogMsg "    [-] Synced .lrc companion already exists on disk. Skipping API matching engine."
         Invoke-LogMsg "---------------------------------------------"
         continue
    }

    # Python Native Metadata Verification via Real-time Stream (With ID3 Support for MP3)
    Invoke-LogMsg "    [*] Querying embedded container tags for unsynced lyrics..."
    $TmpPyCheck = Join-Path $env:TEMP "mutagen_check.py"
    $PreCheckPython = @"
import mutagen, sys
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3
try:
    audio = mutagen.File(r'$FilePath')
    if audio is not None:
        if isinstance(audio, MP4) and '\xa9lyr' in audio and audio['\xa9lyr']: sys.exit(2)
        elif isinstance(audio, FLAC) and 'lyrics' in audio and audio['lyrics']: sys.exit(2)
        elif isinstance(audio, ID3) or (audio.tags and hasattr(audio.tags, 'getall')):
            for tag in audio.tags.getall('USLT'):
                if tag.text: sys.exit(2)
    sys.exit(0)
except Exception as e:
    print(f"Metadata scan failure: {e}")
    sys.exit(0)
"@
    $PreCheckPython | Out-File $TmpPyCheck -Encoding utf8NoBOM
    
    $CheckExitCode = Invoke-NativeProcess "python" @($TmpPyCheck)
    $HasUnsyncedLyrics = ($CheckExitCode -eq 2)
    Remove-Item $TmpPyCheck -Force
    
    Invoke-LogMsg "    [*] Internal metadata analysis complete. Unsynced state present: $HasUnsyncedLyrics"

    $SearchQuery = $FileInfo.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    Invoke-LogMsg "    [*] Formulated indexing search target string: '$SearchQuery'"
    Invoke-LogMsg "    [*] Launching global timeline sync index query sequence..."
    
    # Quality prioritized sequence definition
    $TimedProviders = @("lrclib", "musixmatch", "netease", "megalobiz")
    $LrcFound = $false

    foreach ($Provider in $TimedProviders) {
        Invoke-LogMsg "    [*] Querying matrix source: [$Provider]"
        $LrcArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "-p", $Provider)
        $LrcExitCode = Invoke-NativeProcess "python" $LrcArgs
        
        if (Test-Path -LiteralPath $LrcFile) {
            Invoke-LogMsg "    [+] Pristine timed timelines (.lrc) successfully committed via [$Provider]."
            Invoke-LogMsg "---------------------------------------------"
            if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force }
            $LrcFound = $true
            break
        }
    }
    
    if ($LrcFound) { continue }

    if ($HasUnsyncedLyrics) {
        Invoke-LogMsg "    [-] Timed tracking missing, but audio container holds embedded plain text. Aborting search array."
        Invoke-LogMsg "---------------------------------------------"
        continue
    }

    # Absolute quality fallback routine: Sync missed, drop into Genius tag compilation
    Invoke-LogMsg "    [!] Timed matrix missing. Fallback initiated: Scraping Genius Engine via Native Subprocess..."
    $FallbackArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "-p", "genius")
    $FallbackExitCode = Invoke-NativeProcess "python" $FallbackArgs

    # Fix logic flow matching your rule: syncedlyrics saves genius scrapes as .txt if it's plain lyrics.
    # If it accidentally dropped an un-timed .lrc, rename it immediately to feed the Mutagen pipeline.
    if (Test-Path -LiteralPath $LrcFile) {
        Rename-Item -LiteralPath $LrcFile -NewName "$($FileInfo.BaseName).txt" -Force
    }

    if (Test-Path -LiteralPath $TxtFile) {
        Invoke-LogMsg "    [+] Flat text lyrics returned by fallback. Constructing Mutagen database encoder..."
        
        $TmpPyEmbed = Join-Path $env:TEMP "mutagen_embed.py"
        $PythonCode = @"
import os, mutagen, sys
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3, USLT
try:
    with open(r'$TxtFile', 'r', encoding='utf-8') as f: lyrics_text = f.read()
    
    # Safe check for file structure tags
    audio = mutagen.File(r'$FilePath')
    if audio is not None:
        if isinstance(audio, MP4):
            audio['\xa9lyr'] = [lyrics_text]
            audio.save()
            print('    [+] Unsynced text tag written to M4A container.')
        elif isinstance(audio, FLAC):
            audio['lyrics'] = lyrics_text
            audio.save()
            print('    [+] Unsynced text tag written to FLAC container.')
        else:
            # Fallback for ID3/MP3 environments
            try:
                tags = ID3(r'$FilePath')
            except Exception:
                tags = ID3()
            tags.add(USLT(encoding=3, lang='eng', desc='Lyrics', text=lyrics_text))
            tags.save(r'$FilePath')
            print('    [+] Unsynced USLT tag written to MP3 container.')
            
    if os.path.exists(r'$TxtFile'): os.remove(r'$TxtFile')
except Exception as e: 
    print(f'    [!] Mutagen structural error: {e}')
    sys.exit(1)
"@
        $PythonCode | Out-File $TmpPyEmbed -Encoding utf8NoBOM
        $EmbedExitCode = Invoke-NativeProcess "python" @($TmpPyEmbed)
        Remove-Item $TmpPyEmbed -Force
        Invoke-LogMsg "    [*] Tag embed operations complete (Exit Code: $EmbedExitCode)."
    } else {
        Invoke-LogMsg "    [-] Critical Error: Track could not be targeted or verified across any global API indices."
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force }
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force }
    }
    Invoke-LogMsg "---------------------------------------------"
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Invoke-LogMsg "[METRIC] Total Engine Run Duration: $Elapsed"
Write-Output "============================================="
Exit 0