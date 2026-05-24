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
        Write-Host "    [+] Scraped successfully. Embedding tags..." -ForegroundColor DarkGray

        # Double-escape paths for Python syntax safety
        $EscapedAudioPath = $File.FullName -replace '\\', '\\\\' -replace '"', '\\"'
        $EscapedLyricPath = $TargetLyricFile -replace '\\', '\\\\' -replace '"', '\\"'

        # Single line python execution to completely eliminate indentation/here-string formatting issues
        $PythonInline = "import mutagen; from mutagen.mp4 import MP4; from mutagen.flac import FLAC; lyrics = open('$EscapedLyricPath', 'r', encoding='utf-8').read(); f = mutagen.File('$EscapedAudioPath'); f['\xa9lyr' if isinstance(f, MP4) else 'lyrics'] = lyrics; f.save()"

        # Execute the embedder command safely
        $EmbedArgs = @("-c", $PythonInline)
        Start-Process -FilePath "python" -ArgumentList $EmbedArgs -Wait -NoNewWindow
        
        Write-Host "    [+] Metadata atomic sync complete." -ForegroundColor Green
    } else {
        Write-Host "    [-] No matching lyrics found across scanned repositories." -ForegroundColor Yellow
    }
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Lyric scraping and embedding complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0