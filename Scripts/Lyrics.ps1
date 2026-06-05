Param (
    [string]$BackupDir
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$env:PYTHONIOENCODING = "utf-8"
Clear-Host

Write-Output "============================================="
Write-Output "    PowerShell Module: Headless Lyric Engine & Tag Embedder"
Write-Output "============================================="

Write-Output "Updating Python package"
pip install --upgrade syncedlyrics

if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    Write-Output "[ERROR] Target directory could not be found: $BackupDir"
    Exit 1
}

Write-Output "[*] Scanning directory for audio files..."
$AudioFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }

if ($AudioFiles.Count -eq 0) {
    Write-Output "[+] No audio tracks found to process."
    $MetricStopwatch.Stop()
    Write-Output "[METRIC] 00:00:00"
    Exit 0
}

Write-Output "[+] Found $($AudioFiles.Count) track(s). Initializing scraper..."
Write-Output "---------------------------------------------"

foreach ($File in $AudioFiles) {
    Write-Output "[*] Processing: $($File.Name)"
    $DirName = $File.DirectoryName
    $LrcFile = Join-Path $DirName "$($File.BaseName).lrc"
    $TxtFile = Join-Path $DirName "$($File.BaseName).txt"
    
    if (Test-Path -LiteralPath $LrcFile) {
         Write-Output "    [-] Synced .lrc companion already exists. Skipping API call."
         Write-Output "---------------------------------------------"
         continue
    }

    # Python Execution Block
    $TmpPyCheck = Join-Path $env:TEMP "mutagen_check.py"
    $PreCheckPython = @"
import mutagen, sys
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
try:
    audio = mutagen.File(r'$($File.FullName)')
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

    $SearchQuery = $File.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    Write-Output "    [*] Querying all global databases for synced timelines (.lrc)..."
    
    $SyncedArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "--providers", "lrclib", "musixmatch", "netease", "megalyrics", "megalobiz", "lyricsify")
    Start-Process -FilePath "python" -ArgumentList $SyncedArgs -Wait -NoNewWindow

    if (Test-Path -LiteralPath $LrcFile) {
        Write-Output "    [+] Found pristine synced lyrics (.lrc). Preserving file next to track."
        Write-Output "---------------------------------------------"
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force }
        continue
    }

    if ($HasUnsyncedLyrics) {
        Write-Output "    [-] Synced missing, but track already has embedded plain text tags. Skipping fallback."
        Write-Output "---------------------------------------------"
        continue
    }

    Write-Output "    [!] No timed lyrics found. Attempting absolute plain text fallback..."
    $FallbackArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "--providers", "genius")
    Start-Process -FilePath "python" -ArgumentList $FallbackArgs -Wait -NoNewWindow

    if (Test-Path -LiteralPath $TxtFile) {
        Write-Output "    [+] Found flat unsynced lyrics (.txt fallback). Embedding tag into metadata container..."
        
        $TmpPyEmbed = Join-Path $env:TEMP "mutagen_embed.py"
        $PythonCode = @"
import os, mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
try:
    with open(r'$TxtFile', 'r', encoding='utf-8') as f: lyrics_text = f.read()
    audio = mutagen.File(r'$($File.FullName)')
    if audio is not None:
        if isinstance(audio, MP4):
            audio['\xa9lyr'] = [lyrics_text]
            audio.save()
            print('    [+] Unsynced text tag cleanly written to M4A (\xa9lyr atom).')
        elif isinstance(audio, FLAC):
            audio['lyrics'] = lyrics_text
            audio.save()
            print('    [+] Unsynced text tag cleanly written to FLAC (Vorbis comments).')
    if os.path.exists(r'$TxtFile'): os.remove(r'$TxtFile')
except Exception as e: print(f'    [!-ERROR] Mutagen execution failed: {e}')
"@
        $PythonCode | Out-File $TmpPyEmbed -Encoding utf8NoBOM
        python $TmpPyEmbed
        Remove-Item $TmpPyEmbed -Force
    } else {
        Write-Output "    [-] No matching lyrics found across any scanned repositories."
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force }
    }
    Write-Output "---------------------------------------------"
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Output "[METRIC] $Elapsed"
Write-Output "============================================="
Exit 0