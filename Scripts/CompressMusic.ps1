Param (
    [string]$BackupDir,
    [string]$MobileDir,
    [string]$FFmpegPath,
    [int]$MaxThreads = 3
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Parallel Audio Compressor" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $BackupDir)) {
    Write-Error "CRITICAL: The Source Directory '$BackupDir' does not exist! Check your folder spelling."
    Exit 1
}

if (-not (Test-Path -LiteralPath $MobileDir)) {
    New-Item -ItemType Directory -LiteralPath $MobileDir -Force | Out-Null
}

Write-Host "[*] Purging leftover thumbnail artwork files (.webp / .jpg)..." -ForegroundColor Yellow
Get-ChildItem -LiteralPath $BackupDir -Recurse -File |
Where-Object { $_.Extension -match '\.(webp|jpg|jpeg|png)$' } | 
    ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
            Write-Host "[-] Vaporized: $($_.Name)" -ForegroundColor DarkGray
        } catch {}
    }

Write-Host "[*] Scanning source directory for master audio tracks..." -ForegroundColor Cyan
$AllFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|ogg)$' }

if ($AllFiles.Count -eq 0) {
    Write-Host "[+] No source audio tracks found to process!" -ForegroundColor Green
    $MetricStopwatch.Stop()
    Write-Host "[METRIC] 00:00:00"
    Exit 0
}

Write-Host "[*] Found $($AllFiles.Count) total source files. Checking for updates..." -ForegroundColor Cyan

Write-Host "[*] Syncing timed lyric (.lrc) files..." -ForegroundColor Cyan
$LrcFiles = Get-ChildItem -LiteralPath $BackupDir -Filter *.lrc -Recurse -File

foreach ($Lrc in $LrcFiles) {
    if ($Lrc.Name -like "*cookie*") { continue }
    $RelativePath = $Lrc.FullName.Substring($BackupDir.Length)
    $DestinationLrc = "$MobileDir$RelativePath"
    $DestFolder = [System.IO.Path]::GetDirectoryName($DestinationLrc)
    if (-not (Test-Path -LiteralPath $DestFolder)) {
        New-Item -ItemType Directory -LiteralPath $DestFolder -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $DestinationLrc) -or ($Lrc.LastWriteTime -gt (Get-Item -LiteralPath $DestinationLrc).LastWriteTime)) {
        Copy-Item -LiteralPath $Lrc.FullName -Destination $DestinationLrc -Force
        Write-Host "[LYRIC] Copied lyric layer: $($Lrc.Name)" -ForegroundColor Gray
    }
}

Write-Host "[*] Filtering out already compressed files..." -ForegroundColor Yellow
$Queue = @()
foreach ($File in $AllFiles) {
    $RelativePath = $File.FullName.SubString($BackupDir.Length)
    $DestinationFile = "$MobileDir$RelativePath"
    $DestinationFile = [System.IO.Path]::ChangeExtension($DestinationFile, ".m4a")

    if (-not (Test-Path -LiteralPath $DestinationFile) -or ($File.LastWriteTime -gt (Get-Item -LiteralPath $DestinationFile).LastWriteTime)) {
        $Queue += [PSCustomObject]@{
            Source      = $File.FullName
            Destination = $DestinationFile
            Name        = $File.Name
        }
    }
}

if ($Queue.Count -eq 0) {
    Write-Host "[+] Mobile folder completely up to date. 0 tracks queued." -ForegroundColor Green
    $MetricStopwatch.Stop()
    $Elapsed = [string]::Format("{0:hh\:mm\:ss}", $MetricStopwatch.Elapsed)
    Write-Host "[METRIC] $Elapsed"
    Write-Host "=============================================" -ForegroundColor Cyan
    Exit 0
}

Write-Host "[+] Filtering complete! $($Queue.Count) tracks require compression." -ForegroundColor Green
Write-Host "[+] Spawning parallel ffmpeg processing threads (Max Workers: $MaxThreads)`n" -ForegroundColor Yellow

$RunningProcesses = New-Object System.Collections.ArrayList
$CompletedCount = 0
$TotalToProcess = $Queue.Count

foreach ($Item in $Queue) {
    while ($RunningProcesses.Count -ge $MaxThreads) {
        Start-Sleep -Milliseconds 200
        for ($i = $RunningProcesses.Count - 1; $i -ge 0; $i--) {
             if ($RunningProcesses[$i].HasExited) {
                $CompletedCount++
                $Percent = [Math]::Round(($CompletedCount / $TotalToProcess) * 100)
                Write-Host "[$Percent%] Completed $CompletedCount of $TotalToProcess tracks" -ForegroundColor Gray
                $RunningProcesses.RemoveAt($i)
            }
        }
    }

    $TargetFolder = [System.IO.Path]::GetDirectoryName($Item.Destination)
    if (-not (Test-Path -LiteralPath $TargetFolder)) {
        New-Item -ItemType Directory -LiteralPath $TargetFolder -Force | Out-Null
    }

    Write-Host "[LAUNCH] $($Item.Name) -> Mobile VBR AAC" -ForegroundColor Green

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

    $Proc = Start-Process -FilePath $FFmpegPath -ArgumentList $FFmpegArgs -NoNewWindow -PassThru
    [void]$RunningProcesses.Add($Proc)
}

if ($RunningProcesses.Count -gt 0) {
    Write-Host "`n[*] All conversions dispatched. Finalizing background threads..." -ForegroundColor Yellow
    while (($RunningProcesses | Where-Object { -not $_.HasExited }).Count -gt 0) {
        Start-Sleep -Milliseconds 500
    }
    Write-Host "[BAKED] Mobile library is perfectly synced and compressed!" -ForegroundColor Green
}

$MetricStopwatch.Stop()
$Elapsed = [string]::Format("{0:hh\:mm\:ss}", $MetricStopwatch.Elapsed)
Write-Host "[METRIC] $Elapsed"
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0