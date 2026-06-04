Param (
    [string]$BackupDir,
    [string]$MobileDir,
    [string]$FFmpegPath,
    [int]$MaxThreads = 4
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Clear-Host

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Parallel Audio Compressor" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $BackupDir)) {
    Write-Error "CRITICAL: The Source Directory '$BackupDir' does not exist!"
    Exit 1
}

if (-not (Test-Path -LiteralPath $MobileDir)) {
    New-Item -ItemType Directory -LiteralPath $MobileDir -Force | Out-Null
}

Write-Host "[*] Purging leftover artwork files..." -ForegroundColor Yellow
Get-ChildItem -LiteralPath $BackupDir -Recurse -File | 
    Where-Object { $_.Extension -match '\.(webp|jpg|jpeg|png)$' } | 
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Host "[*] Scanning source directory for master audio tracks..." -ForegroundColor Cyan
$AllFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|ogg)$' }

if ($AllFiles.Count -eq 0) {
    Write-Host "[+] No source audio tracks found to process!" -ForegroundColor Green
    $MetricStopwatch.Stop()
    Write-Host "[METRIC] 00:00:00"
    Exit 0
}

Write-Host "[*] Syncing timed lyric (.lrc) files..." -ForegroundColor Cyan
Get-ChildItem -LiteralPath $BackupDir -Filter *.lrc -Recurse -File | ForEach-Object {
    if ($_.Name -notlike "*cookie*") {
        $RelativePath = $_.FullName.Substring($BackupDir.Length)
        $DestinationLrc = "$MobileDir$RelativePath"
        $DestFolder = [System.IO.Path]::GetDirectoryName($DestinationLrc)
        if (-not (Test-Path -LiteralPath $DestFolder)) { New-Item -ItemType Directory -LiteralPath $DestFolder -Force | Out-Null }
        if (-not (Test-Path -LiteralPath $DestinationLrc) -or ($_.LastWriteTime -gt (Get-Item -LiteralPath $DestinationLrc).LastWriteTime)) {
            Copy-Item -LiteralPath $_.FullName -Destination $DestinationLrc -Force
        }
    }
}

Write-Host "[*] Filtering out already compressed files..." -ForegroundColor Yellow
$Queue = @()
foreach ($File in $AllFiles) {
    $RelativePath = $File.FullName.SubString($BackupDir.Length)
    $DestinationFile = [System.IO.Path]::ChangeExtension("$MobileDir$RelativePath", ".m4a")

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
    Write-Host "[METRIC] $("{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed)"
    Exit 0
}

Write-Host "[+] Filtering complete! $($Queue.Count) tracks require compression." -ForegroundColor Green
Write-Host "[+] Spawning parallel ffmpeg processing threads (Max Workers: $MaxThreads)`n" -ForegroundColor Yellow

# Optimization: Modern Parallel Multi-threaded Core Architecture
$Queue | ForEach-Object -Parallel {
    $TargetFolder = [System.IO.Path]::GetDirectoryName($_.Destination)
    if (-not (Test-Path -LiteralPath $TargetFolder)) { New-Item -ItemType Directory -LiteralPath $TargetFolder -Force | Out-Null }

    Write-Host "[LAUNCH] $($_.Name) -> Mobile M4A" -ForegroundColor Green

    $FFmpegArgs = @(
        "-y", "-loglevel", "quiet",
        "-i", $_.Source,
        "-c:a", "aac", "-vbr", "4",
        "-c:v", "copy", "-disposition:v", "attached_pic",
        "-map_metadata", "0", "-id3v2_version", "3",
        $_.Destination
    )

    $Proc = Start-Process -FilePath $using:FFmpegPath -ArgumentList $FFmpegArgs -NoNewWindow -PassThru -Wait
} -ThrottleLimit $MaxThreads

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Write-Host "[BAKED] Mobile library is perfectly synced and compressed!" -ForegroundColor Green
Write-Host "[METRIC] $Elapsed"
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0