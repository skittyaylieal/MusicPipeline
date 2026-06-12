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

if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force | Out-Null } 
if (-not (Test-Path $Global:TimingFile)) { "[]" | Out-File $Global:TimingFile -Encoding utf8 } 

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

            $MasterSize = 0
            if ($MasterFiles) { $MasterSize = ($MasterFiles | Measure-Object -Property Length -Sum).Sum / 1GB }
            $MobileSize = 0
            if ($MobileFiles) { $MobileSize = ($MobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB }

            $TrackDatabase = @() 

            foreach ($File in $MasterFiles) { 
                if ($null -eq $File.FullName) { continue } 
                $RelativePath = $File.FullName.Substring($BDir.Length).TrimStart('\') 
                $PathParts = $RelativePath -split '\\' 
                
                $Artist = "Unknown Artist"
                $Album  = "Single / Unknown"
                
                if ($PathParts.Count -ge 3) {
                    $Artist = $PathParts[0]
                    $Album  = $PathParts[1]
                } elseif ($PathParts.Count -eq 2) {
                    $Artist = $PathParts[0]
                }

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
                    [void](git -c network.timeout=5 fetch origin main 2>&1) 
                    $LocalHash  = (git rev-parse HEAD).Trim() 
                    $RemoteHash = (git rev-parse origin/main).Trim() 

                    if ($LocalHash -ne $RemoteHash) { 
                        $Alerts += @{ 
                            type      = "warning" 
                            message   = "Repository Update Available: Changes pushed from Mac are ready."
                            fixAction = "gitpull" 
                        }
                    }
                    Pop-Location 
                } catch {
                    Pop-Location
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

function Start-AutomatedChronDaemon {
    param($RuntimePort)
    Get-Job -Name "ChronDaemon" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue 
    
    $ChronScript = {
        param($TargetPort)
        while ($true) {
            Start-Sleep -Seconds 1800 
            try { Invoke-RestMethod -Uri "http://127.0.0.1:$TargetPort/run?type=Automated" -Method Post } catch {} 
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
    "`e[1;36m[SYSTEM] ($TriggerType Run) Initializing Master Pipeline...`e[0m" | Out-File -FilePath $Global:DiagLogFile -Encoding utf8 

    $ContextBundle = @{
        ScriptDir       = "C:\MusicTools\MusicPipeline\Scripts" 
        ConfigDir       = "C:\MusicTools\MusicPipeline\Config" 
        CacheDir        = "C:\MusicTools\MusicPipeline\Config\.cache"
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

        $env:PYTHONUNBUFFERED = "1" 
        $env:YTDLP_UNBUFFERED = "1" 

        function Log-Progress([string]$Msg) {
            $Timestamp = (Get-Date).ToString("HH:mm:ss") 
            "`e[90m[$Timestamp]`e[0m $Msg" | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
        }

        $OverallStopwatch = [System.Diagnostics.Stopwatch]::StartNew() 

        try {
            Log-Progress "`e[1;33m[STEP 1/5]`e[0m Running Cookie Validation..." 
            $S1Watch = [System.Diagnostics.Stopwatch]::StartNew() 
            $S1ScriptPath = Join-Path $EnvMap.ScriptDir "CookieCheck.ps1" 
            if (Test-Path $S1ScriptPath) {
                $S1Params = @{ CookiePath = $EnvMap.CookieFile; YTDLPPath = $EnvMap.YTDLPExe; TestURL = $EnvMap.CheckURL } 
                $Step1Result = & $S1ScriptPath @S1Params 2>&1 
                $Step1Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
            } else { Log-Progress "⚠️ CookieCheck.ps1 missing. Skipping." }
            $S1Watch.Stop();
            $S1Time = [string]::Format("{0:hh\:mm\:ss}", $S1Watch.Elapsed) 

            Log-Progress "`e[1;33m[STEP 2/5]`e[0m Running Native Pipeline Downloader..." 
            $S2Watch = [System.Diagnostics.Stopwatch]::StartNew() 
            $S2ScriptPath = Join-Path $EnvMap.ScriptDir "Download.ps1" 
            if (Test-Path $S2ScriptPath) {
                $S2Params = @{
                    BackupDir        = $EnvMap.BackupDir 
                    YTDLPPath        = $EnvMap.YTDLPExe 
                    CookiePath       = $EnvMap.CookieFile 
                    HistoryPath      = $EnvMap.HistoryFile 
                    PlaylistURLs     = $EnvMap.Playlists 
                    ConfigDir        = $EnvMap.ConfigDir 
                    CacheDir         = $EnvMap.CacheDir
                    SleepInterval    = 4 
                    MaxSleepInterval = 12 
                    SleepRequests    = 3 
                    CleanSweep       = $EnvMap.CleanSweep 
                }
                $Step2Result = & $S2ScriptPath @S2Params 2>&1 
                $Step2Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
            } else { Log-Progress "⚠️ Download.ps1 missing. Skipping." }
            $S2Watch.Stop();
            $S2Time = [string]::Format("{0:hh\:mm\:ss}", $S2Watch.Elapsed) 

            Log-Progress "`e[1;33m[STEP 3/5]`e[0m Running Error Log Analysis..." 
            $S3Watch = [System.Diagnostics.Stopwatch]::StartNew() 
            $S3ScriptPath = Join-Path $EnvMap.ScriptDir "Fix.ps1" 
            if (Test-Path $S3ScriptPath) {
                $S3Params = @{ ConfigDir = $EnvMap.ConfigDir; HistoryPath = $EnvMap.HistoryFile; FirefoxPath = $EnvMap.FirefoxExe } 
                $Step3Result = & $S3ScriptPath @S3Params 2>&1 
                $Step3Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
            } else { Log-Progress "⚠️ Fix.ps1 missing. Skipping." }
            $S3Watch.Stop();
            $S3Time = [string]::Format("{0:hh\:mm\:ss}", $S3Watch.Elapsed) 

            Log-Progress "`e[1;33m[STEP 4/5]`e[0m Syncing Local Lyrics Databases..." 
            $S4Watch = [System.Diagnostics.Stopwatch]::StartNew() 
            $S4ScriptPath = Join-Path $EnvMap.ScriptDir "Lyrics.ps1" 
            if (Test-Path $S4ScriptPath) {
                $S4Params = @{ BackupDir = $EnvMap.BackupDir } 
                $Step4Result = & $S4ScriptPath @S4Params 2>&1 
                $Step4Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
            } else { Log-Progress "⚠️ Lyrics.ps1 missing. Skipping." }
            $S4Watch.Stop();
            $S4Time = [string]::Format("{0:hh\:mm\:ss}", $S4Watch.Elapsed) 

            Log-Progress "`e[1;33m[STEP 5/5]`e[0m Executing Lossy Mobile Deployment Transcoding..." 
            $S5Watch = [System.Diagnostics.Stopwatch]::StartNew() 
            $S5ScriptPath = Join-Path $EnvMap.ScriptDir "CompressMusic.ps1" 
            if (Test-Path $S5ScriptPath) {
                $S5Params = @{ BackupDir = $EnvMap.BackupDir; MobileDir = $EnvMap.MobileDir; FFmpegPath = $EnvMap.FFmpegExe; MaxThreads = 3 } 
                $Step5Result = & $S5ScriptPath @S5Params 2>&1 
                $Step5Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
            } else { Log-Progress "⚠️ CompressMusic.ps1 missing. Skipping." }
            $S5Watch.Stop();
            $S5Time = [string]::Format("{0:hh\:mm\:ss}", $S5Watch.Elapsed) 

            $OverallStopwatch.Stop() 
            $TotalTime = [string]::Format("{0:hh\:mm\:ss}", $OverallStopwatch.Elapsed) 

            Log-Progress "`e[1;32m[SUCCESS] Master Execution Pipeline Completed Successfully!`e[0m" 
            
            $HistoryDB = @()
            if (Test-Path $EnvMap.TimingFile) {
                try { $HistoryDB = Get-Content -LiteralPath $EnvMap.TimingFile -Raw | ConvertFrom-Json } catch { $HistoryDB = @() }
            }
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
            Log-Progress "`e[1;31m[CRITICAL ERROR] Pipeline execution collapsed: $_`e[0m" 
        }
    }

    $Job = Start-Job -Name "ActiveMusicDownloader" -ScriptBlock $MasterPipelineJob -ArgumentList $ContextBundle 
}

function Invoke-HotReload {
    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force } 
    "`e[1;35m[SYSTEM] Hot-reload triggered. Checking for remote updates...`e[0m" | Out-File -FilePath $Global:DiagLogFile -Encoding utf8 
    Push-Location $ScriptRepoDir 
    try {
        $Env:GIT_TERMINAL_PROMPT = "0" 
        $Env:GIT_SSH_COMMAND = "" 
        $BeforeHash = (& "git" rev-parse HEAD).Trim() 
        $PullOutput = & "git" pull origin main 2>&1 | Out-String 
        $PullOutput | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 
        $AfterHash = (& "git" rev-parse HEAD).Trim() 

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

        if ($EngineChanged) { 
            " ↳ WebsiteEngine.ps1 modification detected. Respawning core process..." | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 
            $ArgsList = @("-NoProfile", "-WindowStyle", "Hidden", "-File", "$PSCommandPath") 
            Start-Process -FilePath "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList $ArgsList 
            Pop-Location 
            Stop-Process -Id $PID -Force 
        } else {
            " ↳ Asset update only (HTML/CSS). Engine restart skipped. Core server remains live." | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 
        }
    } catch {
        " ↳ Hot-Reload Exception: $_" | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 
    }
    Pop-Location 
}

# -----------------------------------------------------------------
# 3. ADAPTIVE NETWORK ENGINE ROUTER ROUTINE
# -----------------------------------------------------------------
Write-Host "🧼 Flushing old proxy tables and cleaning session jobs..." -ForegroundColor Yellow 
netsh interface portproxy reset | Out-Null 
Get-Job -Name "MusicFolderScanner","ChronDaemon","ActiveMusicDownloader" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue 

$TargetPort = 49152 
while ($true) { 
    $Conflict = Get-NetTCPConnection -LocalPort $TargetPort -ErrorAction SilentlyContinue 
    if (-not $Conflict) { break } 
    $TargetPort++ 
}

Write-Host "🔗 Aligning fresh Windows port proxy map: 80 ---> $TargetPort" -ForegroundColor Cyan 
netsh interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=$TargetPort connectaddress=127.0.0.1 | Out-Null

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
            if (Test-Path $HtmlFile) {
                $HtmlContent = Get-Content -LiteralPath $HtmlFile -Raw -Encoding utf8 
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlContent) 
                $Response.ContentType = "text/html; charset=utf-8" 
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            } else { $Response.StatusCode = 404 }
            $Response.OutputStream.Close()
        }
        elseif ($UrlPath -eq "/broken-songs" -and $Method -eq "GET") {
            $BrokenDbFile = "C:\MusicTools\MusicPipeline\Config\broken_songs.json"
            $RawData = "[]"
            if (Test-Path $BrokenDbFile) { $RawData = Get-Content -LiteralPath $BrokenDbFile -Raw }
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData)
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            $Response.OutputStream.Close()
        }
        elseif ($UrlPath -eq "/resolve-song" -and $Method -eq "POST") {
            $BrokenDbFile = "C:\MusicTools\MusicPipeline\Config\broken_songs.json"
            $HistoryFile  = "C:\MusicTools\MusicPipeline\Config\downloaded_history.txt"
            
            # Read from JSON body input stream rather than QueryStrings
            $Reader = New-Object System.IO.StreamReader($Request.InputStream)
            $BodyJson = $Reader.ReadToEnd()
            $Payload = $BodyJson | ConvertFrom-Json
            
            $SongId  = $Payload.id
            $Action  = $Payload.action
            $VideoID = $Payload.videoId

            if ($SongId -and (Test-Path $BrokenDbFile)) {
                $CurrentList = Get-Content -LiteralPath $BrokenDbFile -Raw | ConvertFrom-Json
                $TargetSong = $CurrentList | Where-Object { $_.id -eq $SongId }
                
                # Check if it requires a manual background single VPN routing download
                if ($Action -eq "geo_vpn_fix" -and $TargetSong) {
                    $Global:IsPipelineRunning = $true
                    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
                    
                    $SingleJobBlock = {
                        param($Log, $Backup, $Cfg, $Vid, $Sid, $DbFile, $HistFile)
                        $ProtonCLI = "C:\Program Files\Proton\VPN\ProtonVPN.Backend.CLI.exe"
                        $YTDLP = "C:\MusicTools\yt-dlp.exe"
                        $Cookies = "C:\MusicTools\MusicPipeline\Config\cookies.txt"
                        
                        "`e[1;35m[SYSTEM] Targeted VPN Link Established for ID: $Vid...`e[0m" | Out-File -FilePath $Log -Append -Encoding utf8
                        & $ProtonCLI c --cc US 2>&1 | Out-Null
                        Start-Sleep -Seconds 8
                        
                        $TargetUrl = "https://www.youtube.com/watch?v=$Vid"
                        & $YTDLP --no-colors --embed-metadata --embed-thumbnail --convert-thumbnails jpg -f "ba[ext=m4a]/ba" --cookies $Cookies -P $Backup $TargetUrl 2>&1 | Out-File -FilePath $Log -Append -Encoding utf8
                        $Status = $LASTEXITCODE
                        
                        & $ProtonCLI d 2>&1 | Out-Null
                        if ($Status -eq 0) {
                            "`e[1;32m[SUCCESS] Track successfully resolved over VPN.`e[0m" | Out-File -FilePath $Log -Append -Encoding utf8
                            $ReloadDb = Get-Content -LiteralPath $DbFile -Raw | ConvertFrom-Json
                            $ReloadDb | Where-Object { $_.id -ne $Sid } | ConvertTo-Json -Depth 4 | Out-File -FilePath $DbFile -Encoding utf8 -Force
                        } else {
                            "`e[1;31m[ERROR] Extraction failed over active VPN adapter link.`e[0m" | Out-File -FilePath $Log -Append -Encoding utf8
                        }
                    }
                    $Job = Start-Job -Name "ActiveMusicDownloader" -ScriptBlock $SingleJobBlock -ArgumentList $Global:DiagLogFile, $BackupDir, $ConfigDir, $TargetSong.videoId, $SongId, $BrokenDbFile, $HistoryFile
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"success","message":"Dispatched targeted single VPN route"}')
                } else {
                    # Standard baseline resolutions (mark fixed, skip)
                    $UpdatedList = $CurrentList | Where-Object { $_.id -ne $SongId }
                    $UpdatedList | ConvertTo-Json -Depth 4 | Out-File -FilePath $BrokenDbFile -Encoding utf8 -Force

                    if ($Action -eq "write_history" -and -not [string]::IsNullOrWhiteSpace($VideoID)) {
                        $ArchiveLine = "youtube $VideoID"
                        [System.IO.File]::AppendAllText($HistoryFile, ($ArchiveLine + [System.Environment]::NewLine))
                    }
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"success"}')
                }
                $Response.StatusCode = 200
            } else {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Invalid request target"}')
                $Response.StatusCode = 400
            }
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            $Response.OutputStream.Close()
        }
        elseif ($UrlPath -eq "/run-geo-recovery" -and $Method -eq "POST") { # Aligned with frontend routing name
            if ($Global:IsPipelineRunning) {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Pipeline active"}')
                $Response.StatusCode = 409
            } else {
                $Global:IsPipelineRunning = $true
                if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
                "`e[1;35m[SYSTEM] Initializing Safe Asynchronous ProtonVPN Geo-Recovery Loop...`e[0m" | Out-File -FilePath $Global:DiagLogFile -Encoding utf8

                $RecoveryJobBlock = {
                    param($Log, $Backup, $Cfg)
                    function Log-VpnProgress([string]$M) {
                        $T = (Get-Date).ToString("HH:mm:ss")
                        "`e[90m[$T]`e[0m $M" | Out-File -FilePath $Log -Append -Encoding utf8
                    }

                    $ProtonCLI = "C:\Program Files\Proton\VPN\ProtonVPN.Backend.CLI.exe"
                    $YTDLP = "C:\MusicTools\yt-dlp.exe"
                    $Cookies = "C:\MusicTools\MusicPipeline\Config\cookies.txt"
                    $DbFile = Join-Path $Cfg "broken_songs.json"

                    if (-not (Test-Path $DbFile)) { Log-VpnProgress "🛑 Error database missing."; return }
                    $Db = Get-Content -LiteralPath $DbFile -Raw | ConvertFrom-Json
                    $GeoTracks = $Db | Where-Object { $_.reason -match "available in your country|GeoRestrictedError|not made this video available|sign in to confirm" }

                    if ($null -eq $GeoTracks -or $GeoTracks.Count -eq 0) {
                        Log-VpnProgress "🔍 Clean analytics match. Zero songs are currently blocked behind geo-restrictions."
                        return
                    }

                    Log-VpnProgress "`e[1;33m[*] Routing connection... Forcing USA safe exit node.`e[0m"
                    & $ProtonCLI c --cc US 2>&1 | Out-File -FilePath $Log -Append -Encoding utf8
                    Start-Sleep -Seconds 8

                    $SuccessTracks = @()
                    foreach ($Track in $GeoTracks) {
                        $TargetUrl = "https://www.youtube.com/watch?v=$($Track.videoId)"
                        Log-VpnProgress "🚀 Pulling track through secure tunnel: $TargetUrl"
                        & $YTDLP --no-colors --embed-metadata --embed-thumbnail --convert-thumbnails jpg -f "ba[ext=m4a]/ba" --cookies $Cookies -P $Backup $TargetUrl 2>&1 | Out-File -FilePath $Log -Append -Encoding utf8
                        if ($LASTEXITCODE -eq 0) {
                            Log-VpnProgress "[+] Download Success: $($Track.videoId)"
                            $SuccessTracks += $Track.videoId
                        } else {
                            Log-VpnProgress "🛑 Dynamic tunnel breakdown or failure on ID: $($Track.videoId)"
                        }
                    }

                    Log-VpnProgress "`e[1;31m[*] Terminating active routing adapters... Closing VPN connection.`e[0m"
                    & $ProtonCLI d 2>&1 | Out-File -FilePath $Log -Append -Encoding utf8

                    if ($SuccessTracks.Count -gt 0) {
                        $ReloadDb = Get-Content -LiteralPath $DbFile -Raw | ConvertFrom-Json
                        $CleanedDb = $ReloadDb | Where-Object { $SuccessTracks -notcontains $_.videoId }
                        $CleanedDb | ConvertTo-Json -Depth 4 | Out-File -FilePath $DbFile -Encoding utf8 -Force
                        Log-VpnProgress "`e[1;32m[SUCCESS] Removed ($($SuccessTracks.Count)) anomalies from broken_songs.json!`e[0m"
                    }
                }
                $Job = Start-Job -Name "ActiveMusicDownloader" -ScriptBlock $RecoveryJobBlock -ArgumentList $Global:DiagLogFile, $BackupDir, $ConfigDir
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}')
                $Response.StatusCode = 200
            }
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            $Response.OutputStream.Close()
        }
        elseif ($UrlPath -eq "/analytics" -and $Method -eq "GET") { 
            $RawData = "[]" 
            if (Test-Path $Global:TimingFile) { $RawData = Get-Content -LiteralPath $Global:TimingFile -Raw } 
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData) 
            $Response.ContentType = "application/json" 
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
            $Response.OutputStream.Close()
        }
        elseif ($UrlPath -eq "/metrics" -and $Method -eq "GET") { 
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes(($Global:CachedMetrics | ConvertTo-Json -Depth 4 -Compress))
            if (Test-Path $Global:CacheFile) { 
                try {
                    $RawJson = Get-Content -LiteralPath $Global:CacheFile -Raw -ErrorAction SilentlyContinue 
                    if ($RawJson) { $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawJson) } 
                } catch {}
            }
            $Response.ContentType = "application/json" 
            $Response.ContentLength64 = $Buffer.Length 
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
            $Response.OutputStream.Close()
        }
        elseif ($UrlPath -eq "/stream" -and $Method -eq "GET") { 
            $CurrentLogs = @()
            $AllLines = @()
            
            $SkipCount = 0
            if ($Request.Url.Query -match "skip=(\d+)") { $SkipCount = [int]$Matches[1] }

            if (Test-Path $Global:DiagLogFile) { 
                try {
                    $FileStream = [System.IO.File]::Open($Global:DiagLogFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                    $StreamReader = New-Object System.IO.StreamReader($FileStream, [System.Text.Encoding]::UTF8)
                    while ($null -ne ($Line = $StreamReader.ReadLine())) { $AllLines += $Line }
                    $StreamReader.Close();
                    $FileStream.Close()
                } catch { $AllLines = @() }

                if ($AllLines.Count -gt 0) {
                    if ($SkipCount -lt $AllLines.Count) {
                        $CurrentLogs = $AllLines[$SkipCount..($AllLines.Count - 1)]
                    }
                }
            } 
            
            $DownloadJob = Get-Job -Name "ActiveMusicDownloader" -ErrorAction SilentlyContinue 
            if ($DownloadJob) {
                if ($DownloadJob.State -ne "Running") { $Global:IsPipelineRunning = $false; Remove-Job -Job $DownloadJob -Force } 
            } else { $Global:IsPipelineRunning = $false } 

            $JsonPayload = @{ 
                running = $Global:IsPipelineRunning;
                logs    = $CurrentLogs;
                totalLines = $AllLines.Count
            } | ConvertTo-Json -Compress 

            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload) 
            $Response.ContentType = "application/json" 
            $Response.ContentLength64 = $Buffer.Length 
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
            $Response.OutputStream.Close()
        }
        elseif ($UrlPath -eq "/clear-logs" -and $Method -eq "POST") { 
            try {
                Clear-Content -LiteralPath $Global:DiagLogFile -ErrorAction Stop 
                "`e[1;36m[SYSTEM] Console logs manually cleared.`e[0m" | Out-File -FilePath $Global:DiagLogFile -Encoding utf8 
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"cleared"}') 
                $Response.StatusCode = 200 
            } catch {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Failed to clear logs"}') 
                $Response.StatusCode = 500 
            }
            $Response.ContentType = "application/json" 
            $Response.ContentLength64 = $Buffer.Length 
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
            $Response.OutputStream.Close()
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
            $Response.OutputStream.Close()
        }
        elseif ($UrlPath -eq "/stop" -and $Method -eq "POST") {
            try {
                $DownloadJob = Get-Job -Name "ActiveMusicDownloader" -ErrorAction SilentlyContinue
                if ($DownloadJob) {
                    Stop-Job -Job $DownloadJob -ErrorAction SilentlyContinue
                    Remove-Job -Job $DownloadJob -Force -ErrorAction SilentlyContinue
                }
                Stop-Process -Name "yt-dlp" -Force -ErrorAction SilentlyContinue
                Stop-Process -Name "ffmpeg" -Force -ErrorAction SilentlyContinue

                $Global:IsPipelineRunning = $false
                $Timestamp = (Get-Date).ToString("HH:mm:ss")
                "`e[1;31m[$Timestamp] [SYSTEM] Pipeline and all child processes manually terminated.`e[0m" | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8

                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"stopped"}')
                $Response.StatusCode = 200
            } catch {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Failed to terminate job"}')
                $Response.StatusCode = 500
            }
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            $Response.OutputStream.Close()
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
        else { 
            $Response.StatusCode = 404 
            try { $Response.OutputStream.Close() } catch {}
        }
    }
}
catch { Write-Host "⚠️ Router Stream Exception: $_" -ForegroundColor Yellow } 
finally { if ($null -ne $Listener) { if ($Listener.IsListening) { $Listener.Stop() }; $Listener.Close() } }