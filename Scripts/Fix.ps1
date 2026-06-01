Param (
    [string]$ConfigDir,
    [string]$HistoryPath,
    [string]$FirefoxPath
)

# Push old terminal content out of view
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Headless Link Auditor" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Define tracking file paths
$QueueFile = "$ConfigDir\audit_queue.json"
$HtmlPath  = "$ConfigDir\music_audit.html"
$ShortcutPath = "$env:USERPROFILE\Desktop\Review Broken Music.url"

# Detect if running in Session 0 (Headless / Task Scheduler background)
$IsHeadless = (Get-Process -Id $PID).SessionId -eq 0

# -----------------------------------------------------------------
# MODE A: UNATTENDED LOG EXTRACTION (Task Scheduler / Session 0)
# -----------------------------------------------------------------
if ($IsHeadless) {
    Write-Host "[*] Headless execution environment verified. Scanning logs..." -ForegroundColor Yellow
    
    $ErrorLogs = Get-ChildItem -LiteralPath $ConfigDir -Filter "playlist*_errors.txt"
    if (-not $ErrorLogs) { Exit 0 }

    # Load existing queue items so we don't drop items unresolved from previous runs
    $Queue = @()
    if (Test-Path -LiteralPath $QueueFile) {
        try { $Queue = Get-Content -LiteralPath $QueueFile -Raw | ConvertFrom-Json } catch { $Queue = @() }
    }

    $VideoIdRegex = 'ERROR:\s*\[youtube\]\s*([a-zA-Z0-9_-]{11}):'

    foreach ($Log in $ErrorLogs) {
        if ((Get-Item -LiteralPath $Log.FullName).Length -eq 0) { continue }
        $Content = Get-Content -LiteralPath $Log.FullName
        foreach ($Line in $Content) {
            if ($Line -match $VideoIdRegex) {
                $Id = $Matches[1]
                
                # Check if this specific video ID is already tracked in our structured queue object array
                $AlreadyExists = $false
                foreach ($Item in $Queue) {
                    if ($Item.id -eq $Id) { $AlreadyExists = $true; break }
                }

                if (-not $AlreadyExists) {
                    # Save both the raw ID and the clean text string of the line error context
                    $Queue += [PSCustomObject]@{
                        id    = $Id
                        error = $Line.Trim()
                    }
                }
            }
        }
    }

    # If nothing is broken, clean up old notifications and stop
    if ($Queue.Count -eq 0) {
        if (Test-Path -LiteralPath $ShortcutPath) { Remove-Item -LiteralPath $ShortcutPath -Force }
        Exit 0
    }

    # Save tracking data arrays natively as robust structural JSON elements
    $Queue | ConvertTo-Json | Out-File -LiteralPath $QueueFile -Encoding utf8

    # Create a Desktop shortcut notification wrapper pointing to our interface engine
    $TargetCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -Command `"& '$PSCommandPath' -ConfigDir '$ConfigDir' -HistoryPath '$HistoryPath' -FirefoxPath '$FirefoxPath'`""
    $ShortcutContent = @"
[InternetShortcut]
URL=$HtmlPath
IconIndex=0
IconFile=$FirefoxPath
"@
    $ShortcutContent | Out-File -LiteralPath $ShortcutPath -Encoding ascii
    
    Write-Host "[+] Background extraction complete. Queue saved with $($Queue.Count) links." -ForegroundColor Green
    
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host "    Headless link extraction cycle complete!" -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Cyan
    Exit 0
}

# -----------------------------------------------------------------
# MODE B: INTERACTIVE REVIEW PLATFORM (When run manually by you)
# -----------------------------------------------------------------
Write-Host "[*] Interactive console detected. Launching local API engine..." -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $QueueFile)) {
    Write-Host "[+] No audit data found. Queue file is missing." -ForegroundColor Green
    Exit 0
}

$Queue = Get-Content -LiteralPath $QueueFile -Raw | ConvertFrom-Json
if ($Queue.Count -eq 0) {
    Write-Host "[+] Audit queue is completely empty!" -ForegroundColor Green
    if (Test-Path -LiteralPath $ShortcutPath) { Remove-Item -LiteralPath $ShortcutPath -Force }
    Exit 0
}

# Convert objects safely to a compiled JavaScript JSON structure data block
$JsonQueueData = $Queue | ConvertTo-Json -Compress

# Generate the interactive HTML asset file inside the Config directory dynamically
$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Music Link Auditor</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #121212; color: #E0E0E0; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background: #1E1E1E; padding: 30px; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); text-align: center; max-width: 500px; width: 100%; border: 1px solid #333; }
        h2 { color: #00ADB5; margin-top: 0; }
        .counter { font-size: 0.9em; color: #888; margin-bottom: 20px; }
        .id-box { background: #2D2D2D; padding: 12px; border-radius: 6px; font-family: monospace; font-size: 1.2em; color: #FFD369; margin-bottom: 15px; word-break: break-all; }
        .error-log { background: #251B1B; border: 1px solid #5C2D2D; color: #FF6B6B; padding: 12px; border-radius: 6px; font-family: monospace; font-size: 0.85em; text-align: left; margin-bottom: 25px; word-break: break-word; max-height: 100px; overflow-y: auto; }
        .btn { display: block; width: 100%; padding: 12px; margin: 10px 0; border: none; border-radius: 6px; font-size: 1em; font-weight: bold; cursor: pointer; transition: opacity 0.2s; }
        .btn:hover { opacity: 0.9; }
        .btn-launch { background: #00ADB5; color: #FFF; }
        .btn-fixed { background: #4