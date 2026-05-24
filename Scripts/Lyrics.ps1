param (
    [string]$BackupDir
)

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Headless Lyric Engine & Tag Embedder" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Verify target directory exists
if (-not (Test-Path -Path $BackupDir -PathType Container)) {
    Write-Host "[ERROR] Target directory could not be found: $BackupDir" -ForegroundColor Red
    Exit 1
}

Write-Host "[*] Scanning directory for audio files..." -ForegroundColor Yellow
$AudioFiles = Get-ChildItem -Path $BackupDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }

if ($AudioFiles.Count -eq 0) {
    Write-Host "[+] No audio tracks found to process." -ForegroundColor Green
    Exit 0
}

Write-Host "[+] Found $($AudioFiles.Count) track(s). Initializing scraper..." -ForegroundColor Green
Write-Host "---------------------------------------------" -ForegroundColor DarkGray

foreach ($File in $AudioFiles) {
    Write-Host "[*] Processing: $($File.Name)" -ForegroundColor Cyan
    
    # Clean up file name to use as a search query
    $SearchQuery = $File.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    
    # Define primary (.lrc) and fallback (.txt) paths
    $LrcFile = Join-Path -Path $File.DirectoryName -ChildPath "$($File.BaseName).lrc"
    $TxtFile = Join-Path -Path $File.DirectoryName -ChildPath "$($File.BaseName).txt"
    
    # 1. Execute syncedlyrics
    $ScrapeArgs = @("-m", "syncedlyrics", "`"$SearchQuery`"", "-o", "`"$LrcFile`"")
    $null = Start-Process -FilePath "python" -ArgumentList $ScrapeArgs -Wait -NoNewWindow

    # 2. Determine which lyric file was created
    $TargetLyricFile = $null
    if (Test-Path -Path $LrcFile) { $TargetLyricFile = $LrcFile }
    elseif (Test-Path -Path $TxtFile) { $TargetLyricFile = $TxtFile }

    # 3. Embed lyrics into file metadata tags if found
    if ($TargetLyricFile) {
        $LyricContent = [File]::ReadAllText($TargetLyricFile) -replace '"', '\\"' -replace "`n", '\n' -replace "`r", ''
        $EscapedAudioPath = $File.FullName -replace '\\', '\\\\' -replace '"', '\\"'

        Write-Host "    [+] Scraped successfully. Embedding tags..." -ForegroundColor DarkGray

        # Run an inline Python script using Mutagen to handle M4A (MP4) vs FLAC natively
        $PythonCode = @"
import mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC

audio_path = "$EscapedAudioPath"
lyrics_text = "$LyricContent"

try:
    f = mutagen.File(audio_path)
    if isinstance(f, MP4):
        f['\xa9lyr'] = [lyrics_text]
        f.save()
        print('    [+] Embedded into M4A metadata atoms.')
    elif isinstance(f, FLAC):
        f['lyrics'] = lyrics_text
        f.save()
        print('    [+] Embedded into FLAC Vorbis comments.')
except Exception as e:
    print(f'    [!-ERROR] Metadata injection failed: {e}')
"@

        # Execute the embedder
        $EmbedArgs = @("-c", $PythonCode)
        Start-Process -FilePath "python" -ArgumentList $EmbedArgs -Wait -NoNewWindow
    } else {
        Write-Host "    [-] No matching lyrics found across scanned repositories." -ForegroundColor Yellow
    }
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Lyric scraping and embedding complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0