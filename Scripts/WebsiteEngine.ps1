Param (
    [string]$BackupDir = "C:\Users\filip\Music\YT_Music_Backup",
    [string]$MobileDir = "C:\Users\filip\Music\YT_Music_Mobile",
    [string]$BatchScript = "C:\MusicTools\MusicPipeline\sync_music.bat"
)

# Global variables and runtime states
$Global:IsPipelineRunning = $false
$Global:DiagLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"
$Global:CacheFile = "C:\MusicTools\MusicPipeline\Config\dashboard_cache.json"
$ScriptRepoDir = [System.IO.Path]::GetDirectoryName($BatchScript)

# Create config directory if it doesn't exist
$ConfigDir = Split-Path $Global:DiagLogFile
if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force }

# Shared Default Memory Container
$Global:CachedMetrics = @{
    masterCount = 0; mobileCount = 0; lrcCount = 0
    masterSize  = 0; mobileSize  = 0; alerts = @(); tracks = @()
}

# -----------------------------------------------------------------
# 1. ROBUST BACKGROUND SCANNER (Asynchronous Processing Layout)
# -----------------------------------------------------------------
function Start-AsyncLibraryScanner {
    Get-Job -Name "MusicFolderScanner" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

    $JobScript = {
        param($BDir, $MDir, $RDir, $CFile)
        
        Start-Sleep -Seconds 2
        while ($true) {
            if (-not (Test-Path -LiteralPath $BDir)) { Start-Sleep -Seconds 5; continue }

            $MasterFiles = Get-ChildItem -LiteralPath $BDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }
            $MobileFiles = Get-ChildItem -LiteralPath $MDir -Recurse -File | Where-Object { $_.Extension -match "m4a" }
            $LrcFiles    = Get-ChildItem -LiteralPath $BDir -Recurse -Filter "*.lrc" -File

            $MasterSize = ($MasterFiles | Measure-Object -Property Length -Sum).Sum / 1GB
            $MobileSize = ($MobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB

            $Alerts = @()
            if (Test-Path -LiteralPath "$RDir\.git") {
                try {
                    $Env:GIT_TERMINAL_PROMPT = "0"
                    $Env:GIT_SSH_COMMAND = ""
                    Push-Location $RDir
                    [void](git -c network.timeout=3 fetch origin main 2>&1)
                    if ((git rev-parse HEAD).Trim() -ne (git rev-parse "@{upstream}").Trim()) {
                        $Alerts += @{ type = "warning"; message = "Repository Update Available: Changes pushed from Mac are ready."; fixAction = "gitpull" }
                    }
                    Pop-Location
                } catch {}
            }

            if ($MasterFiles.Count -gt $MobileFiles.Count) {
                $Alerts += @{ type = "danger"; message = "Synchronization Gap: Master backup has $(($MasterFiles.Count - $MobileFiles.Count)) more track(s) than Mobile."; fixAction = "sync" }
            }

            # Build metadata lookup array layout
            $TrackDatabase = @()
            foreach ($File in $MasterFiles) {
                if ($null -eq $File.FullName) { continue }
                $RelativePath = $File.FullName.Substring($BDir.Length).TrimStart('\')
                $PathParts = $RelativePath -split '\\'
                $Artist = if ($PathParts.Count -ge 3) { $PathParts[0] } else { "Unknown Artist" }
                $Album  = if ($PathParts.Count -ge 3) { $PathParts[1] } else { "Single / Unknown" }
                
                $TrackDatabase += @{
                    title  = [string]$File.BaseName
                    artist = [string]$Artist
                    album  = [string]$Album
                    sizeMb = [Math]::Round(($File.Length / 1MB), 2)
                    hasLrc = [bool](Test-Path -LiteralPath "$($File.DirectoryName)\$($File.BaseName).lrc" -ErrorAction SilentlyContinue)
                    type   = [string]$File.Extension.ToUpper().Replace('.','')
                }
            }

            @{
                masterCount = $MasterFiles.Count
                mobileCount = $MobileFiles.Count
                lrcCount    = $LrcFiles.Count
                masterSize  = [Math]::Round($MasterSize, 2)
                mobileSize  = [Math]::Round($MobileSize, 2)
                alerts      = $Alerts
                tracks      = $TrackDatabase
            } | ConvertTo-Json -Depth 4 | Out-File -FilePath $CFile -Encoding utf8 -Force

            Start-Sleep -Seconds 60
        }
    }

    Start-Job -Name "MusicFolderScanner" -ScriptBlock $JobScript -ArgumentList $BackupDir, $MobileDir, $ScriptRepoDir, $Global:CacheFile
}

# -----------------------------------------------------------------
# 2. PROCESS MANAGEMENT WORKERS
# -----------------------------------------------------------------
function Invoke-PipelineExecution {
    if ($Global:IsPipelineRunning) { return }
    $Global:IsPipelineRunning = $true
    
    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
    "[SYSTEM] Dispatching background process worker..." | Out-File -FilePath $Global:DiagLogFile -Encoding utf8

    $PipelineJob = {
        param($ScriptPath, $RepoDir, $OutputFile)
        Set-Location -LiteralPath $RepoDir
        & "$env:SystemRoot\System32\cmd.exe" /c "`"$ScriptPath`" headless" > $OutputFile 2>&1
    }
    
    $Job = Start-Job -ScriptBlock $PipelineJob -ArgumentList $BatchScript, $ScriptRepoDir, $Global:DiagLogFile
}

function Invoke-HotReload {
    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
    "[SYSTEM] Hot-reload triggered. Executing Git Pull..." | Out-File -FilePath $Global:DiagLogFile -Encoding utf8
    Push-Location $ScriptRepoDir
    try {
        $Env:GIT_TERMINAL_PROMPT = "0"
        $Env:GIT_SSH_COMMAND = ""
        & "git" pull origin main >> $Global:DiagLogFile 2>&1
    } catch {}
    Pop-Location
}

# HTML Dashboard Asset - Fixed Polling Setup
$HtmlDashboard = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Music Pipeline Master Console</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #0F0F11; color: #E2E8F0; margin: 0; padding: 25px; }
        .alert-container { margin-bottom: 20px; }
        .alert { padding: 15px 20px; border-radius: 6px; margin-bottom: 10px; font-size: 0.95em; display: flex; justify-content: space-between; align-items: center; font-weight: 500; }
        .alert-danger { background: #4C1D1D; color: #F87171; border: 1px solid #7F1D1D; }
        .alert-warning { background: #453015; color: #FBBF24; border: 1px solid #78350F; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-bottom: 25px; }
        .card { background: #18181C; padding: 20px; border-radius: 10px; border: 1px solid #27272A; text-align: center; }
        .card h3 { margin: 0; color: #A1A1AA; font-size: 0.9em; text-transform: uppercase; letter
