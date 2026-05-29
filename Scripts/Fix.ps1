param (
    [string]$ConfigDir,
    [string]$HistoryPath,
    [string]$FirefoxPath
)

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Error File Repair" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# FIX: Swapped to -LiteralPath to scan the config directory safely
$ErrorLogs = Get-ChildItem -LiteralPath $ConfigDir -Filter "Playlist*_errors.txt"

if (-not $ErrorLogs) {
    Write-Host "[+] No error logs found!" -ForegroundColor Green
    Exit 0
}

$BrokenIDs = @()

foreach ($Log in $ErrorLogs) {
    Write-Host "[*] Analyzing log file: $($Log.name)" -ForegroundColor Yellow

    # FIX: Swapped to -LiteralPath to read the individual log contents
    $LogContent = Get-Content -LiteralPath $Log.Fullname

    foreach ($Line in $LogContent) {
        # Check if the line is a missing video error
        if ($Line -match "Video unavailable" -or $Line -match "This video has been removed") {
            # Use a regex to extract 11 char video ID
            if ($Line -match "\[youtube\]\s+([a-zA-Z0-9_-]{11})") {
                $ExtractedID = $Matches[1]

                # Add if new
                if ($ExtractedID -notin $BrokenIDs) {
                    $BrokenIDs += $ExtractedID
                }
            }
        }
    }
}

if ($BrokenIDs.Count -eq 0) {
    Write-Host "[+] Checked all logs. No errors found." -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Cyan
    Exit 0
}

Write-Host "`n[!] Found $($BrokenIDs.Count) unavailable video IDs!" -ForegroundColor Red

foreach ($ID in $BrokenIDs) {
    $TargetURL = "https://www.youtube.com/watch?v=$ID"
    Write-Host "[*] Opening and archiving: $TargetURL" -ForegroundColor Cyan

    # Launch Firefox to specific URL
    Start-Process -FilePath $FirefoxPath -ArgumentList "-url `"$TargetURL`""

    # FIX: Swapped to -LiteralPath to append data to the tracking history file cleanly
    "youtube $ID" | Out-File -LiteralPath $HistoryPath -Append -Encoding ascii

    # Short pause to let firefox process
    Start-Sleep -Seconds 2
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "   Error parsing complete and IDs archived!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0