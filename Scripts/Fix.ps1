Param (
    [string]$ConfigDir,
    [string]$HistoryPath
)

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Interactive Link Auditor" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Find all error log files
$ErrorLogs = Get-ChildItem -LiteralPath $ConfigDir -Filter "playlist*_errors.txt"

if ($ErrorLogs.Count -eq 0) {
    Write-Host "[+] No playlist error logs found to audit!" -ForegroundColor Green
    Exit 0
}

# Regex to extract YouTube Video IDs from yt-dlp error output
$VideoIdRegex = 'ERROR:\s*\[youtube\]\s*([a-zA-Z0-9_-]{11}):'
$BrokenIDs = @()

foreach ($Log in $ErrorLogs) {
    $Content = Get-Content -LiteralPath $Log.FullName
    foreach ($Line in $Content) {
        if ($Line -match $VideoIdRegex) {
            $Id = $Matches[1]
            if ($BrokenIDs -notcontains $Id) {
                $BrokenIDs += $Id
            }
        }
    }
}

if ($BrokenIDs.Count -eq 0) {
    Write-Host "[+] Scan complete. No structural YouTube Video ID errors found!" -ForegroundColor Green
    Exit 0
}

Write-Host "[+] Found $($BrokenIDs.Count) unique broken tracks to audit." -ForegroundColor Yellow
Write-Host "[*] Assembling your local interactive HTML audit deck..." -ForegroundColor Cyan

# Convert the array of IDs into a JSON string for JavaScript execution inside the HTML
$JsonIDs = ($BrokenIDs | ForEach-Object { "'$_'" }) -join ','

# Define the HTML template paths
$HtmlPath = "$env:USERPROFILE\Desktop\music_audit.html"

$HtmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Music Link Auditor</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #121212; color: #E0E0E0; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background: #1E1E1E; padding: 30px; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); text-align: center; max-width: 500px; width: 100%; border: 1px solid #333; }
        h2 { color: #00ADB5; margin-top: 0; }
        .counter { font-size: 0.9em; color: #888; margin-bottom: 20px; }
        .id-display { background: #2D2D2D; padding: 10px; border-radius: 6px; font-family: monospace; font-size: 1.2em; letter-spacing: 1px; color: #FFD369; margin-bottom: 25px; }
        .btn { display: block; width: 100%; padding: 12px; margin: 10px 0; border: none; border-radius: 6px; font-size: 1em; font-weight: bold; cursor: pointer; transition: background 0.2s; }
        .btn-launch { background: #00ADB5; color: #EEE; }
        .btn-launch:hover { background: #008C9E; }
        .btn-fixed { background: #4E9F3D; color: #EEE; }
        .btn-fixed:hover { background: #3E8E2D; }
        .btn-ok { background: #393E46; color: #EEE; }
        .btn-ok:hover { background: #222831; }
        .btn-skip { background: #D63447; color: #EEE; }
        .btn-skip:hover { background: #B32437; }
        textarea { width: 100%; height: 120px; background: #2D2D2D; color: #00FF