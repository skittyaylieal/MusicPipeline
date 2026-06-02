Param (
    [string]$BackupDir
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$env:PYTHONIOENCODING = "utf-8"
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Headless Lyric Engine & Tag Embedder" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Write-Host "Updating Python package" -ForegroundColor Cyan
pip install --upgrade syncedlyrics

if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    Write-Host "[ERROR] Target directory could not be found: $BackupDir" -ForegroundColor Red
    Exit 1
}

Write-Host "[*] Scanning directory for audio files..." -ForegroundColor Yellow
$AudioFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }

if ($AudioFiles.Count -eq 0) {
    Write-Host "[+] No audio tracks found to process." -ForegroundColor Green
    $MetricStopwatch.Stop()
    Write-Host "[METRIC] 00:00:00"
    Exit 0
}

Write-Host "[+] Found $($AudioFiles.Count) track(s). Initializing scraper..." -ForegroundColor Green
Write-Host "---------------------------------------------" -ForegroundColor DarkGray

foreach ($File in $AudioFiles) {
    Write-Host "[*] Processing: $($File.Name)" -ForegroundColor Cyan
    $DirName = $File.DirectoryName
    $LrcFile = "$DirName\$($File.BaseName).lrc"
    $TxtFile = "$DirName\$($File.BaseName).txt"
    
    if (Test-Path -LiteralPath $LrcFile) {
         Write-Host "    [-] Synced .lrc companion already exists. Skipping API call." -ForegroundColor Gray
         Write-Host "---------------------------------------------" -ForegroundColor DarkGray
         continue
    }

    $EscapedAudioPath = $File.FullName -replace '\\', '\\\\' -replace "'", "\'"
    $PreCheckPython = @"
import mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
import sys
try:
    audio = mutagen.File('$EscapedAudioPath')
    if audio is not None:
        if isinstance(audio, MP4) and '\xa9lyr' in audio and audio['\xa9lyr']:
             sys.exit(2)
        elif isinstance(audio, FLAC) and 'lyrics' in audio and audio['lyrics']:
            sys.exit(2)
    sys.exit(0)
except Exception:
    sys.exit(0)
"@
    
    $PreCheckPython | python -
    $HasUnsyncedLyrics = ($LASTEXITCODE -eq 2)
    $SearchQuery = $File.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    
    Write-Host "    [*] Querying all global databases for synced timelines (.lrc)..." -ForegroundColor DarkCyan
    $SyncedArgs = @("-m", "syncedlyrics", "`"$SearchQuery`"", "-o", "`"$LrcFile`"", "--providers", "lrclib", "musixmatch", "netease", "megalyrics", "megalobiz", "lyricsify")
    $null = Start-Process -FilePath "python" -ArgumentList $SyncedArgs -Wait -NoNewWindow

    if (Test-Path -LiteralPath $LrcFile) {
        Write-Host "    [+] Found pristine synced lyrics (.lrc). Preserving file next to track." -ForegroundColor Green
        Write-Host "---------------------------------------------" -ForegroundColor DarkGray
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force }
        continue
    }

    if ($HasUnsyncedLyrics) {
        Write-Host "    [-] Synced missing, but track already has embedded plain text tags. Skipping fallback." -ForegroundColor Gray
        Write-Host "---------------------------------------------" -ForegroundColor DarkGray
        continue
    }

    Write-Host "    [!] No timed lyrics found. Attempting absolute plain text fallback..." -ForegroundColor Yellow
    $FallbackArgs = @("-m", "syncedlyrics", "`"$SearchQuery`"", "-o", "`"$LrcFile`"", "--providers", "genius")
    $null = Start-Process -FilePath "python" -ArgumentList $FallbackArgs -Wait -NoNewWindow

    if (Test-Path -LiteralPath $TxtFile) {
        Write-Host "    [+] Found flat unsynced lyrics (.txt fallback). Embedding tag into metadata container..." -ForegroundColor DarkGray
        $EscapedLyricPath = $TxtFile -replace '\\', '\\\\' -replace "'", "\'"
        $PythonCode = @"
import os
import mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
try:
    with open('$EscapedLyricPath', 'r', encoding='utf-8') as f_lyric:
        lyrics_text = f_lyric.read()
    audio = mutagen.File('$EscapedAudioPath')
    if audio is not None:
         if isinstance(audio, MP4):
            audio['\xa9lyr'] = [lyrics_text]
            audio.save()
            print('    [+] Unsynced text tag cleanly written to M4A (\xa9lyr atom).')
        elif isinstance(audio, FLAC):
            audio['lyrics'] = lyrics_text
            audio.save()
            print('    [+] Unsynced text tag cleanly written to FLAC (Vorbis comments).')
    if os.path.exists('$EscapedLyricPath'):
        os.remove('$EscapedLyricPath')
except Exception as e:
    print(f'    [!-ERROR] Mutagen execution failed: {e}')
"@
        $PythonCode | python -
    } else {
        Write-Host "    [-] No matching lyrics found across any scanned repositories." -ForegroundColor Yellow
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force }
    }
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
}

$MetricStopwatch.Stop()
$Elapsed = [string]::Format("{0:hh\:mm\:ss}", $MetricStopwatch.Elapsed)
Write-Host "[METRIC] $Elapsed"
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0