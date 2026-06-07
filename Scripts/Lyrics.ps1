Param (
    [string]$BackupDir
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$env:PYTHONIOENCODING = "utf-8"
Clear-Host

Write-Output "============================================="
Write-Output "    PowerShell Module: Headless Lyric Engine & Tag Embedder"
Write-Output "============================================="

Write-Output "[*] Verifying background Python dependencies..."
# Quiet update so pip doesn't stall the console log buffer
pip install --upgrade syncedlyrics --quiet

if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    Write-Output "[ERROR] Target directory could not be found: $BackupDir"
    Exit 1
}

Write-Output "[*] Initializing ultra-fast deep database scan across all directories..."

# .NET SPEED UP: Instead of Get-ChildItem, this streams paths instantly without blocking RAM
try {
    $AllFiles = [System.IO.Directory]::EnumerateFiles($BackupDir, "*.*", [System.IO.SearchOption]::AllDirectories)
} catch {
    Write-Output "[ERROR] Failed to initialize deep directory enumeration: $_"
    Exit 1
}

# Rapid inline regex filter for your targeted audio containers
$AudioFiles = [System.Collections.Generic.List[string]]::new()
foreach ($File in $AllFiles) {
    if ($File -match '\.(flac|mp3|m4a)$') {
        $AudioFiles.Add($File)
    }
}

if ($AudioFiles.Count -eq 0) {
    Write-Output "[+] No audio tracks found across the system array."
    $MetricStopwatch.Stop()
    Write-Output "[METRIC] 00:00:00"
    Exit 0
}

Write-Output "[+] Deep scan complete. Found $($AudioFiles.Count) total track(s) to verify."
Write-Output "---------------------------------------------"

$ScannedCount = 0
foreach ($FilePath in $AudioFiles) {
    $ScannedCount++
    $FileInfo = [System.IO.FileInfo]::new($FilePath)
    
    # Send a heartbeat signature to your phone dashboard every single track so you know it's alive
    Write-Output "[*] [$ScannedCount/$($AudioFiles.Count)] Evaluating: $($FileInfo.Name)"
    
    $DirName = $FileInfo.DirectoryName
    $LrcFile = Join-Path $DirName "$($FileInfo.BaseName).lrc"
    $TxtFile = Join-Path $DirName "$($FileInfo.BaseName).txt"
    
    if (Test-Path -LiteralPath $LrcFile) {
         Write-Output "    [-] Synced .lrc companion already exists. Skipping API call."
         Write-Output "---------------------------------------------"
         continue
    }

    # Python Native Metadata Verification Block
    $TmpPyCheck = Join-Path $env:TEMP "mutagen_check.py"
    $PreCheckPython = @"
import mutagen, sys
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
try:
    audio = mutagen.File(r'$FilePath')
    if audio is not None:
        if isinstance(audio, MP4) and '\xa9lyr' in audio and audio['\xa9lyr']: sys.exit(2)
        elif isinstance(audio, FLAC) and 'lyrics' in audio and audio['lyrics']: sys.exit(2)
    sys.exit(0)
except Exception: sys.exit(0)
"@
    $PreCheckPython | Out-File $TmpPyCheck -Encoding utf8NoBOM
    python $TmpPyCheck
    $HasUnsyncedLyrics = ($LASTEXITCODE -eq 2)
    Remove-Item $TmpPyCheck -Force

    $SearchQuery = $FileInfo.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    Write-Output "    [*] Querying all global timeline indices..."
    
    # CRITICAL FIX: Run python INLINE instead of Start-Process.
    # This pipes python's live output strings directly into your WebsiteEngine stream log!
    $Providers = "lrclib", "musixmatch", "netease", "megalyrics", "megalobiz", "lyricsify"
    $PythonOutput = python -m syncedlyrics "$SearchQuery" -o "$LrcFile" --providers $Providers 2>&1
    
    if (Test-Path -LiteralPath $LrcFile) {
        Write-Output "    [+] Pristine timed timelines (.lrc) saved to disk."
        Write-Output "---------------------------------------------"
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force }
        continue
    }

    if ($HasUnsyncedLyrics) {
        Write-Output "    [-] Synced missing, but track container already possesses embedded plain text. Skipping."
        Write-Output "---------------------------------------------"
        continue
    }

    # Absolute quality fallback routine requested
    Write-Output "    [!] Timed matrix missing. Fallback initiated: Scraping Genius Engine..."
    $FallbackOutput = python -m syncedlyrics "$SearchQuery" -o "$LrcFile" --providers genius 2>&1

    if (Test-Path -LiteralPath $TxtFile) {
        Write-Output "    [+] Flat lyrics retrieved successfully. Committing Mutagen write operation..."
        
        $TmpPyEmbed = Join-Path $env:TEMP "mutagen_embed.py"
        $PythonCode = @"
import os, mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
try:
    with open(r'$TxtFile', 'r', encoding='utf-8') as f: lyrics_text = f.read()
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
    if os.path.exists(r'$TxtFile'): os.remove(r'$TxtFile')
except Exception as e: print(f'    [!] Mutagen structural error: {e}')
"@
        $PythonCode | Out-File $TmpPyEmbed -Encoding utf8NoBOM
        python $TmpPyEmbed 2>&1
        Remove-Item $TmpPyEmbed -Force
    } else {
        Write-Output "    [-] Critical: Track could not be matched across any global lyric indices."
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force }
    }
    Write-Output "---------------------------------------------"
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] $Elapsed"
Write-Output "============================================="
Exit 0