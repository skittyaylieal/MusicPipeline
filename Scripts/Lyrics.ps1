param (
    [string]$BackupDir
)

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Headless Lyric Engine" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Verify target directory exists
if (-not (Test-Path -Path $BackupDir -PathType Container)) {
    Write-Host "[ERROR] Target directory could not be found: $BackupDir" -ForegroundColor Red
    Exit 1
}

# Verify syncedlyrics installation
if (-not (Get-Command syncedlyrics -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] 'syncedlyrics' CLI utility is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please run: pip install syncedlyrics" -ForegroundColor Yellow
    Exit 1
}

Write-Host "[*] Scanning directory for audio files..." -ForegroundColor Yellow
$AudioFiles = Get-ChildItem -Path $BackupDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }

if ($AudioFiles.Count -eq 0) {
    Write-Host "[+] No audio tracks found to process." -ForegroundColor Green
    Exit 0
}

Write-Host "[+] Found $($AudioFiles.Count) track(s). Initializing multi-repository scraper..." -ForegroundColor Green
Write-Host "---------------------------------------------" -ForegroundColor DarkGray

foreach ($File in $AudioFiles) {
    Write-Host "[*] Processing: $($File.Name)" -ForegroundColor Cyan
    
    # 1. Use the file name as a fallback search query (Cleaned up)
    # Assumes format "Artist - Title" or "Title". Adjust regex if your naming convention varies.
    $SearchQuery = $File.BaseName
    
    Write-Host "    -> Querying repositories for '$SearchQuery'..." -ForegroundColor DarkGray
    
    # 2. Define the output lyrics file path (e.g., song.lrc or song.txt)
    $OutputFile = Join-Path -Path $File.DirectoryName -ChildPath "$($File.BaseName).lrc"
    
    # 3. Execute syncedlyrics CLI
    # Reaches out to Musixmatch, Genius, LRCLIB, etc.
    $Arguments = @(
        "`"$SearchQuery`"",
        "-o", "`"$OutputFile`""
    )
    
    $Process = Start-Process -FilePath "syncedlyrics" -ArgumentList $Arguments -Wait -NoNewWindow -PassThru
    
    # 4. Check if a lyric file was successfully created
    if (Test-Path -Path $OutputFile) {
        Write-Host "    [+] Success! Lyrics saved to: $($File.BaseName).lrc" -ForegroundColor Green
        
        # Optional: If you want to explicitly embed the lyric file directly into the FLAC metadata 
        # using 'metaflac' or similar tool, that logic can be appended right here.
    } else {
        Write-Host "    [-] No matching lyrics found across scanned repositories." -ForegroundColor Yellow
    }
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Lyric scraping complete! Pipeline advancing." -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0