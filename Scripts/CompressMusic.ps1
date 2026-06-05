Param (
    [string]$BackupDir,
    [string]$MobileDir,
    [string]$FFmpegPath,
    [int]$MaxThreads = 4
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Clear-Host

Write-Output "============================================="
Write-Output "    PowerShell Module: Parallel Audio Compressor"
Write-Output "============================================="

if (-not (Test-Path -LiteralPath $BackupDir)) {
    Write-Error "CRITICAL: The Source Directory '$BackupDir' does not exist!"
    Exit 1
}

if (-not (Test-Path -LiteralPath $MobileDir)) {
    New-Item -ItemType Directory -LiteralPath $MobileDir -Force | Out-Null
}

Write-Output "[*] Purging leftover artwork files..."
Get-ChildItem -LiteralPath $BackupDir -Recurse -File | 
    Where-Object { $_.Extension -match '\.(webp|jpg|jpeg|png)$' } | 
    Remove-Item -Force -ErrorAction SilentlyContinue

Write-Output "[*] Scanning source directory for master audio tracks..."
$AllFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | Where-Object { $_.Extension -match '\.(mp3|flac|wav|m4a|ogg)$' }

if ($AllFiles.Count -eq 0) {
    Write-Output "[+] No source audio tracks found to process!"
    $MetricStopwatch.Stop()
    Write-Output "[METRIC] 00:00:00"
    Exit 0
}

Write-Output "[*] Syncing timed lyric (.lrc) files..."
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

Write-Output "[*] Filtering out already compressed files..."
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
    Write-Output "[+] Mobile folder completely up to date. 0 tracks queued."
    $MetricStopwatch.Stop()
    Write-Output "[METRIC] $("{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed)"
    Exit 0
}

Write-Output "[+] Filtering complete! $($Queue.Count) tracks require compression."
Write-Output "[+] Spawning parallel ffmpeg processing threads (Max Workers: $MaxThreads)`n"

# Optimization: Modern Parallel Multi-threaded Core Architecture
$Queue | ForEach-Object -Parallel {
    $TargetFolder = [System.IO.Path]::GetDirectoryName($_.Destination)
    if (-not (Test-Path -LiteralPath $TargetFolder)) { New-Item -ItemType Directory -LiteralPath $TargetFolder -Force | Out-Null }

    Write-Output "[LAUNCH] $($_.Name) -> Mobile M4A"

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
Write-Output "[BAKED] Mobile library is perfectly synced and compressed!"
Write-Output "[METRIC] $Elapsed"
Write-Output "============================================="
Exit 0