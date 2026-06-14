Param (
    [string]$ProfilesFile = "C:\MusicTools\MusicPipeline\Config\profiles.json"
)

# Root System Anchors
$ScriptRepoDir = "C:\MusicTools\MusicPipeline" 
$ScriptDir     = "$ScriptRepoDir\Scripts" 
$ConfigDir     = "$ScriptRepoDir\Config" 
$HtmlFile      = "$ScriptDir\dashboard.html" 

# -----------------------------------------------------------------
# CORE PROFILE INJECTION ENGINE
# -----------------------------------------------------------------
function Load-ProfileContext {
    if (-not (Test-Path $ProfilesFile)) {
        if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force | Out-Null }
        # Inline absolute fallback generation matching your current environment specifications
        $DefaultTemplate = @{
            activeProfile = "Default"
            profiles = @{
                Default = @{
                    BackupDir               = "C:\Users\filip\Music\YT_Music_Backup"
                    MobileDir               = "C:\Users\filip\Music\YT_Music_Mobile"
                    BrokenSongsFile         = "C:\MusicTools\MusicPipeline\Config\broken_songs.json"
                    DiagLogFile             = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"
                    CacheFile               = "C:\MusicTools\MusicPipeline\Config\dashboard_cache.json"
                    TimingFile              = "C:\MusicTools\MusicPipeline\Config\timing_history.json"
                    CookieFile              = "C:\MusicTools\MusicPipeline\Config\cookies.txt"
                    HistoryFile             = "C:\MusicTools\MusicPipeline\Config\downloaded_history.txt"
                    YTDLPExe                = "C:\MusicTools\yt-dlp.exe"
                    FFmpegExe               = "C:\MusicTools\ffmpeg.exe"
                    FirefoxExe              = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    CheckURL                = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
                    SleepInterval           = 4
                    MaxSleepInterval        = 12
                    SleepRequests           = 3
                    MaxCompressThreads      = 3
                    ScannerSleepIntervalSec = 60
                    ChronDaemonSleepSec     = 1800
                    Playlists               = @(
                        "https://www.youtube.com/playlist?list=PLqcuYaDDgyacWpBG6ib-2EKOuQa6aGjZJ",
                        "https://www.youtube.com/playlist?list=PLqcuYaDDgyaeHKssVjz_Nw3qUDwfrwL09",
                        "https://www.youtube.com/playlist?list=PLqcuYaDDgyad_i19iLheoQJLLKJUtwlAr"
                    )
                }
            }
        }
        $DefaultTemplate | ConvertTo-Json -Depth 5 | Out-File $ProfilesFile -Encoding utf8 -Force
    }

    $RawConfig = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
    $Global:ActiveProfileName = $RawConfig.activeProfile
    $Global:Profile = $RawConfig.profiles.$($Global:ActiveProfileName)

    # Re-expose key engine dependencies cleanly to core runtime globals
    $Global:DiagLogFile = $Global:Profile.DiagLogFile
    $Global:CacheFile   = $Global:Profile.CacheFile
    $Global:TimingFile  = $Global:Profile.TimingFile
}

# Initial Context Engine Boot up Sequence
Load-ProfileContext
$Global:IsPipelineRunning = $false

if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force | Out-Null } 
if (-not (Test-Path $Global:TimingFile)) { "[]" | Out-File $Global:TimingFile -Encoding utf8 } 

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
        param($BDir, $MDir, $RDir, $CFile, $ScanDelay)
        
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

                $IsInstrumentalTrack = [bool](Test-Path -LiteralPath "$($File.DirectoryName)\$($File.BaseName).inst" -ErrorAction SilentlyContinue)
                if (-not $IsInstrumentalTrack) {
                    $LrcPath = "$($File.DirectoryName)\$($File.BaseName).lrc"
                    if (Test-Path -LiteralPath $LrcPath) {
                        $Content = Get-Content -LiteralPath $LrcPath -Raw -TotalCount 10 -ErrorAction SilentlyContinue
                        if ($Content -and $Content -match "Instrumental") { $IsInstrumentalTrack = $true }
                    }
                }

                $TrackDatabase += @{ 
                    title          = [string]$File.BaseName 
                    artist         = [string]$Artist 
                    album          = [string]$Album 
                    sizeMb         = [Math]::Round(($File.Length / 1MB), 2) 
                    hasLrc         = [bool](Test-Path -LiteralPath "$($File.DirectoryName)\$($File.BaseName).lrc" -ErrorAction SilentlyContinue) 
                    isInstrumental = $IsInstrumentalTrack
                    type           = [string]$File.Extension.ToUpper().Replace('.','') 
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
                } catch { Pop-Location }
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

            Start-Sleep -Seconds $ScanDelay
        }
    }

    $Job = Start-Job -Name "MusicFolderScanner" -ScriptBlock $JobScript -ArgumentList $Global:Profile.BackupDir, $Global:Profile.MobileDir, $ScriptRepoDir, $Global:CacheFile, $Global:Profile.ScannerSleepIntervalSec
}

function Start-AutomatedChronDaemon {
    param($RuntimePort, $LoopInterval)
    Get-Job -Name "ChronDaemon" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue 
    
    $ChronScript = {
        param($TargetPort, $Delay)
        while ($true) {
            Start-Sleep -Seconds $Delay 
            try { Invoke-RestMethod -Uri "http://127.0.0.1:$TargetPort/run?type=Automated" -Method Post } catch {} 
        }
    }
    $Job = Start-Job -Name "ChronDaemon" -ScriptBlock $ChronScript -ArgumentList $RuntimePort, $LoopInterval 
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

    # Bundle compiled entirely out of variable profile options
    $ContextBundle = @{
        ScriptDir        = $ScriptDir 
        ConfigDir        = $ConfigDir 
        CacheDir         = Join-Path $ConfigDir ".cache"
        BackupDir        = $Global:Profile.BackupDir 
        MobileDir        = $Global:Profile.MobileDir 
        CookieFile       = $Global:Profile.CookieFile 
        HistoryFile      = $Global:Profile.HistoryFile 
        YTDLPExe         = $Global:Profile.YTDLPExe 
        FFmpegExe        = $Global:Profile.FFmpegExe 
        FirefoxExe       = $Global:Profile.FirefoxExe 
        CheckURL         = $Global:Profile.CheckURL 
        Playlists        = @($Global:Profile.Playlists)
        SleepInterval    = [int]$Global:Profile.SleepInterval
        MaxSleepInterval = [int]$Global:Profile.MaxSleepInterval
        SleepRequests    = [int]$Global:Profile.SleepRequests
        MaxCompressThreads = [int]$Global:Profile.MaxCompressThreads
        CleanSweep       = $CleanSweep 
        LogFile          = $Global:DiagLogFile 
        TimingFile       = $Global:TimingFile 
        RunType          = $TriggerType 
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
                    SleepInterval    = $EnvMap.SleepInterval 
                    MaxSleepInterval = $EnvMap.MaxSleepInterval 
                    SleepRequests    = $EnvMap.SleepRequests 
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
                $S5Params = @{ BackupDir = $EnvMap.BackupDir; MobileDir = $EnvMap.MobileDir; FFmpegPath = $EnvMap.FFmpegExe; MaxThreads = $EnvMap.MaxCompressThreads } 
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
                try { $HistoryDB = @(Get-Content -LiteralPath $EnvMap.TimingFile -Raw | ConvertFrom-Json) } catch { $HistoryDB = @() }
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
        catch { Log-Progress "`e[1;31m[CRITICAL ERROR] Pipeline execution collapsed: $_`e[0m" }
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
    Start-AutomatedChronDaemon -RuntimePort $TargetPort -LoopInterval $Global:Profile.ChronDaemonSleepSec
    

    while ($true) {
        try {
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
                $HtmlContent = "<html><body><h1>Dashboard Loading Error</h1></body></html>"
                if (Test-Path $HtmlFile) { 
                    try { $HtmlContent = Get-Content -LiteralPath $HtmlFile -Raw -Encoding utf8 } catch {}
                }
                if ([string]::IsNullOrWhiteSpace($HtmlContent)) { $HtmlContent = " " }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlContent) 
                $Response.ContentType = "text/html; charset=utf-8" 
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/broken-songs" -and $Method -eq "GET") {
                $RawData = "[]"
                if (Test-Path $Global:Profile.BrokenSongsFile) { 
                    try { $RawData = Get-Content -LiteralPath $Global:Profile.BrokenSongsFile -Raw } catch {}
                }
                if ([string]::IsNullOrWhiteSpace($RawData)) { $RawData = "[]" }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData)
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            # --- PROFILE ENDPOINTS ---
            elseif ($UrlPath -eq "/profiles" -and $Method -eq "GET") {
                $RawData = '{"activeProfile": "Default", "profiles": {"Default": {}}}'
                if (Test-Path $ProfilesFile) {
                    try { $RawData = Get-Content -LiteralPath $ProfilesFile -Raw } catch {}
                }
                if ([string]::IsNullOrWhiteSpace($RawData)) { $RawData = '{"activeProfile": "Default", "profiles": {"Default": {}}}' }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData)
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/profiles/switch" -and $Method -eq "POST") {
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $JSONBody = $Reader.ReadToEnd() | ConvertFrom-Json
                
                $ProfilesJson = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
                if ($ProfilesJson.profiles.$($JSONBody.profileName)) {
                    $ProfilesJson.activeProfile = $JSONBody.profileName
                    $ProfilesJson | ConvertTo-Json -Depth 5 | Out-File $ProfilesFile -Encoding utf8 -Force
                    Load-ProfileContext
                    Start-AsyncLibraryScanner
                    Start-AutomatedChronDaemon -RuntimePort $TargetPort -LoopInterval $Global:Profile.ChronDaemonSleepSec
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"switched","profile":"' + $JSONBody.profileName + '"}')
                } else {
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Profile not found"}')
                    $Response.StatusCode = 404
                }
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/profiles/save" -and $Method -eq "POST") {
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $JSONBody = $Reader.ReadToEnd() | ConvertFrom-Json
                $ProfilesJson = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
                $TargetProfile = $JSONBody.profileName
                
                if (-not $ProfilesJson.profiles) { Add-Member -InputObject $ProfilesJson -MemberType NoteProperty -Name "profiles" -Value @{} }
                $ProfilesJson.profiles | Add-Member -MemberType NoteProperty -Name $TargetProfile -Value $JSONBody.config -Force

                $ProfilesJson | ConvertTo-Json -Depth 5 | Out-File $ProfilesFile -Encoding utf8 -Force
                Load-ProfileContext
                if ($TargetProfile -eq $Global:ActiveProfileName) {
                    Start-AsyncLibraryScanner
                    Start-AutomatedChronDaemon -RuntimePort $TargetPort -LoopInterval $Global:Profile.ChronDaemonSleepSec
                }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"saved"}')
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/profiles/create" -and $Method -eq "POST") {
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $JSONBody = $Reader.ReadToEnd() | ConvertFrom-Json
                $NewName = $JSONBody.profileName
                $ProfilesJson = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
                
                if ($ProfilesJson.profiles.PSObject.Properties.Name -contains $NewName) {
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Profile already exists"}')
                    $Response.StatusCode = 400
                } else {
                    $BaseTemplate = $ProfilesJson.profiles.Default
                    $ProfileConfig = if ($JSONBody.config) { $JSONBody.config } else { $BaseTemplate }
                    $ProfilesJson.profiles | Add-Member -MemberType NoteProperty -Name $NewName -Value $ProfileConfig
                    $ProfilesJson | ConvertTo-Json -Depth 5 | Out-File $ProfilesFile -Encoding utf8 -Force
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"created"}')
                    $Response.StatusCode = 200
                }
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/profiles/delete" -and $Method -eq "POST") {
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $JSONBody = $Reader.ReadToEnd() | ConvertFrom-Json
                $TargetProfile = $JSONBody.profileName
                $ProfilesJson = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
                
                if ($TargetProfile -eq "Default") {
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Cannot delete default system fallback profile"}')
                    $Response.StatusCode = 403
                } elseif ($ProfilesJson.profiles.PSObject.Properties.Name -contains $TargetProfile) {
                    $ProfilesJson.profiles.psobject.properties.Remove($TargetProfile)
                    if ($ProfilesJson.activeProfile -eq $TargetProfile) { $ProfilesJson.activeProfile = "Default" }
                    $ProfilesJson | ConvertTo-Json -Depth 5 | Out-File $ProfilesFile -Encoding utf8 -Force
                    Load-ProfileContext
                    Start-AsyncLibraryScanner
                    Start-AutomatedChronDaemon -RuntimePort $TargetPort -LoopInterval $Global:Profile.ChronDaemonSleepSec
                    
                    $Payload = @{ status = "deleted"; activeProfile = $Global:ActiveProfileName } | ConvertTo-Json
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes($Payload)
                    $Response.StatusCode = 200
                } else {
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Profile not found"}')
                    $Response.StatusCode = 404
                }
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            # -----------------------------
            elseif ($UrlPath -eq "/resolve-song" -and $Method -eq "POST") {
                # (Logic remains same, JSON response is hardcoded so it is safe)
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $Payload = $Reader.ReadToEnd() | ConvertFrom-Json
                $SongId  = $Payload.id; $Action  = $Payload.action; $VideoID = $Payload.videoId

                if ($SongId -and (Test-Path $Global:Profile.BrokenSongsFile)) {
                    $CurrentList = Get-Content -LiteralPath $Global:Profile.BrokenSongsFile -Raw | ConvertFrom-Json
                    $TargetSong = $CurrentList | Where-Object { $_.id -eq $SongId }
                    
                    if ($Action -eq "geo_vpn_fix" -and $TargetSong) {
                        $Global:IsPipelineRunning = $true
                        if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
                        
                        $SingleJobBlock = {
                            param($Log, $Backup, $Cfg, $Vid, $Sid, $DbFile, $HistFile, $YTDLP, $Cookies)
                            $ProtonCLI = "C:\Program Files\Proton\VPN\ProtonVPN.Backend.CLI.exe"
                            
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
                        $Job = Start-Job -Name "ActiveMusicDownloader" -ScriptBlock $SingleJobBlock -ArgumentList $Global:DiagLogFile, $Global:Profile.BackupDir, $ConfigDir, $TargetSong.videoId, $SongId, $Global:Profile.BrokenSongsFile, $Global:Profile.HistoryFile, $Global:Profile.YTDLPExe, $Global:Profile.CookieFile
                        $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"success","message":"Dispatched targeted single VPN route"}')
                    } else {
                        $UpdatedList = $CurrentList | Where-Object { $_.id -ne $SongId }
                        $UpdatedList | ConvertTo-Json -Depth 4 | Out-File -FilePath $Global:Profile.BrokenSongsFile -Encoding utf8 -Force
                        if ($Action -eq "write_history" -and -not [string]::IsNullOrWhiteSpace($VideoID)) {
                            $ArchiveLine = "youtube $VideoID"
                            [System.IO.File]::AppendAllText($Global:Profile.HistoryFile, ($ArchiveLine + [System.Environment]::NewLine))
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
            elseif ($UrlPath -eq "/run-geo-recovery" -and $Method -eq "POST") {
                if ($Global:IsPipelineRunning) {
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Pipeline active"}')
                    $Response.StatusCode = 409
                } else {
                    $Global:IsPipelineRunning = $true
                    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
                    "`e[1;35m[SYSTEM] Initializing Safe Asynchronous ProtonVPN Geo-Recovery Loop...`e[0m" | Out-File -FilePath $Global:DiagLogFile -Encoding utf8

                    $RecoveryJobBlock = {
                        param($Log, $Backup, $Cfg, $DbFile, $YTDLP, $Cookies)
                        function Log-VpnProgress([string]$M) {
                            $T = (Get-Date).ToString("HH:mm:ss")
                            "`e[90m[$T]`e[0m $M" | Out-File -FilePath $Log -Append -Encoding utf8
                        }

                        $ProtonCLI = "C:\Program Files\Proton\VPN\ProtonVPN.Backend.CLI.exe"

                        if (-not (Test-Path $DbFile)) { Log-VpnProgress "🛑 Error database missing."; return }
                        $Db = Get-Content -LiteralPath $DbFile -Raw | ConvertFrom-Json
                        $GeoTracks = $Db | Where-Object { $_.reason -match "available in your country|GeoRestrictedError|not made this video available|sign in to confirm" }

                        if ($null -eq $GeoTracks -or $GeoTracks.Count -eq 0) {
                            Log-VpnProgress "🔍 Clean analytics match. Zero songs are currently blocked behind geo-restrictions."
                            return
                        }

                        Log-VpnProgress "`e[1;33m[*] Routing connection... Forcing USA safe exit node.`e[0m"
                        & $ProtonCLI c --cc US 2>&1 | Out-Null
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
                        & $ProtonCLI d 2>&1 | Out-Null

                        if ($SuccessTracks.Count -gt 0) {
                            $ReloadDb = Get-Content -LiteralPath $DbFile -Raw | ConvertFrom-Json
                            $CleanedDb = $ReloadDb | Where-Object { $SuccessTracks -notcontains $_.videoId }
                            $CleanedDb | ConvertTo-Json -Depth 4 | Out-File -FilePath $DbFile -Encoding utf8 -Force
                            Log-VpnProgress "`e[1;32m[SUCCESS] Removed ($($SuccessTracks.Count)) anomalies from broken_songs.json!`e[0m"
                        }
                    }
                    $Job = Start-Job -Name "ActiveMusicDownloader" -ScriptBlock $RecoveryJobBlock -ArgumentList $Global:DiagLogFile, $Global:Profile.BackupDir, $ConfigDir, $Global:Profile.BrokenSongsFile, $Global:Profile.YTDLPExe, $Global:Profile.CookieFile
                    
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}')
                    $Response.StatusCode = 200
                }
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/analytics" -and $Method -eq "GET") { 
                $RawData = "[]" 
                if (Test-Path $Global:TimingFile) { 
                    try { $RawData = Get-Content -LiteralPath $Global:TimingFile -Raw } catch {}
                } 
                if ([string]::IsNullOrWhiteSpace($RawData)) { $RawData = "[]" }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData) 
                $Response.ContentType = "application/json" 
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/metrics" -and $Method -eq "GET") { 
                $DataPayload = '{"status":"loading","activeProfile":"' + $Global:ActiveProfileName + '"}'
                
                try {
                    if (Test-Path $Global:CacheFile) { 
                        # Open with FileShare.ReadWrite to prevent file-locking crashes
                        $FileStream = [System.IO.File]::Open($Global:CacheFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                        $Reader = New-Object System.IO.StreamReader($FileStream, [System.Text.Encoding]::UTF8)
                        $RawJson = $Reader.ReadToEnd()
                        $Reader.Close()
                        $FileStream.Close()

                        if (-not [string]::IsNullOrWhiteSpace($RawJson)) { 
                            $DataPayload = $RawJson 
                        }
                    }
                    
                    # Parse and inject active profile
                    $JSONObj = $DataPayload | ConvertFrom-Json
                    $JSONObj | Add-Member -Type NoteProperty -Name "activeProfile" -Value $Global:ActiveProfileName -Force
                    $DataPayload = $JSONObj | ConvertTo-Json -Depth 4 -Compress
                } catch {
                    # Silent fail: keep the fallback payload if parsing fails
                }

                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($DataPayload)
                $Response.ContentType = "application/json" 
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
                        $StreamReader.Close(); $FileStream.Close()
                    } catch { $AllLines = @() }

                    if ($AllLines.Count -gt 0 -and $SkipCount -lt $AllLines.Count) {
                        $CurrentLogs = $AllLines[$SkipCount..($AllLines.Count - 1)]
                    }
                } 
                
                $DownloadJob = Get-Job -Name "ActiveMusicDownloader" -ErrorAction SilentlyContinue 
                if ($DownloadJob) {
                    if ($DownloadJob.State -ne "Running") { $Global:IsPipelineRunning = $false; Remove-Job -Job $DownloadJob -Force } 
                } else { $Global:IsPipelineRunning = $false } 

                $JsonPayload = @{ running = $Global:IsPipelineRunning; logs = $CurrentLogs; totalLines = $AllLines.Count } | ConvertTo-Json -Compress 
                if ([string]::IsNullOrWhiteSpace($JsonPayload)) { $JsonPayload = "{}" }
                
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload) 
                $Response.ContentType = "application/json" 
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
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/run" -and $Method -eq "POST") { 
                $IsSweepRequested = $false
                if ($null -ne $Request.Url.Query) { $IsSweepRequested = [bool]($Request.Url.Query -match "sweep=true") }
                
                $RunContext = "Manual" 
                if ($Request.Url.Query -match "type=Automated") { $RunContext = "Automated" } 
                if ($IsSweepRequested) { $RunContext = "Clean Sweep" } 
                
                Invoke-PipelineExecution -CleanSweep $IsSweepRequested -TriggerType $RunContext 
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}') 
                $Response.ContentType = "application/json" 
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
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/pull" -and $Method -eq "POST") { 
                Invoke-HotReload 
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"pulling"}') 
                $Response.ContentType = "application/json" 
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
                $Response.OutputStream.Close() 
                Stop-Process -Id $PID -Force 
            }
            else { 
                $Response.StatusCode = 404 
                try { $Response.OutputStream.Close() } catch {}
            }
        } 
        catch {
            Write-Host "⚠️ Request Error: $_" -ForegroundColor Yellow
            try { $Response.Abort() } catch {}
        }
    }
}
catch {
    # If the Server itself crashes (e.g., port binding failed), kill the script
    Write-Host "🛑 Fatal Server Error: $_" -ForegroundColor Red
}
finally {
    # This always runs, ensuring the listener is closed properly
    if ($null -ne $Listener) { $Listener.Stop(); $Listener.Close() }
    netsh interface portproxy reset
}