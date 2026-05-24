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
    if ($Lrc.Name -like "*cookie*") { continue }

    $RelativePath = $Lrc.FullName.Substring($BackupDir.Length)
    $DestinationLrc = Join-Path -Path $MobileDir -ChildPath $RelativePath
    
    $DestFolder = Split-Path -Path $DestinationLrc
    if (-not (Test-Path -Path $DestFolder)) {
        New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null
    }
    
    if (-not (Test-Path -Path $DestinationLrc) -or ($Lrc.LastWriteTime -gt (Get-Item -Path $DestinationLrc).LastWriteTime)) {
        Copy-Item -Path $Lrc.FullName -Destination $DestinationLrc -Force
        Write-Host "[LYRIC] Copied lyric layer: $($Lrc.Name)" -ForegroundColor Gray
    }
}

# --- 4. PROCESSING CODE QUEUE ---
Write-Host "[*] Filtering out already compressed files..." -ForegroundColor Yellow

$Queue = @()
foreach ($File in $AllFiles) {
    $RelativePath = $File.FullName.SubString($BackupDir.Length)
    $DestinationFile = Join-Path -Path $MobileDir -ChildPath $RelativePath
    $DestinationFile = [System.IO.Path]::ChangeExtension($DestinationFile, ".m4a")

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

# Use a tracking array for processes instead of background Job monitors
$RunningProcesses = New-Object System.Collections.ArrayList
$CompletedCount = 0
$TotalToProcess = $Queue.Count

foreach ($Item in $Queue) {
    # Throttling Loop: Wait if we hit MaxThreads limit
    while ($RunningProcesses.Count -ge $MaxThreads) {
        Start-Sleep -Milliseconds 200

        # Check for completed processes
        for ($i = $RunningProcesses.Count - 1; $i -ge 0; $i--) {
            if ($RunningProcesses[$i].HasExited) {
                $CompletedCount++
                $Percent = [Math]::Round(($CompletedCount / $TotalToProcess) * 100)
                Write-Host "[$Percent%] Completed $CompletedCount of $TotalToProcess tracks" -ForegroundColor Gray
                
                $RunningProcesses.RemoveAt($i)
            }
        }
    }

    # Ensure target subfolders exist cleanly
    $TargetFolder = Split-Path -Path $Item.Destination -Parent
    if (-not (Test-Path -Path $TargetFolder)) {
        New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
    }

    Write-Host "[LAUNCH] $($Item.Name) -> Mobile VBR AAC" -ForegroundColor Green

    # Array style argument mapping—keeps spacing completely intact across user directories
    $FFmpegArgs = @(
        "-y",
        "-i", $Item.Source,
        "-c:a", "aac",
        "-vbr", "4",
        "-c:v", "copy",
        "-disposition:v", "attached_pic",
        "-map_metadata", "0",
        "-id3v2_version", "3",
        $Item.Destination
    )

    # Launch FFmpeg as an independent background process track node
    $Proc = Start-Process -FilePath $FFmpegPath -ArgumentList $FFmpegArgs -NoNewWindow -PassThru
    [void]$RunningProcesses.Add($Proc)
}

# --- 5. WAIT FOR FINALIZATION ---
if ($RunningProcesses.Count -gt 0) {
    Write-Host "`n[*] All conversions dispatched. Finalizing background threads..." -ForegroundColor Yellow
    while (($RunningProcesses | Where-Object { -not $_.HasExited }).Count -gt 0) {
        Start-Sleep -Milliseconds 500
    }
    Write-Host "[BAKED] Mobile library is perfectly synced and compressed!" -ForegroundColor Green
}

Write-Host "=============================================" -ForegroundColor Cyan
Exit 0