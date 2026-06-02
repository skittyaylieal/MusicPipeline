Param (
    [string]$BackupDir = "C:\Users\filip\Music\YT_Music_Backup",
    [string]$MobileDir = "C:\Users\filip\Music\YT_Music_Mobile",
    [string]$BatchScript = "C:\MusicTools\MusicPipeline\sync_music.bat"
)

# Global variables and runtime states
$Global:IsPipelineRunning = $false
$Global:DiagLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"
$Global:CacheFile = "C:\MusicTools\MusicPipeline\Config\dashboard_cache.json"
$HtmlFile = "C:\MusicTools\MusicPipeline\Scripts\dashboard.html"
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
# 1. ROBUST BACKGROUND SCANNER
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

# -----------------------------------------------------------------
# 3. NETWORK ENGINE ROUTER ROUTINE
# -----------------------------------------------------------------
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:8080/")

try {
    $Listener.Start()
    Start-AsyncLibraryScanner
    
    while ($true) {
        try {
            $Context = $Listener.GetContext()
            $Request = $Context.Request
            $Response = $Context.Response
            $UrlPath = $Request.Url.LocalPath
            $Method  = $Request.HttpMethod

            $Response.KeepAlive = $false
            $Response.Headers.Add("Connection", "close")

            if ($UrlPath -eq "/" -and $Method -eq "GET") {
                # Clean File Injection Bypass
                $HtmlContent = Get-Content -LiteralPath $HtmlFile -Raw -Encoding utf8
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlContent)
                $Response.ContentType = "text/html; charset=utf-8"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/metrics" -and $Method -eq "GET") {
                if (Test-Path $Global:CacheFile) {
                    try {
                        $RawJson = Get-Content -LiteralPath $Global:CacheFile -Raw -ErrorAction SilentlyContinue
                        if ($RawJson) { $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawJson) }
                    } catch {
                        $JsonPayload = $Global:CachedMetrics | ConvertTo-Json -Depth 4 -Compress
                        $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                    }
                } else {
                    $JsonPayload = $Global:CachedMetrics | ConvertTo-Json -Depth 4 -Compress
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                }
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/stream" -and $Method -eq "GET") {
                $CurrentLogs = @()
                if (Test-Path $Global:DiagLogFile) { $CurrentLogs = Get-Content -LiteralPath $Global:DiagLogFile -ErrorAction SilentlyContinue }
                if ($CurrentLogs -match "Execution complete|completed successfully") {
                    $Global:IsPipelineRunning = $false
                }
                $JsonPayload = @{ running = $Global:IsPipelineRunning; logs = $CurrentLogs } | ConvertTo-Json -Compress
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/run" -and $Method -eq "POST") {
                Invoke-PipelineExecution
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}')
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/pull" -and $Method -eq "POST") {
                Invoke-HotReload
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"pulling"}')
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            else { $Response.StatusCode = 404 }
            $Response.OutputStream.Close()
        } catch {}
    }
} finally {
    if ($null -ne $Listener) { $Listener.Stop(); $Listener.Close() }
}
