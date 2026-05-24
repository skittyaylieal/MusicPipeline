param (
    [string]$BackupDir,
    [string]$FoobarPath
)

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Lyric Grabber & Embedder" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Verify foobar executable's existence
if (-not (Test-Path -Path $FoobarPath -PathType Leaf)) {
    Write-Host "[ERROR] foobar2000 executable could not be found" -ForegroundColor Red
    Write-Host "Checked Path: $FoobarPath" -ForegroundColor Yellow
    Exit 1
}

Write-Host "[*] Purging old foobar2000 active queues and loading fresh files..." -ForegroundColor Yellow
Write-Host "Target Directory: $BackupDir" -ForegroundColor DarkGray

# Clean active view memory and map files immediately to prevent 300k song bloat
& "C:\Program Files\foobar2000\foobar2000.exe" /command:Clear /add "$BackupDir"
Start-Sleep -Seconds 5 # Tiny breather for foobar to register the folder mapping
# TEMP DEBUG PAUSE: Stops the script here so you can look at Foobar and the terminal!
Read-Host "DEBUG: Foobar has launched. Press Enter to allow the script to continue..."
Write-Host "[*] Triggering automated Lyric Show Panel 3 query" -ForegroundColor Cyan

# Fixed command typo (/runcmd) and passed /exit inside arguments to force-close Foobar when finished
Start-Process -FilePath $FoobarPath -ArgumentList "/runcmd=`"Lyric Show Panel 3/Search for lyrics`"", "/exit"

Write-Host "[*] Monitoring scraper progress. Waiting for database completion" -ForegroundColor Yellow
Write-Host "Do not close this window. The script will automatically advance when done." -ForegroundColor DarkGray

# Loop until foobar2000 can't be found running
while (Get-Process -Name "foobar2000" -ErrorAction SilentlyContinue) {
    # Check every 5 seconds for performance
    Start-Sleep -Seconds 5
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "   foobar2000 closed. Lyric embedding complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0