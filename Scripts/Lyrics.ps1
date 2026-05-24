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

# Verify Python accessibility
if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "[ERROR] Python could not be found globally. Please ensure Python is installed and in your system PATH." -ForegroundColor Red
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
    
    # Clean up file name to use as a fallback search query
    # Drops track numbers (e.g., "01 - Track" becomes "Track") and removes extra spaces
    $SearchQuery = $File.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    
    Write-Host "    -> Querying repositories via python -m syncedlyrics for '$SearchQuery'..." -ForegroundColor DarkGray
    
    # Define the output lyrics file path (matching the audio file location)
    $OutputFile = Join-Path -Path $File.DirectoryName -ChildPath "$($File.BaseName).lrc"
    
    # 3. Execute syncedlyrics via Python module wrapper to bypass AppData %PATH% missing linkages
    $Arguments = @(
        "-m", "syncedlyrics",
        "`"$SearchQuery`"",
        "-o", "`"$OutputFile`""
    )
    
    $Process = Start-Process -FilePath "python" -ArgumentList $Arguments -Wait -NoNewWindow -PassThru
    
    # 4. Check if a lyric file was successfully created
    if (Test-Path -Path $OutputFile) {
        Write-Host "    [+] Success! Lyrics saved to: $($File.BaseName).lrc" -ForegroundColor Green
    } else {
        # Fallback check: Sometimes syncedlyrics drops plain text files if synced timestamps aren't found
        $TxtFallback = Join-Path -Path $File.DirectoryName -ChildPath "$($File.BaseName).txt"
        if (Test-Path -Path $TxtFallback) {
             Write-Host "    [+] Success! Plain text lyrics saved to: $($File.BaseName).txt" -ForegroundColor Green
        } else {
             Write-Host "    [-] No matching lyrics found across scanned repositories." -ForegroundColor Yellow
        }
    }
    Write-Host "---------------------------------------------" -ForegroundColor DarkGray
}

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "   Lyric scraping complete! Pipeline advancing." -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0