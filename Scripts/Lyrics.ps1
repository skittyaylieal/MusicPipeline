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

# 1. Clean active view memory and map files immediately via global executable call
& $FoobarPath /command:Clear /add "$BackupDir"
Start-Sleep -Seconds 3 # Tiny breather for foobar to register the folder mapping

Write-Host "[*] Triggering automated Lyric Show Panel 3 query via foo_runcmd..." -ForegroundColor Cyan

# 2. FIXED: Store the switch as a single literal string argument so foobar can parse it without errors
$RunCmdArg = '/runcmd-playlist="Lyric Show Panel 3/Search for lyrics"'
& $FoobarPath $RunCmdArg

Write-Host "[*] Monitoring sandbox folder activity. Script will advance when tags stabilize..." -ForegroundColor Yellow
Write-Host "Timeout Threshold: 10 minutes (600 seconds) of total file system idling." -ForegroundColor DarkGray

# --- DYNAMIC SYSTEM MONITORING LOOP ---
$IsProcessing = $true
$LastChangeTime = [DateTime]::Now
$LoopIntervalSec = 5
$MaxIdleSeconds = 600 # 10 Minutes absolute cap

while ($IsProcessing) {
    Start-Sleep -Seconds $LoopIntervalSec
    
    # Check if Foobar was closed manually by a user (emergency breakout)
    if (-not (Get-Process -Name "foobar2000" -ErrorAction SilentlyContinue)) {
        Write-Host "[-] foobar2000 process terminated externally. Breaking monitor loop." -ForegroundColor DarkYellow
        $IsProcessing = $false
        break
    }

    # Fetch the latest write times for target audio tracks and metadata text/lrc extensions
    $CurrentFiles = Get-ChildItem -Path $BackupDir -Recurse | Where-Object { $_.Extension -match "flac|txt|lrc" }
    
    if ($CurrentFiles) {
        $LatestFileChange = ($CurrentFiles | Measure-Object -Property LastWriteTime -Maximum).Maximum
        
        # Check if the lyric tagger touched files during this processing block
        if ($LatestFileChange -gt $LastChangeTime) {
            Write-Host "[*] Scraper active: Updating file tags..." -ForegroundColor Cyan
            $LastChangeTime = $LatestFileChange
        } else {
            # Calculate current total inactivity duration
            $TimeIdle = ([DateTime]::Now - $LastChangeTime).TotalSeconds
            
            if ($TimeIdle -ge $MaxIdleSeconds) {
                Write-Host "[+] Target directory stabilized. 10 minutes of idling reached!" -ForegroundColor Green
                $IsProcessing = $false
            } else {
                # Format a clean countdown tracking indicator
                $Remaining = [Math]::Round($MaxIdleSeconds - $TimeIdle)
                Write-Host "[*] Idling... ($Remaining seconds remaining until automatic cutoff)" -ForegroundColor DarkGray
            }
        }
    } else {
        Write-Warning "[-] Sandbox folder empty. Waiting for file initialization..."
    }
}

# 3. Cleanly kill the background process now that the database tasks have finished writing
Write-Host "[*] Finalizing step and closing foobar2000 cleanly..." -ForegroundColor Cyan
Stop-Process -Name "foobar2000" -Force -ErrorAction SilentlyContinue

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "   foobar2000 closed. Lyric embedding complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0