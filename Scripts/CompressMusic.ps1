param (
    [string]$BackupDir,
    [string]$MobileDir,
    [string]$FFmpegPath,
    [int]$MaxThreads = 3  # Keeps 1 core free on the N100 for OS/IO stability
)

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Parallel Audio Compressor" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# PATH SAFETY CHECK
if (-not (Test-Path -Path $BackupDir)) {
    Write-Error "CRITICAL: The Source Directory '$BackupDir' does not exist! Check your folder spelling."
    Exit 1
}

# Make sure there's a target directory
if (-not (Test-Path -Path $MobileDir)) {
    New-Item -ItemType Directory -Path $MobileDir -Force | Out-Null
}

# --- 1. STRAY IMAGE CLEANUP ENGINE ---
Write-Host "[*] Purging leftover thumbnail artwork files (.webp / .jpg)..." -ForegroundColor Yellow
Get-ChildItem -LiteralPath $BackupDir -Recurse -File | 
    Where-Object { $_.Extension -match '\.(webp|jpg|jpeg|png)$' } | 
    ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
            Write-Host "[-] Vaporized: $($_.Name)" -ForegroundColor DarkGray
        } catch {
            # File is locked by yt-dlp/tagger; will skip and catch on next run
        }
    }

# --- 2. AUDIO SCANNING ---
Write-Host "[*] Scanning source directory for master audio tracks..." -ForegroundColor Cyan
# Scans multi-format tracks to align perfectly with your archive rules
$AllFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | 
            Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|ogg)$' }

if ($AllFiles.Count -eq 0) {
    Write-Host "[+] No source audio tracks found to process!" -ForegroundColor Green
    Exit 0
}

Write-Host "[*] Found $($AllFiles.Count) total source files. Checking for updates..." -ForegroundColor Cyan

# --- 3. LYRIC MIRROR ENGINE (WITH COOKIE SHIELD) ---
Write-Host "[*] Syncing timed lyric (.lrc) files..." -ForegroundColor Cyan
$LrcFiles = Get-ChildItem -LiteralPath $BackupDir -Filter *.lrc -Recurse -File

foreach ($Lrc in $LrcFiles) {
    # COOKIE SHIELD: If the file is secretly a cookie artifact, ignore it entirely!
    if ($Lrc.Name -like "*cookie*") { continue }

    $RelativePath = $Lrc.FullName.Substring($BackupDir.Length)
    $DestinationLrc = Join-Path -Path $MobileDir -ChildPath $RelativePath
    
    $DestFolder = Split-Path -Path $DestinationLrc
    if (-not (Test-Path -Path $DestFolder)) {
        New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null
    }
    
    # Only copy if missing or updated
    if (-not (Test-Path -Path $DestinationLrc) -or ($Lrc.LastWriteTime -gt (Get-Item -Path $DestinationLrc).LastWriteTime)) {
        Copy-Item -Path $Lrc.FullName -Destination $DestinationLrc -Force
        Write-Host "[LYRIC] Copied lyric layer: $($Lrc.Name)" -ForegroundColor Gray
    }
}

# --- 4. PROCESSING CODE QUEUE ---
Write-Host "[*] Filtering out already compressed files..." -ForegroundColor Yellow

# Create array of tracks that need processing
$Queue = @()

foreach ($File in $AllFiles) {
    # Build destination path for compressed file and force extension mapping to .m4a
    $RelativePath = $File.FullName.SubString($BackupDir.Length)
    $DestinationFile = Join-Path -Path $MobileDir -ChildPath $RelativePath
    $DestinationFile = [System.IO.Path]::ChangeExtension($DestinationFile, ".m4a")

    # If target file doesn't exist OR the master copy is newer, queue it up!
    if (-not (Test-Path -Path $DestinationFile) -or ($File.LastWriteTime -gt (Get-Item -Path $DestinationFile).LastWriteTime)) {
        $Queue += [PSCustomObject]@{
            Source      = $File.FullName
            Destination = $DestinationFile
            Name        = $File.Name
        }
    }
}

if ($Queue.Count -eq 0) {
    Write-Host "[+] Mobile folder completely up to date. 0 tracks queued." -ForegroundColor Green
    Write-Host "=============================================" -ForegroundColor Cyan
    Exit 0
}

Write-Host "[+] Filtering complete! $($Queue.Count) tracks require compression." -ForegroundColor Green
Write-Host "[+] Spawning parallel ffmpeg processing threads (Max Workers: $MaxThreads)`n" -ForegroundColor Yellow

# Use ArrayList to easily scale out and drop tracking nodes on the fly
$RunningJobs = New-Object System.Collections.ArrayList
$CompletedCount = 0
$TotalToProcess = $Queue.Count

foreach ($Item in $Queue) {
    # If running at max capacity, wait for a thread to finish
    while (($RunningJobs | Where-Object { $_.State -eq 'Running' }).Count -ge $MaxThreads) {
        Start-Sleep -Milliseconds 200

        # Clean up completed jobs and update progress counter
        $Finished = $RunningJobs | Where-Object { $_.State -ne 'Running' }
        foreach ($Job in $Finished) {
            $CompletedCount++
            $Percent = [Math]::Round(($CompletedCount / $TotalToProcess) * 100)
            Write-Host "[$Percent%] Completed $CompletedCount of $TotalToProcess tracks" -ForegroundColor Gray
            Remove-Job -Job $Job
            [void]$RunningJobs.Remove($Job)
        }
    }

    # Ensure target subfolders exist cleanly
    $TargetFolder = Split-Path -Path $Item.Destination -Parent
    if (-not (Test-Path -Path $TargetFolder)) {
        New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
    }

    # Display the file currently being dispatched
    Write-Host "[LAUNCH] $($Item.Name) -> Mobile VBR AAC" -ForegroundColor Green

    # ScriptBlock mapping your accurate artwork and tag conservation rules
    $ScriptBlock = {
        param($FFmpeg, $Source, $Target)
        & $FFmpeg -y -i $Source -c:a aac -vbr 4 -c:v copy -disposition:v attached_pic -map_metadata 0 -id3v2_version 3 $Target 2>$null
    }

    # Spawn the background script thread worker
    $Job = Start-Job -ScriptBlock $ScriptBlock -ArgumentList $FFmpegPath, $Item.Source, $Item.Destination
    [void]$RunningJobs.Add($Job)
}

# --- 5. WAIT FOR COMPLETION ---
if ($RunningJobs.Count -gt 0) {
    Write-Host "`n[*] All conversions dispatched. Finalizing background threads..." -ForegroundColor Yellow
    while (($RunningJobs | Where-Object { $_.State -eq 'Running' }).Count -gt 0) {
        Start-Sleep -Milliseconds 500
    }
    Get-Job | Remove-Job
    Write-Host "[BAKED] Mobile library is perfectly synced and compressed!" -ForegroundColor Green
}

Write-Host "=============================================" -ForegroundColor Cyan
Exit 0