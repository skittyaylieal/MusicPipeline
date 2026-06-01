Param (
    [string]$BackupDir
)

# Force Python to use UTF-8 encoding for all standard input/output streams
$env:PYTHONIOENCODING = "utf-8"

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Headless Lyric Engine & Tag Embedder" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

Write-Host "Updating Python package" -ForegroundColor Cyan
pip install --upgrade syncedlyrics

# Verify target directory exists
if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    Write-Host "[ERROR] Target directory could not be found: $BackupDir" -ForegroundColor Red
    Exit 1
}

Write-Host "[*] Scanning directory for audio files..." -ForegroundColor Yellow
$AudioFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }

if ($AudioFiles.Count -eq 0) {
    Write-Host "[+] No audio tracks found to process." -ForegroundColor Green
    Exit 0
}

Write-Host "[+] Found $($AudioFiles.Count) track(s). Initializing scraper..." -ForegroundColor Green
Write-Host "---------------------------------------------" -ForegroundColor DarkGray

foreach ($File in $AudioFiles) {
    Write-Host "[*] Processing: $($File.Name)" -ForegroundColor Cyan
    
    # 1. DEFINE PATHS USING BULLETPROOF INTERPOLATION
    $DirName = $File.DirectoryName
    $LrcFile = "$DirName\$($File.BaseName).lrc"
    $TxtFile = "$DirName\$($File.BaseName).txt"
    
    # 2. THE UPGRADE CHECK PHASE
    # Skip immediately if a high-quality synced .lrc companion file already exists
    if (Test-Path -LiteralPath $LrcFile) {
        Write-Host "    [-] Synced .lrc companion already exists. Skipping API call." -ForegroundColor Gray
        Write-Host "---------------------------------------------" -ForegroundColor DarkGray
        continue
    }

    # 3. CONSTRUCT EMBEDDING PRE-CHECK STRING
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
            sys.exit(2) # Found unsynced lyrics inside M4A
        elif isinstance(audio, FLAC) and 'lyrics' in audio and audio['lyrics']:
            sys.exit(2) # Found unsynced lyrics inside FLAC
    sys.exit(0) # Completely empty container
except Exception:
    sys.exit(0)
"@
    
    $PreCheckPython | python -
    $HasUnsyncedLyrics = ($LASTEXITCODE -eq 2)

    # Clean up file name to use as a search query
    $SearchQuery = $File.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    
    # -----------------------------------------------------------------
    # STAGE 1: EXHAUST ALL PREMIUM SYNCED LYRIC PROVIDERS
    # -----------------------------------------------------------------
    Write-Host "    [*] Searching premium databases for synced timing tags (.lrc)..." -ForegroundColor DarkCyan
    
    # Enforcing Musixmatch, NetEase, Megalyrics, and Lyricsify exclusively
    $SyncedArgs = @("-m", "syncedlyrics", "`"$SearchQuery`"", "-o", "`"$LrcFile`"", "--providers", "musixmatch", "netease", "megalyrics", "lyricsify")
    $null = Start-Process -FilePath "python" -ArgumentList $SyncedArgs -Wait -NoNewWindow

    if (Test-Path -LiteralPath $LrcFile) {
        Write-Host "    [+] Found pristine synced lyrics (.lrc). Preserving file next to track." -ForegroundColor Green
        Write-Host "---------------------------------------------" -ForegroundColor DarkGray
        # If a .txt accidentally leaked from these providers, scrub it away
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force }
        continue
    }

    # -----------------------------------------------------------------
    # STAGE 2: PLAIN TEXT FALLBACK MECHANISM (Only if file does not have tags)
    # -----------------------------------------------------------------
    if ($HasUnsyncedLyrics) {
        Write-Host "    [-] Synced missing, but track already has embedded plain text tags. Skipping fallback." -ForegroundColor Gray
        Write-Host "---------------------------------------------" -ForegroundColor DarkGray
        continue
    }

    Write-Host "    [!] No timed lyrics found. Attempting plain text fallback lookup..." -ForegroundColor Yellow
    
    # Route fallback purely through Genius/Luminate pools for raw structural text accuracy
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
        # Clean up any dead empty files generated by failed fallback cycles
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force }
    }
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    Lyric scraping and embedding complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0