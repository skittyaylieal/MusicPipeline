Param (
    [string]$BackupDir = "C:\Users\filip\Music\YT_Music_Backup",
    [string]$MobileDir = "C:\Users\filip\Music\YT_Music_Mobile"
)

# Global variables and runtime states
$Global:IsPipelineRunning = $false
$Global:DiagLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"
$Global:CacheFile = "C:\MusicTools\MusicPipeline\Config\dashboard_cache.json"
$Global:TimingFile = "C:\MusicTools\MusicPipeline\Config\timing_history.json"
$HtmlFile = "C:\MusicTools\MusicPipeline\Scripts\dashboard.html"

$ScriptRepoDir = "C:\MusicTools\MusicPipeline"
$ScriptDir = "$ScriptRepoDir\Scripts"
$ConfigDir = "$ScriptRepoDir\Config"

if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force }
if (-not (Test-Path $Global:TimingFile)) { "[]" | Out-File $Global:TimingFile }

# Shared Default Memory Container
$Global:CachedMetrics = @{
    masterCount  = 0; mobileCount = 0; lrcCount = 0
    masterSize   = 0; mobileSize  = 0; alerts = @()
    loadingState = "scanning"; tracks = @()
}

# -----------------------------------------------------------------
# 1. ROBUST BACKGROUND SCANNER & AUTOMATION ENGINE
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

                if ($TrackDatabase.Count % 150 -eq 0) {
                    @{
                        masterCount  = $MasterFiles.Count
                        mobileCount  = $MobileFiles.Count
                        lrcCount     = $LrcFiles.Count
                        masterSize   = [Math]::Round($MasterSize, 2)
                        mobileSize   = [Math]::Round($MobileSize, 2)
                        alerts       = @()
                        loadingState = "scanning"
                        tracks       = $TrackDatabase
                    } | ConvertTo-Json -Depth 4 | Out-File -FilePath $CFile -Encoding utf8 -Force
                }
            }

            $Alerts = @()
            if (Test-Path -LiteralPath "$RDir\.git") {
                try {
                    $Env:GIT_TERMINAL_PROMPT = "0"
                    $Env:GIT_SSH_COMMAND = ""
                    Push-Location $RDir
                    
                    # 1. Silently fetch from the remote repository to see if changes exist
                    [void](git -c network.timeout=5 fetch origin main 2>&1)
                    
                    # 2. Grab the precise hashes for local vs remote tracking branch
                    $LocalHash  = (git rev-parse HEAD).Trim()
                    $RemoteHash = (git rev-parse origin/main).Trim()

                    # 3. If they don't match, fire the warning to the dashboard cache
                    if ($LocalHash -ne $RemoteHash) {
                        $Alerts += @{ 
                            type      = "warning" 
                            message   = "Repository Update Available: Changes pushed from Mac are ready." 
                            fixAction = "gitpull" 
                        }
                    }
                    Pop-Location
                } catch {
                    if ($null -ne $RDir) { Pop-Location }
                }
            }

            if ($MasterFiles.Count -gt $MobileFiles.Count) {
                $Alerts += @{ type = "danger"; message = "Synchronization Gap: Master backup has $(($MasterFiles.Count - $MobileFiles.Count)) more track(s) than Mobile."; fixAction = "sync" }
            }

            @{
                masterCount  = $MasterFiles.Count
                mobileCount  = $MobileFiles.Count
                lrcCount     = $LrcFiles.Count
                masterSize   = [Math]::Round($MasterSize, 2)
                mobileSize   = [Math]::Round($MobileSize, 2)
                alerts       = $Alerts
                loadingState = "idle"
                tracks       = $TrackDatabase
            } | ConvertTo-Json -Depth 4 | Out-File -FilePath $CFile -Encoding utf8 -Force

            Start-Sleep -Seconds 60
        }
    }

    $Job = Start-Job -Name "MusicFolderScanner" -ScriptBlock $JobScript -ArgumentList $BackupDir, $MobileDir, $ScriptRepoDir, $Global:CacheFile
}

# Automated Chron Trigger (Dynamically tracks the assigned internal proxy port)
function Start-AutomatedChronDaemon {
    param($RuntimePort)

    Get-Job -Name "ChronDaemon" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue
    
    $ChronScript = {
        param($TargetPort)
        while ($true) {
            Start-Sleep -Seconds 1800
            try {
                Invoke-RestMethod -Uri "http://127.0.0.1:$TargetPort/run?type=Automated" -Method Post
            } catch {}
        }
    }
    $Job = Start-Job -Name "ChronDaemon" -ScriptBlock $ChronScript -ArgumentList $RuntimePort
}

# -----------------------------------------------------------------
# 2. PROCESS MANAGEMENT & PERFORMANCE PARSER
# -----------------------------------------------------------------
function Invoke-PipelineExecution {
    param(
        [bool]$CleanSweep = $false,
        [string]$TriggerType = "Manual"
    )

    if ($Global:IsPipelineRunning) { return }
    $Global:IsPipelineRunning = $true
    
    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
    "[SYSTEM] ($TriggerType Run) Initializing Master Pipeline..." | Out-File -FilePath $Global:DiagLogFile -Encoding utf8

    $ContextBundle = @{
        ScriptDir       = "C:\MusicTools\MusicPipeline\Scripts"
        ConfigDir       = "C:\MusicTools\MusicPipeline\Config"
        BackupDir       = $BackupDir
        MobileDir       = $MobileDir
        CookieFile      = "C:\MusicTools\MusicPipeline\Config\cookies.txt"
        HistoryFile     = "C:\MusicTools\MusicPipeline\Config\downloaded_history.txt"
        YTDLPExe        = "C:\MusicTools\yt-dlp.exe"
        FFmpegExe       = "C:\MusicTools\ffmpeg.exe"
        FirefoxExe      = "C:\Program Files\Mozilla Firefox\firefox.exe"
        CheckURL        = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        Playlists       = @(
            "https://www.youtube.com/playlist?list=PLqcuYaDDgyacWpBG6ib-2EKOuQa6aGjZJ",
            "https://www.youtube.com/playlist?list=PLqcuYaDDgyaeHKssVjz_Nw3qUDwfrwL09",
            "https://www.youtube.com/playlist?list=PLqcuYaDDgyad_i19iLheoQJLLKJUtwlAr"
        )
        CleanSweep      = $CleanSweep
        LogFile         = $Global:DiagLogFile
        TimingFile      = $Global:TimingFile
        RunType         = $TriggerType
    }

    $MasterPipelineJob = {
        param($EnvMap)

        function Log-Progress([string]$Msg) {
            $Timestamp = (Get-Date).ToString("HH:mm:ss")
            "[$Timestamp] $Msg" | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8
        }

        $OverallStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            # STEP 1: Cookie Validation
            Log-Progress "[STEP 1/5] Running Cookie Validation..."
            $S1Watch = [System.Diagnostics.Stopwatch]::StartNew()
            $S1ScriptPath = Join-Path $EnvMap.ScriptDir "CookieCheck.ps1"
            $S1Params = @{
                CookiePath = $EnvMap.CookieFile
                YTDLPPath  = $EnvMap.YTDLPExe
                TestURL    = $EnvMap.CheckURL
            }
            $Step1Result = & $S1ScriptPath @S1Params 2>&1
            $Step1Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8
            $S1Watch.Stop(); $S1Time = [string]::Format("{0:hh\:mm\:ss}", $S1Watch.Elapsed)

            # STEP 2: Downloader Script
            Log-Progress "[STEP 2/5] Running Native Pipeline Downloader..."
            $S2Watch = [System.Diagnostics.Stopwatch]::StartNew()
            $S2ScriptPath = Join-Path $EnvMap.ScriptDir "Download.ps1"
            $S2Params = @{
                BackupDir        = $EnvMap.BackupDir
                YTDLPPath        = $EnvMap.YTDLPExe
                CookiePath       = $EnvMap.CookieFile
                HistoryPath      = $EnvMap.HistoryFile
                PlaylistURLs     = $EnvMap.Playlists
                ConfigDir        = $EnvMap.ConfigDir
                SleepInterval    = 4
                MaxSleepInterval = 12
                SleepRequests    = 3
                CleanSweep       = $EnvMap.CleanSweep
            }
            $Step2Result = & $S2ScriptPath @S2Params 2>&1
            $Step2Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8
            $S2Watch.Stop(); $S2Time = [string]::Format("{0:hh\:mm\:ss}", $S2Watch.Elapsed)

            # STEP 3: Error Analysis
            Log-Progress "[STEP 3/5] Running Error Log Analysis..."
            $S3Watch = [System.Diagnostics.Stopwatch]::StartNew()
            $S3ScriptPath = Join-Path $EnvMap.ScriptDir "Fix.ps1"
            $S3Params = @{
                ConfigDir   = $EnvMap.ConfigDir
                HistoryPath = $EnvMap.HistoryFile
                FirefoxPath = $EnvMap.FirefoxExe
            }
            $Step3Result = & $S3ScriptPath @S3Params 2>&1
            $Step3Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8
            $S3Watch.Stop(); $S3Time = [string]::Format("{0:hh\:mm\:ss}", $S3Watch.Elapsed)

            # STEP 4: Lyrics Database Sync
            Log-Progress "[STEP 4/5] Syncing Local Lyrics Databases..."
            $S4Watch = [System.Diagnostics.Stopwatch]::StartNew()
            $S4ScriptPath = Join-Path $EnvMap.ScriptDir "Lyrics.ps1"
            $S4Params = @{
                BackupDir = $EnvMap.BackupDir
            }
            $Step4Result = & $S4ScriptPath @S4Params 2>&1
            $Step4Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8
            $S4Watch.Stop(); $S4Time = [string]::Format("{0:hh\:mm\:ss}", $S4Watch.Elapsed)

            # STEP 5: Transcoding Engine
            Log-Progress "[STEP 5/5] Executing Lossy Mobile Deployment Transcoding..."
            $S5Watch = [System.Diagnostics.Stopwatch]::StartNew()
            $S5ScriptPath = Join-Path $EnvMap.ScriptDir "CompressMusic.ps1"
            $S5Params = @{
                BackupDir  = $EnvMap.BackupDir
                MobileDir  = $EnvMap.MobileDir
                FFmpegPath = $EnvMap.FFmpegExe
                MaxThreads = 3
            }
            $Step5Result = & $S5ScriptPath @S5Params 2>&1
            $Step5Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8
            $S5Watch.Stop(); $S5Time = [string]::Format("{0:hh\:mm\:ss}", $S5Watch.Elapsed)

            $OverallStopwatch.Stop()
            $TotalTime = [string]::Format("{0:hh\:mm\:ss}", $OverallStopwatch.Elapsed)

            Log-Progress "[SUCCESS] Master Execution Pipeline Completed Successfully!"

            # TELEMETRY PACKAGER: Save performance record into history file
            $HistoryDB = Get-Content -LiteralPath $EnvMap.TimingFile -Raw | ConvertFrom-Json
            if ($null -eq $HistoryDB) { $HistoryDB = @() }
            
            $NewMetricRecord = @{
                timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                type      = $EnvMap.RunType
                step1     = $S1Time; step2 = $S2Time; step3 = $S3Time; step4 = $S4Time; step5 = $S5Time
                total     = $TotalTime
            }
            $HistoryDB += $NewMetricRecord
            $HistoryDB | ConvertTo-Json -Depth 4 | Out-File -FilePath $EnvMap.TimingFile -Encoding utf8 -Force
        }
        catch {
            Log-Progress "[CRITICAL ERROR] Pipeline execution collapsed: $_"
        }
    }

    $Job = Start-Job -Name "ActiveMusicDownloader" -ScriptBlock $MasterPipelineJob -ArgumentList $ContextBundle
}

function Invoke-HotReload {
    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
    "[SYSTEM] Hot-reload triggered. Checking for remote updates..." | Out-File -FilePath $Global:DiagLogFile -Encoding utf8
    Push-Location $ScriptRepoDir
    try {
        $Env:GIT_TERMINAL_PROMPT = "0"
        $Env:GIT_SSH_COMMAND = ""
        
        # 1. Grab current commit hash
        $BeforeHash = (& "git" rev-parse HEAD).Trim()

        # 2. Pull down updates
        $PullOutput = & "git" pull origin main 2>&1 | Out-String
        $PullOutput | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8
        
        # 3. Grab hash post-pull
        $AfterHash = (& "git" rev-parse HEAD).Trim()

        # 4. FIXED SANITY CHECK: Explicitly parse file ends to stop false positives
        $EngineChanged = $false
        if ($BeforeHash -ne $AfterHash) {
            $ChangedFiles = & "git" diff --name-only $BeforeHash $AfterHash
            foreach ($File in $ChangedFiles) {
                if ($File -replace '\\','/' -match "scripts/websiteengine.ps1$|^websiteengine.ps1$") {
                    $EngineChanged = $true
                    break
                }
            }
        }

        # 5. Conditional Process Respawn
        if ($EngineChanged) {
            "    ↳ WebsiteEngine.ps1 modification detected. Respawning core process..." | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8
            
            $ArgsList = @(
                "-NoProfile",
                "-WindowStyle", "Hidden",
                "-File", "$PSCommandPath"
            )
            
            Start-Process -FilePath "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList $ArgsList
            Pop-Location
            Stop-Process -Id $PID -Force
        } else {
            "    ↳ Asset update only (HTML/CSS). Engine restart skipped. Core server remains live." | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8
        }

    } catch {
        "    ↳ Hot-Reload Exception: $_" | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8
    }
    Pop-Location
}

# -----------------------------------------------------------------
# 3. ADAPTIVE NETWORK ENGINE ROUTER ROUTINE
# -----------------------------------------------------------------
# FAILSAFE: Forcefully tear down any residual Windows port proxy mappings from old crashed sessions
Write-Host "🧼 Flushing old proxy tables..." -ForegroundColor Yellow
netsh interface portproxy reset | Out-Null

# Clear any zombie jobs that might be clinging to the pipeline name space
Get-Job -Name "MusicFolderScanner","ChronDaemon","ActiveMusicDownloader" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

# Find an open port dynamically starting from 49152 to host the script safely behind the scenes
$TargetPort = 49152
while ($true) {
    $Conflict = Get-NetTCPConnection -LocalPort $TargetPort -ErrorAction SilentlyContinue
    if (-not $Conflict) { break }
    $TargetPort++
}

# Re-build the fresh native Windows Port Forwarder mapping: Port 80 -> Free High Port
Write-Host "🔗 Aligning fresh Windows port proxy map: 80 ---> $TargetPort" -ForegroundColor Cyan
netsh interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=$TargetPort connectaddress=127.0.0.1

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://127.0.0.1:$TargetPort/")

try {
    $Listener.Start()
    
    $LocalIPs = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi','Ethernet' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress
    $PrimaryIP = if ($LocalIPs) { $LocalIPs[0] } else { "127.0.0.1" }

    Write-Output "--------------------------------------------------"
    Write-Output " SERVER LIVE AND ADAPTIVELY MAPPED!"
    Write-Output " Internal Endpoint : http://127.0.0.1:$TargetPort/"
    Write-Output " Clean Browser URL : http://$PrimaryIP/"
    Write-Output "--------------------------------------------------"
    
    Start-AsyncLibraryScanner
    Start-AutomatedChronDaemon -RuntimePort $TargetPort
    
    # SYSTEM INTERRUPT REGISTER: If the window is closed normally or Ctrl+C is pressed
    trap {
        Write-Host "🛑 Shutting down server engine cleanly..." -ForegroundColor Red
        if ($null -ne $Listener -and $Listener.IsListening) { $Listener.Stop() }
        if ($null -ne $Listener) { $Listener.Close() }
        netsh interface portproxy reset | Out-Null
        exit
    }

    while ($true) {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response
        $UrlPath = $Request.Url.LocalPath
        $Method  = $Request.HttpMethod

        $Response.KeepAlive = $false
        
        $Response.Headers.Add("Connection", "close")
        $Response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
        $Response.Headers.Add("Pragma", "no-cache")
        $Response.Headers.Add("Expires", "0")

        if ($UrlPath -eq "/" -and $Method -eq "GET") {
            $HtmlContent = Get-Content -LiteralPath $HtmlFile -Raw -Encoding utf8
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlContent)
            $Response.ContentType = "text/html; charset=utf-8"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        elseif ($UrlPath -eq "/analytics" -and $Method -eq "GET") {
            $RawData = "[]"
            if (Test-Path $Global:TimingFile) { $RawData = Get-Content -LiteralPath $Global:TimingFile -Raw }
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData)
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        elseif ($UrlPath -eq "/metrics" -and $Method -eq "GET") {
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
        elseif ($UrlPath -eq "/stream" -and $Method -eq "GET") {
            $CurrentLogs = @()
            if (Test-Path $Global:DiagLogFile) { $CurrentLogs = Get-Content -LiteralPath $Global:DiagLogFile -ErrorAction SilentlyContinue }
            
            $DownloadJob = Get-Job -Name "ActiveMusicDownloader" -ErrorAction SilentlyContinue
            if ($DownloadJob) {
                if ($DownloadJob.State -ne "Running") { $Global:IsPipelineRunning = $false; Remove-Job -Job $DownloadJob -Force }
            } else { $Global:IsPipelineRunning = $false }

            $JsonPayload = @{ running = $Global:IsPipelineRunning; logs = $CurrentLogs } | ConvertTo-Json -Compress
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        elseif ($UrlPath -eq "/clear-logs" -and $Method -eq "POST") {
            try {
                Clear-Content -LiteralPath $Global:DiagLogFile -ErrorAction Stop
                "[SYSTEM] Console logs manually cleared." | Out-File -FilePath $Global:DiagLogFile -Encoding utf8
                
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"cleared"}')
                $Response.StatusCode = 200
            } catch {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Failed to clear logs"}')
                $Response.StatusCode = 500
            }
            
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        elseif ($UrlPath -eq "/run" -and $Method -eq "POST") {
            $IsSweepRequested = [bool]($Request.Url.Query -match "sweep=true")
            
            $RunContext = "Manual"
            if ($Request.Url.Query -match "type=Automated") { $RunContext = "Automated" }
            if ($IsSweepRequested) { $RunContext = "Clean Sweep" }
            
            Invoke-PipelineExecution -CleanSweep $IsSweepRequested -TriggerType $RunContext
            
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}')
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        elseif ($UrlPath -eq "/stop" -and $Method -eq "POST") {
            try {
                $DownloadJob = Get-Job -Name "ActiveMusicDownloader" -ErrorAction SilentlyContinue
                if ($DownloadJob) {
                    Stop-Job -Job $DownloadJob -ErrorAction SilentlyContinue
                    Remove-Job -Job $DownloadJob -Force -ErrorAction SilentlyContinue
                }
                
                $Global:IsPipelineRunning = $false
                
                $Timestamp = (Get-Date).ToString("HH:mm:ss")
                "[$Timestamp] [SYSTEM] Pipeline manually terminated by user." | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8
                
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"stopped"}')
                $Response.StatusCode = 200
            } catch {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Failed to terminate job"}')
                $Response.StatusCode = 500
            }
            
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        elseif ($UrlPath -eq "/pull" -and $Method -eq "POST") {
            Invoke-HotReload
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"pulling"}')
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            $Response.OutputStream.Close()
            
            Stop-Process -Id $PID -Force
        }
        elseif ($UrlPath -eq "/favicon.ico") {
            $Response.StatusCode = 404
        }
        else { 
            $Response.StatusCode = 404 
        }
        
        try {
            $Response.OutputStream.Close()
        } catch {}
    }
}  
catch { 
    Write-Host "⚠️ Router Stream Exception: $_" -ForegroundColor Yellow
}
finally {
    if ($null -ne $Listener) { if ($Listener.IsListening) { $Listener.Stop() }; $Listener.Close() }
}