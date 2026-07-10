Param (
    [string]$ProfilesFile = "C:\MusicTools\MusicPipeline\Config\profiles.json"
)

# Root System Anchors
$ScriptRepoDir = "C:\MusicTools\MusicPipeline" 
$ScriptDir     = "$ScriptRepoDir\Scripts" 
$ConfigDir     = "$ScriptRepoDir\Config" 
$HtmlFile      = "$ScriptDir\dashboard.html" 

# -----------------------------------------------------------------
# CENTRALIZED SERVER LOGGING ROUTINE (Captures framework output)
# -----------------------------------------------------------------
function Log-Engine([string]$Message, [string]$AnsiStyle = "37") {
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $Payload = "`e[${AnsiStyle}m[$Timestamp] [SERVER] $Message`e[0m"
    
    # 1. Attempt to append to the log file safely
    try {
        $Payload | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 -ErrorAction Stop
    } catch {
        # Fallback silently to terminal if the file is transiently locked or busy
        Write-Host "`e[1;31m[LOG LOCK] Could not write to web stream log file: $_`e[0m"
    }
    
    # 2. Mirror it to your running terminal session so you see it live
    Write-Host $Payload
}


# -----------------------------------------------------------------
# CORE PROFILE INJECTION ENGINE
# -----------------------------------------------------------------
function Load-ProfileContext {
    if (-not (Test-Path $ProfilesFile)) {
        if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force | Out-Null }
        
        # Comprehensive profile matrix template - all presets moved completely into config mapping
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
                    HistoryFile             = "C:\MusicTools\MusicPipeline\Config\history.txt"
                    YTDLPExe                = "C:\MusicTools\MusicPipeline\Tools\yt-dlp.exe"
                    FFmpegExe               = "C:\MusicTools\MusicPipeline\Tools\ffmpeg.exe"
                    FirefoxExe              = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    CheckURL                = "https://www.youtube.com"
                    SleepInterval           = 4
                    MaxSleepInterval        = 12
                    SleepRequests           = 3
                    MaxCompressThreads      = 4
                    MaxDownloadThreads      = 3
                    ScannerSleepIntervalSec = 60
                    ChronDaemonSleepSec     = 60 # Set to 60s to check the automated intervals accurately
                    
                    # Split-Daemon Routing Track Parameters
                    NormalIntervalSec       = 1800     # 30 Minutes
                    CleanIntervalSec        = 604800   # 7 Days
                    
                    NormalStep1             = $true
                    NormalStep2             = $true
                    NormalStep3             = $true
                    NormalStep4             = $true
                    NormalStep5             = $true
                    NormalStep6             = $true
                    
                    CleanSweepDownload      = $false
                    CleanSweepLyrics        = $true
                    CleanSweepCompress      = $true
                    
                    # Core Runtime Milestone State Captures
                    LastNormalRunEpoch      = 0
                    LastCleanRunEpoch       = 0
                    
                    Playlists               = @(
                        "https://www.youtube.com/playlist?list=PLw-VjHDlEOgs658g796bZ69uBfS809GfF"
                    )
                }
            }
        }
        $DefaultTemplate | ConvertTo-Json -Depth 5 | Out-File $ProfilesFile -Encoding utf8 -Force
    }

    try {
        $Global:ProfileData = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
        $Active = $Global:ProfileData.activeProfile
        $Global:ActiveConfig = $Global:ProfileData.profiles.$Active

        # Context-mapping active configurations down into script runspace memory references
        $Global:BackupDir               = $Global:ActiveConfig.BackupDir
        $Global:MobileDir               = $Global:ActiveConfig.MobileDir
        $Global:BrokenSongsFile         = $Global:ActiveConfig.BrokenSongsFile
        $Global:DiagLogFile             = $Global:ActiveConfig.DiagLogFile
        $Global:CacheFile               = $Global:ActiveConfig.CacheFile
        $Global:TimingFile              = $Global:ActiveConfig.TimingFile
        $Global:CookieFile              = $Global:ActiveConfig.CookieFile
        $Global:HistoryFile             = $Global:ActiveConfig.HistoryFile
        $Global:YTDLPExe                = $Global:ActiveConfig.YTDLPExe
        $Global:FFmpegExe               = $Global:ActiveConfig.FFmpegExe
        $Global:FirefoxExe              = $Global:ActiveConfig.FirefoxExe
        $Global:CheckURL                = $Global:ActiveConfig.CheckURL
        $Global:SleepInterval           = $Global:ActiveConfig.SleepInterval
        $Global:MaxSleepInterval        = $Global:ActiveConfig.MaxSleepInterval
        $Global:SleepRequests           = $Global:ActiveConfig.SleepRequests
        $Global:MaxCompressThreads      = $Global:ActiveConfig.MaxCompressThreads
        $Global:MaxDownloadThreads      = $Global:ActiveConfig.MaxDownloadThreads
        $Global:ScannerSleepIntervalSec = $Global:ActiveConfig.ScannerSleepIntervalSec
        $Global:ChronDaemonSleepSec     = $Global:ActiveConfig.ChronDaemonSleepSec
        
        # Global variable mappings for new splits
        $Global:NormalIntervalSec       = $Global:ActiveConfig.NormalIntervalSec
        $Global:CleanIntervalSec        = $Global:ActiveConfig.CleanIntervalSec
        
        $Global:Profile                 = $Global:ActiveConfig

        Log-Engine "Loaded configuration profile: [$Active]" "32"
    }
    catch {
        Log-Engine "🛑 Critical breakdown loading profiles json architecture context: $_" "1;31"
        Exit 1
    }
}
# Initial Context Engine Boot up Sequence
Load-ProfileContext
$Global:IsPipelineRunning = $false

# Ensure the config directory exists before trying to write logs
if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force | Out-Null } 
if (-not (Test-Path $Global:TimingFile)) { "[]" | Out-File $Global:TimingFile -Encoding utf8 } 

# Append a session initialization marker instead of deleting the file
"`n`e[1;32m[SYSTEM] Website Engine Core Session Initialized.`e[0m" | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8




$Global:CachedMetrics = @{
    masterCount  = 0; mobileCount = 0; lrcCount = 0 
    masterSize   = 0; mobileSize  = 0; alerts = @() 
    loadingState = "scanning"; tracks = @() 
}

# Universal Global Hashing Function
function Get-TrackUUID([string]$Artist, [string]$Album, [string]$Title) {
    $RawIdentity = "$Artist-$Album-$Title".ToLower().Trim()
    $Hasher = [System.Security.Cryptography.SHA256]::Create()
    $HashBytes = $Hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RawIdentity))
    $FullHash = [System.BitConverter]::ToString($HashBytes).Replace("-", "").ToLower()
    return $FullHash.Substring(0, 32)
}

# -----------------------------------------------------------------
# 1. ROBUST BACKGROUND SCANNER & AUTOMATION ENGINE (SHA-2 COMPLIANT)
# -----------------------------------------------------------------
function Start-AsyncLibraryScanner {
    Get-Job -Name "MusicFolderScanner" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue 

    $JobScript = {
        param($BDir, $MDir, $RDir, $CFile, $ScanDelay)
        
        # Core deterministic hashing engine injected directly into local thread runspace
        function Get-TrackUUID([string]$Artist, [string]$Album, [string]$Title) {
            $RawIdentity = "$Artist-$Album-$Title".ToLower().Trim()
            $Hasher = [System.Security.Cryptography.SHA256]::Create()
            $HashBytes = $Hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RawIdentity))
            $FullHash = [System.BitConverter]::ToString($HashBytes).Replace("-", "").ToLower()
            return $FullHash.Substring(0, 32)
        }
        
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

                $PermanentUUID = Get-TrackUUID -Artist $Artist -Album $Album -Title $File.BaseName

                $TrackDatabase += @{ 
                    id             = [string]$PermanentUUID
                    title          = [string]$File.BaseName 
                    artist         = [string]$Artist 
                    album          = [string]$Album 
                    sizeMb         = [Math]::Round(($File.Length / 1MB), 2) 
                    hasLrc         = [bool](Test-Path -LiteralPath "$($File.DirectoryName)\$($File.BaseName).lrc" -ErrorAction SilentlyContinue) 
                    isInstrumental = $IsInstrumentalTrack
                    type           = [string]$File.Extension.ToUpper().Replace('.','') 
                }

                if ($TrackDatabase.Count % 150 -eq 0) { 
                    $TempFile = "$CFile.tmp"
                    @{
                        masterCount  = $MasterFiles.Count 
                        mobileCount  = $MobileFiles.Count 
                        lrcCount     = $LrcFiles.Count 
                        masterSize   = [Math]::Round($MasterSize, 2) 
                        mobileSize   = [Math]::Round($MobileSize, 2) 
                        alerts       = @() 
                        loadingState = "scanning" 
                        tracks       = $TrackDatabase 
                    } | ConvertTo-Json -Depth 4 | Out-File -FilePath $TempFile -Encoding utf8 -Force 
                    
                    Move-Item -Path $TempFile -Destination $CFile -Force
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

            $TempFile = "$CFile.tmp"
            @{
                masterCount  = $MasterFiles.Count 
                mobileCount  = $MobileFiles.Count 
                lrcCount     = $LrcFiles.Count 
                masterSize   = [Math]::Round($MasterSize, 2) 
                mobileSize   = [Math]::Round($MobileSize, 2) 
                alerts       = $Alerts 
                loadingState = "idle" 
                tracks       = $TrackDatabase 
            } | ConvertTo-Json -Depth 4 | Out-File -FilePath $TempFile -Encoding utf8 -Force 

            Move-Item -Path $TempFile -Destination $CFile -Force
            Start-Sleep -Seconds $ScanDelay
        }
    }

    $Job = Start-Job -Name "MusicFolderScanner" -ScriptBlock $JobScript -ArgumentList $Global:Profile.BackupDir, $Global:Profile.MobileDir, $ScriptRepoDir, $Global:CacheFile, $Global:Profile.ScannerSleepIntervalSec
}

function Start-AutomatedChronDaemon {
    param($RuntimePort, $LoopInterval)
    Get-Job -Name "ChronDaemon" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue 
    
    $ChronScript = {
        param($TargetPort, $Delay, $PFile)
        
        while ($true) {
            # Sleep step interval tracking loops
            Start-Sleep -Seconds $Delay 
            
            if (-not (Test-Path $PFile)) { continue }
            
            try {
                # Load profile details dynamically to match config alterations on the fly
                $Raw = Get-Content -LiteralPath $PFile -Raw | ConvertFrom-Json
                $Act = $Raw.activeProfile
                $Prof = $Raw.profiles.$Act
                
                $CurrentEpoch = [DateTimeOffset]::Now.ToUnixTimeSeconds()
                
                # Fetch relative calculation checkpoints out of configuration properties
                $LastNormal = if ($Prof.LastNormalRunEpoch) { [long]$Prof.LastNormalRunEpoch } else { 0 }
                $LastClean  = if ($Prof.LastCleanRunEpoch) { [long]$Prof.LastCleanRunEpoch } else { 0 }
                
                $IntervalNormal = if ($Prof.NormalIntervalSec) { [long]$Prof.NormalIntervalSec } else { 1800 }
                $IntervalClean  = if ($Prof.CleanIntervalSec) { [long]$Prof.CleanIntervalSec } else { 604800 }
                
                $TriggerClean  = ($CurrentEpoch - $LastClean) -ge $IntervalClean
                $TriggerNormal = ($CurrentEpoch - $LastNormal) -ge $IntervalNormal
                
                if ($TriggerClean) {
                    $URI = "http://127.0.0.1:$TargetPort/run?type=AutomatedClean" +
                           "&cleanDownload=$($Prof.CleanSweepDownload)" +
                           "&cleanLyrics=$($Prof.CleanSweepLyrics)" +
                           "&cleanCompress=$($Prof.CleanSweepCompress)"
                           
                    Invoke-RestMethod -Uri $URI -Method Post | Out-Null
                }
                elseif ($TriggerNormal) {
                    # Map structural inversion parameters directly relative to checkbox configuration settings
                    $Skip1 = if ($Prof.NormalStep1 -eq $true) { "false" } else { "true" }
                    $Skip2 = if ($Prof.NormalStep2 -eq $true) { "false" } else { "true" }
                    $Skip3 = if ($Prof.NormalStep3 -eq $true) { "false" } else { "true" }
                    $Skip4 = if ($Prof.NormalStep4 -eq $true) { "false" } else { "true" }
                    $Skip5 = if ($Prof.NormalStep5 -eq $true) { "false" } else { "true" }
                    $Skip6 = if ($Prof.NormalStep6 -eq $true) { "false" } else { "true" }
                    
                    $URI = "http://127.0.0.1:$TargetPort/run?type=AutomatedNormal" +
                           "&skip1=$Skip1&skip2=$Skip2&skip3=$Skip3&skip4=$Skip4&skip5=$Skip5&skip6=$Skip6"
                           
                    Invoke-RestMethod -Uri $URI -Method Post | Out-Null
                }
            } 
            catch {
                # Safeguard against structural engine dropouts
            }
        }
    }
    # Track execution checks every minute (60s) to securely map scheduled tracks
    $Job = Start-Job -Name "ChronDaemon" -ScriptBlock $ChronScript -ArgumentList $RuntimePort, 60, $ProfilesFile 
}

# -----------------------------------------------------------------
# 2. PROCESS MANAGEMENT & PERFORMANCE PARSER
# -----------------------------------------------------------------
function Invoke-PipelineExecution {
    param(
        [bool]$CleanSweep = $false,
        [string]$TriggerType = "Manual",
        [bool]$SkipStep1 = $false,
        [bool]$SkipStep2 = $false,
        [bool]$SkipStep3 = $false,
        [bool]$SkipStep4 = $false,
        [bool]$SkipStep5 = $false,
        [bool]$SkipStep6 = $false,
        [bool]$CleanSweepDownload = $false,
        [bool]$CleanSweepLyrics = $false,
        [bool]$CleanSweepCompress = $false
    )

    if ($Global:IsPipelineRunning) { return } 
    $Global:IsPipelineRunning = $true 
    
    "`n`e[1;35m=================================================================`e[0m" |
        Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 
    "`e[1;36m[SYSTEM] ($TriggerType Run) Initializing Custom Sequence Flow Framework...`e[0m" |
        Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 

    # If the user hit the default global Clean Sweep button, pass it along down to step 2's parameter fallback explicitly
    $EffectiveCleanDownload = if ($CleanSweep) { $true } else { $CleanSweepDownload }

    $ContextBundle = @{
        ScriptDir          = $ScriptDir 
        ConfigDir          = $ConfigDir 
        CacheDir           = Join-Path $ConfigDir ".cache" 
        BackupDir          = $Global:Profile.BackupDir 
        MobileDir          = $Global:Profile.MobileDir 
        CookieFile         = $Global:Profile.CookieFile 
        HistoryFile        = $Global:Profile.HistoryFile 
        YTDLPExe           = $Global:Profile.YTDLPExe 
        FFmpegExe          = $Global:Profile.FFmpegExe 
        FirefoxExe         = $Global:Profile.FirefoxExe 
        CheckURL           = $Global:Profile.CheckURL 
        Playlists          = @($Global:Profile.Playlists) 
        SleepInterval      = [int]$Global:Profile.SleepInterval 
        MaxSleepInterval   = [int]$Global:Profile.MaxSleepInterval 
        SleepRequests      = [int]$Global:Profile.SleepRequests 
        MaxCompressThreads = [int]$Global:Profile.MaxCompressThreads 
        MaxDownloadThreads = [int]$Global:Profile.MaxDownloadThreads 
        
        # New Execution Controller Directives
        SkipStep1          = $SkipStep1
        SkipStep2          = $SkipStep2
        SkipStep3          = $SkipStep3
        SkipStep4          = $SkipStep4
        SkipStep5          = $SkipStep5
        SkipStep6          = $SkipStep6
        CleanDownload      = $EffectiveCleanDownload
        CleanLyrics        = $CleanSweepLyrics
        CleanCompress      = $CleanSweepCompress
        
        LogFile            = $Global:DiagLogFile 
        TimingFile         = $Global:TimingFile 
        RunType            = $TriggerType 
    }

    $MasterPipelineJob = {
        param($EnvMap)

        #$env:PYTHONUNBUFFERED = "1" 
        $env:YTDLP_UNBUFFERED = "1" 
        $ProgressPreference = 'SilentlyContinue'


        function Log-Progress([string]$Msg) {
            $Timestamp = (Get-Date).ToString("HH:mm:ss") 
            "`e[90m[$Timestamp]`e[0m $Msg" | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
        }

        $OverallStopwatch = [System.Diagnostics.Stopwatch]::StartNew() 

        try {
            if (-not $EnvMap.SkipStep1) {
                Log-Progress "`e[1;33m[STEP 1/6]`e[0m Running Cookie Validation..." 
                $S1Watch = [System.Diagnostics.Stopwatch]::StartNew() 
                $S1ScriptPath = Join-Path $EnvMap.ScriptDir "CookieCheck.ps1" 
                if (Test-Path $S1ScriptPath) {
                    $S1Params = @{ CookiePath = $EnvMap.CookieFile; YTDLPPath = $EnvMap.YTDLPExe; TestURL = $EnvMap.CheckURL } 
                    $Step1Result = & $S1ScriptPath @S1Params 2>&1 
                    $Step1Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
                } else { Log-Progress "⚠️ CookieCheck.ps1 missing. Skipping." }
                $S1Watch.Stop()
                $S1Time = [string]::Format("{0:hh\:mm\:ss}", $S1Watch.Elapsed) 
            } else { Log-Progress "`e[90m[STEP 1/6] Explicitly bypassed via step toggle directive.`e[0m"; $S1Time = "00:00:00" }
            if (-not $EnvMap.SkipStep2) {
                Log-Progress "`e[1;33m[STEP 2/6]`e[0m Running Native Pipeline Downloader..." 
                $S2Watch = [System.Diagnostics.Stopwatch]::StartNew() 
                $S2ScriptPath = Join-Path $EnvMap.ScriptDir "Download.ps1" 
                if (Test-Path $S2ScriptPath) {
                    $S2Params = @{
                        BackupDir           = $EnvMap.BackupDir 
                        YTDLPPath           = $EnvMap.YTDLPExe 
                        CookiePath          = $EnvMap.CookieFile 
                        HistoryPath         = $EnvMap.HistoryFile 
                        PlaylistURLs        = $EnvMap.Playlists 
                        ConfigDir           = $EnvMap.ConfigDir 
                        CacheDir            = $EnvMap.CacheDir
                        SleepInterval       = $EnvMap.SleepInterval 
                        MaxSleepInterval    = $EnvMap.MaxSleepInterval 
                        SleepRequests       = $EnvMap.SleepRequests
                        MaxDownloadThreads  = $EnvMap.MaxDownloadThreads
                        CleanSweep          = $EnvMap.CleanDownload
                    }
                    & $S2ScriptPath @S2Params 2>&1 
                } else { Log-Progress "⚠️ Download.ps1 missing. Skipping." }
                $S2Watch.Stop()
                $S2Time = [string]::Format("{0:hh\:mm\:ss}", $S2Watch.Elapsed) 
            } else { Log-Progress "`e[90m[STEP 2/6] Explicitly bypassed via step toggle directive.`e[0m"; $S2Time = "00:00:00" }
            if (-not $EnvMap.SkipStep3) {
                Log-Progress "`e[1;33m[STEP 3/6]`e[0m Running Error Log Analysis..." 
                $S3Watch = [System.Diagnostics.Stopwatch]::StartNew() 
                $S3ScriptPath = Join-Path $EnvMap.ScriptDir "Fix.ps1" 
                if (Test-Path $S3ScriptPath) {
                    $S3Params = @{ ConfigDir = $EnvMap.ConfigDir; HistoryPath = $EnvMap.HistoryFile; FirefoxPath = $EnvMap.FirefoxExe; GlobalLogFile = $EnvMap.LogFile } 
                    & $S3ScriptPath @S3Params 2>&1 | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8
                } else { Log-Progress "⚠️ Fix.ps1 missing. Skipping." }
                $S3Watch.Stop()
                $S3Time = [string]::Format("{0:hh\:mm\:ss}", $S3Watch.Elapsed) 
            } else { Log-Progress "`e[90m[STEP 3/6] Explicitly bypassed via step toggle directive.`e[0m"; $S3Time = "00:00:00" }
            if (-not $EnvMap.SkipStep4) {
                Log-Progress "`e[1;33m[STEP 4/6]`e[0m Syncing Local Lyrics Databases..." 
                $S4Watch = [System.Diagnostics.Stopwatch]::StartNew() 
                $S4ScriptPath = Join-Path $EnvMap.ScriptDir "Lyrics.ps1" 
                if (Test-Path $S4ScriptPath) {
                    $S4Params = @{ BackupDir = $EnvMap.BackupDir }
                    if ($EnvMap.CleanLyrics) { $S4Params.ForceFullRefresh = $true } 
                    & $S4ScriptPath @S4Params 2>&1 
                } else { Log-Progress "⚠️ Lyrics.ps1 missing. Skipping." }
                $S4Watch.Stop()
                $S4Time = [string]::Format("{0:hh\:mm\:ss}", $S4Watch.Elapsed) 
            } else { Log-Progress "`e[90m[STEP 4/6] Explicitly bypassed via step toggle directive.`e[0m"; $S4Time = "00:00:00" }
            if (-not $EnvMap.SkipStep5) {
                Log-Progress "`e[1;35m[STEP 5/6]`e[0m Syncing and Compressing Mobile M4A Library Track Array..."
                $S5Watch = [System.Diagnostics.Stopwatch]::StartNew()
                $S5ScriptPath = Join-Path $EnvMap.ScriptDir "CompressMusic.ps1"
                
                if (Test-Path $S5ScriptPath) {
                    $S5Params = @{
                        BackupDir        = $EnvMap.BackupDir
                        MobileDir        = $EnvMap.MobileDir
                        FFmpegPath       = $EnvMap.FFmpegExe
                        MaxThreads       = [int]$EnvMap.CompressThreads
                        ForceCleanSweep  = [bool]$EnvMap.CleanSweepCompress
                    }
                    
                    # Execute compressor engine with non-destructive tracking arguments
                    & $S5ScriptPath @S5Params 2>&1 | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8
                } else {
                    Log-Progress "⚠️ CompressMusic.ps1 missing. Skipping."
                }
                $S5Watch.Stop()
                $S5Time = [string]::Format("{0:hh\:mm\:ss}", $S5Watch.Elapsed)
            } else {Log-Progress "`e[90m[STEP 5/6] Disabled by explicit configuration profile bypass.`e[0m"
            $S5Time = "00:00:00"}
            if (-not $EnvMap.SkipStep6) {
                Log-Progress "`e[1;33m[STEP 6/6]`e[0m Compiling Track Telemetry & Analytics..." 
                $S6Watch = [System.Diagnostics.Stopwatch]::StartNew() 
                $S6ScriptPath = Join-Path $EnvMap.ScriptDir "Metrics.ps1" 
                if (Test-Path $S6ScriptPath) { 
                    $S6Params = @{ LogPath = $EnvMap.LogFile; DatabasePath = Join-Path $EnvMap.ConfigDir "track_history.json"; RunId = (Get-Date).ToString("yyyyMMdd_HHmmss") } 
                    $Step6Result = & $S6ScriptPath @S6Params 2>&1 
                    $Step6Result | Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 
                } else { Log-Progress "⚠️ Metrics.ps1 missing. Skipping." } 
                $S6Watch.Stop() 
                $S6Time = [string]::Format("{0:hh\:mm\:ss}", $S6Watch.Elapsed) 
            } else { Log-Progress "`e[90m[STEP 6/6] Explicitly bypassed via step toggle directive.`e[0m"; $S6Time = "00:00:00" }

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
                step1     = $S1Time; step2 = $S2Time; step3 = $S3Time; step4 = $S4Time; step5 = $S5Time; step6 = $S6Time
                total     = $TotalTime 
            }
            $HistoryDB += $NewMetricRecord 
            $HistoryDB | ConvertTo-Json -Depth 4 | Out-File -FilePath $EnvMap.TimingFile -Encoding utf8 -Force 
        }
        catch { Log-Progress "`e[1;31m[CRITICAL ERROR] Pipeline execution collapsed: $_`e[0m" }
    }

    $Job = Start-ThreadJob -Name "ActiveMusicDownloader" -ScriptBlock $MasterPipelineJob -ArgumentList $ContextBundle 
}

function Invoke-HotReload {
    "`n`e[1;35m=================================================================`e[0m" | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8
    "`e[1;35m[SYSTEM] Hot-reload triggered. Checking for remote updates...`e[0m" | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 
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

# 🟢 Memory Salvage: Clear out any heavy historical errors pinned in the console memory
$Error.Clear()
[System.GC]::Collect()

Log-Engine "🧼 Flushing old proxy tables and cleaning session jobs..." "33"
netsh interface portproxy reset | Out-Null 
Get-Job -Name "MusicFolderScanner","ChronDaemon","ActiveMusicDownloader" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue 

$TargetPort = 49152 
while ($true) { 
    $Conflict = Get-NetTCPConnection -LocalPort $TargetPort -ErrorAction SilentlyContinue 
    if (-not $Conflict) { break } 
    $TargetPort++ 
}

# Wrap the ENTIRE initialization routine in a safe, memory-insulated try block
try {
    Log-Engine "🔗 Aligning fresh Windows port proxy map: 80 ---> $TargetPort" "36"
    
    # Track exit code safely without letting a heavy error stream build up
    $NetshOut = netsh interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=$TargetPort connectaddress=127.0.0.1 2>&1
    if ($LASTEXITCODE -ne 0) { throw "netsh registration failed: $NetshOut" }

    $Listener = New-Object System.Net.HttpListener 
    $Listener.Prefixes.Add("http://127.0.0.1:$TargetPort/") 
    $Listener.Start() 

    $LocalIPs = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi','Ethernet' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress 
    $PrimaryIP = if ($LocalIPs) { $LocalIPs[0] } else { "127.0.0.1" } 

    Log-Engine "--------------------------------------------------" "32" 
    Log-Engine " SERVER LIVE AND ADAPTIVELY MAPPED!" "1;32"
    Log-Engine " Internal Endpoint : http://127.0.0.1:$TargetPort/" "32" 
    Log-Engine " Clean Browser URL : http://$PrimaryIP/" "32" 
    Log-Engine "--------------------------------------------------" "32" 
    
    Start-AsyncLibraryScanner 
    Start-AutomatedChronDaemon -RuntimePort $TargetPort -LoopInterval $Global:Profile.ChronDaemonSleepSec
    
    # --- FIXED: STATEFUL ASYNCHRONOUS ENGINE LOOP ---
    $AsyncResult = $null
    while ($true) {
        try {
            # Only allocate a fresh async request context if we aren't already waiting on one
            if ($null -eq $AsyncResult) {
                $AsyncResult = $Listener.BeginGetContext($null, $null)
            }
            
            # Non-blocking pause: wait up to 1 second for a new request.
            # If no request hits, drop out and stay responsive to process kills/signals,
            # but keep the active handle intact for the next loop pass!
            if (-not $AsyncResult.AsyncWaitHandle.WaitOne(1000)) {
                continue
            }

            # A connection landed! Consume the handle and clear the tracking variable
            $Context = $Listener.EndGetContext($AsyncResult) 
            $AsyncResult = $null
            
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
            elseif ($UrlPath -eq "favicon.ico") {
                $Response.StatusCode = 404
                $Response.OutputStream.Close()
                continue
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
                $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                $Payload = $Reader.ReadToEnd() | ConvertFrom-Json
                $SongId  = $Payload.id; $Action  = $Payload.action; $VideoID = $Payload.videoId

                if ($SongId -and (Test-Path $Global:Profile.BrokenSongsFile)) {
                    $CurrentList = Get-Content -LiteralPath $Global:Profile.BrokenSongsFile -Raw | ConvertFrom-Json
                    $TargetSong = $CurrentList | Where-Object { $_.id -eq $SongId }
                    
                    if ($Action -eq "geo_vpn_fix" -and $TargetSong) {
                        $Global:IsPipelineRunning = $true
                        
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
                    "`e[1;35m[SYSTEM] Initializing Safe Asynchronous ProtonVPN Geo-Recovery Loop...`e[0m" | Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8

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
                if ($null -eq $RawData -or [string]::IsNullOrWhiteSpace($RawData)) { $RawData = "[]" }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData) 
                $Response.ContentType = "application/json" 
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/track-metrics" -and $Method -eq "GET") { 
                $RawData = "[]"
                $MetricsFile = Join-Path $ConfigDir "track_history.json"
                if (Test-Path $MetricsFile) { 
                    try { $RawData = Get-Content -LiteralPath $MetricsFile -Raw -ErrorAction SilentlyContinue } catch {}
                }
                if ($null -eq $RawData -or [string]::IsNullOrWhiteSpace($RawData)) { $RawData = "[]" }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData)
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            # =================================================================
            # PASSTHROUGH LIVE METRICS WITH DYNAMIC FILE CEILING WARNING
            # =================================================================
            elseif ($UrlPath -eq "/metrics" -and $Method -eq "GET") { 
                $Response.ContentType = "application/json"
                
                $MetricsObj = [ordered]@{
                    activeProfile = if ($Global:ActiveProfile) { $Global:ActiveProfile } else { "Default" }
                    masterCount   = 0
                    masterSize    = "0.00"
                    mobileCount   = 0
                    mobileSize    = "0.00"
                    lrcCount      = 0
                    alerts        = @()
                }

                if (Test-Path $Global:CacheFile) {
                    $RawPayload = Get-Content -LiteralPath $Global:CacheFile -Raw -ErrorAction SilentlyContinue
                    if (-not [string]::IsNullOrWhiteSpace($RawPayload)) {
                        try {
                            $CacheObj = $RawPayload | ConvertFrom-Json
                            foreach ($Prop in $CacheObj.psobject.Properties) {
                                if ($Prop.Name -ne "tracks" -and $null -ne $Prop.Value) {
                                    $MetricsObj[$Prop.Name] = $Prop.Value
                                }
                            }
                        } catch {}
                    }
                }

                # Robust Array casting to handle nested property translation safely
                if ($null -eq $MetricsObj["alerts"]) {
                    $MetricsObj["alerts"] = @()
                } else {
                    $MetricsObj["alerts"] = @($MetricsObj["alerts"])
                }

                # --- 512MB PASSIVE CONSOLE WARNING CEILING ---
                if (Test-Path $Global:DiagLogFile) {
                    $LogSizeBytes = (Get-Item -LiteralPath $Global:DiagLogFile).Length
                    if ($LogSizeBytes -gt 512MB) {
                        $LogSizeMb = [Math]::Round(($LogSizeBytes / 1MB), 2)
                        $MetricsObj["alerts"] += @{
                            type      = "warning"
                            message   = "Log Size Alert: web_console_stream.log has reached ${LogSizeMb}MB (Exceeds 512MB baseline)."
                            fixAction = "clear_logs"
                        }
                    }
                }

                $MetricsObj["activeProfile"] = if ($Global:ActiveProfile) { $Global:ActiveProfile } else { "Default" }

                $DataPayload = $MetricsObj | ConvertTo-Json -Depth 4 -Compress
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($DataPayload)
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            # -----------------------------
            elseif ($UrlPath -eq "/tracks" -and $Method -eq "GET") {
                $Response.ContentType = "application/json"
                $DataPayload = "{}"
                if (Test-Path $Global:CacheFile) {
                    $RawPayload = Get-Content -LiteralPath $Global:CacheFile -Raw -ErrorAction SilentlyContinue
                    try {
                        $CacheObj = $RawPayload | ConvertFrom-Json
                        $DataPayload = @{ tracks = $CacheObj.tracks } | ConvertTo-Json -Depth 4 -Compress
                    } catch { $DataPayload = "{}" }
                }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($DataPayload)
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                $Response.OutputStream.Close()
            }
            
            # --- FIXED: ULTRA HIGH PERFORMANCE INGESTION ENDPOINT ---
            elseif ($UrlPath -eq "/stream" -and $Method -eq "GET") { 
                $CurrentLogs = @()
                $SkipCount = 0
                if ($Request.Url.Query -match "skip=(\d+)") { $SkipCount = [int]$Matches[1] }

                $TotalLinesCount = 0
                $NextPointer = $SkipCount

                if (Test-Path $Global:DiagLogFile) { 
                    try {
                        # Open via shared file stream to handle parallel background pipeline writes safely
                        $FileStream = [System.IO.File]::Open($Global:DiagLogFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                        $StreamReader = New-Object System.IO.StreamReader($FileStream, [System.Text.Encoding]::UTF8)
                        
                        # Optimization: Avoid the O(N^2) line-by-line loop array append operation. Read bulk, split instantly.
                        $FullStringContent = $StreamReader.ReadToEnd()
                        $StreamReader.Close(); $FileStream.Close()
                        
                        if (-not [string]::IsNullOrEmpty($FullStringContent)) {
                            $AllLines = $FullStringContent -split "`r?`n"
                            $TotalLinesCount = $AllLines.Count
                            
                            if ($TotalLinesCount -gt 0 -and $SkipCount -lt $TotalLinesCount) {
                                # FIX: Cap the return payload to 3000 lines max.
                                # This keeps JSON serialization instant and eliminates network socket timeouts.
                                $MaxLinesToReturn = 3000
                                $EndIndex = [math]::Min(($TotalLinesCount - 1), ($SkipCount + $MaxLinesToReturn - 1))
                                
                                $CurrentLogs = $AllLines[$SkipCount..$EndIndex]
                                
                                # Advance the pointer to the end of this batch so the client catches up incrementally
                                $NextPointer = $EndIndex + 1
                            } else {
                                $NextPointer = $TotalLinesCount
                            }
                        }
                    } catch { 
                        $CurrentLogs = @() 
                        $TotalLinesCount = 0
                        $NextPointer = $SkipCount
                    }
                } 
                
                $DownloadJob = Get-Job -Name "ActiveMusicDownloader" -ErrorAction SilentlyContinue 
                if ($DownloadJob) {
                    if ($DownloadJob.State -in @("Completed", "Failed", "Stopped")) { 
                        $Global:IsPipelineRunning = $false
                        Remove-Job -Job $DownloadJob -Force 
                    } else {
                        $Global:IsPipelineRunning = $true
                    }
                } else { 
                    $Global:IsPipelineRunning = $false 
                } 

                # FIX: Pass $NextPointer as totalLines. 
                # Your frontend JS uses data.totalLines to set its next skip parameter,
                # meaning it will now gracefully page through huge backlogs 300 lines at a time every 1.2s!
                $JsonPayload = @{ running = $Global:IsPipelineRunning; logs = $CurrentLogs; totalLines = $NextPointer } | ConvertTo-Json -Compress 
                if ([string]::IsNullOrWhiteSpace($JsonPayload)) { $JsonPayload = "{}" }
                
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload) 
                $Response.ContentType = "application/json" 
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
                $Response.OutputStream.Close()
            }
            elseif ($UrlPath -eq "/clear-logs" -and $Method -eq "POST") { 
                try {
                    # Force overwrite with a clean initialization marker instead of clearing content raw
                    "`e[1;36m[SYSTEM] Console logs manually cleared.`e[0m" | Out-File -FilePath $Global:DiagLogFile -Encoding utf8 -Force -ErrorAction Stop 
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
            # --- CONTEXT AUTOMATION & SCHEDULING DISPATCH DEPLOYMENT ROUTER ---
            elseif ($UrlPath.StartsWith("/run") -and $Method -eq "POST") { 
                if ($Global:IsPipelineRunning) {
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Pipeline engine is currently locked in an active run state."}')
                    $Response.StatusCode = 423
                    $Response.ContentType = "application/json"
                    $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
                    $Response.OutputStream.Close()
                    continue
                }

                # Extract URL parameters manually from query string inputs
                $QueryString = $Request.Url.Query
                $Params = @{}
                if (-not [string]::IsNullOrEmpty($QueryString)) {
                    $QueryString.TrimStart('?').Split('&') | ForEach-Object {
                        $Pair = $_.Split('=')
                        if ($Pair.Count -eq 2) { $Params[$Pair[0]] = [System.Web.HttpUtility]::UrlDecode($Pair[1]) }
                    }
                }

                $RunContext = if ($Params.ContainsKey("type")) { $Params["type"] } else { "Manual" }
                
                $IsSweepRequested  = [bool]($Params["sweep"] -eq "true")
                $SkipStep1         = [bool]($Params["skip1"] -eq "true")
                $SkipStep2         = [bool]($Params["skip2"] -eq "true")
                $SkipStep3         = [bool]($Params["skip3"] -eq "true")
                $SkipStep4         = [bool]($Params["skip4"] -eq "true")
                $SkipStep5         = [bool]($Params["skip5"] -eq "true")
                $SkipStep6         = [bool]($Params["skip6"] -eq "true")
                
                $CleanDownload     = [bool]($Params["cleanDownload"] -eq "true")
                $CleanLyrics       = [bool]($Params["cleanLyrics"] -eq "true")
                $CleanCompress     = [bool]($Params["cleanCompress"] -eq "true")

                # Asynchronously pass the parameters down to execution pipelines
                Invoke-PipelineExecution -TriggerType $RunContext `
                                         -CleanSweep $IsSweepRequested `
                                         -SkipStep1 $SkipStep1 -SkipStep2 $SkipStep2 -SkipStep3 $SkipStep3 `
                                         -SkipStep4 $SkipStep4 -SkipStep5 $SkipStep5 -SkipStep6 $SkipStep6 `
                                         -CleanSweepDownload $CleanDownload `
                                         -CleanSweepLyrics $CleanLyrics `
                                         -CleanSweepCompress $CleanCompress

                # Persist execution completion timestamps right back inside profiles data layout configurations
                try {
                    $RawConfig = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
                    $Act = $RawConfig.activeProfile
                    $CurrentEpoch = [DateTimeOffset]::Now.ToUnixTimeSeconds()

                    if ($RunContext -eq "AutomatedNormal") {
                        # REPLACE THE OLD DOT ASSIGNMENT WITH THIS:
                        $RawConfig.profiles.$Act | Add-Member -MemberType NoteProperty -Name "LastNormalRunEpoch" -Value $CurrentEpoch -Force
                        Log-Engine "⏰ Timed tracking anchor updated successfully for Normal Routine Track Run." "36"
                    }
                    elseif ($RunContext -eq "AutomatedClean") {
                        # REPLACE THE OLD DOT ASSIGNMENT WITH THIS:
                        $RawConfig.profiles.$Act | Add-Member -MemberType NoteProperty -Name "LastCleanRunEpoch" -Value $CurrentEpoch -Force
                        Log-Engine "🧹 Timed tracking anchor updated successfully for Maintenance Clean Sweep Run." "35"
                    }

                    $RawConfig | ConvertTo-Json -Depth 5 | Out-File $ProfilesFile -Encoding utf8 -Force
                    Load-ProfileContext
                }
                catch {
                    Log-Engine "⚠️ Failed to sync running epoch tracking markers back to profiles json array storage: $_" "33"
                }

                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched","mode":"' + $RunContext + '"}') 
                $Response.ContentType = "application/json" 
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length) 
                $Response.OutputStream.Close()
            }
            # --- TARGETED CUSTOM CONFIGURATION RUNTIME ENDPOINT ---
            elseif ($UrlPath -eq "/run-custom" -and $Method -eq "POST") {
                if ($Global:IsPipelineRunning) {
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Pipeline engine is currently locked in an active run state."}')
                    $Response.StatusCode = 423
                } else {
                    $Reader = New-Object System.IO.StreamReader($Request.InputStream)
                    $JSONPayload = $Reader.ReadToEnd() | ConvertFrom-Json
                    
                    $CustomRuntimeContext = @{
                        TriggerType        = "Custom"
                        SkipStep1          = [bool](-not $JSONPayload.steps.s1)
                        SkipStep2          = [bool](-not $JSONPayload.steps.s2)
                        SkipStep3          = [bool](-not $JSONPayload.steps.s3)
                        SkipStep4          = [bool](-not $JSONPayload.steps.s4)
                        SkipStep5          = [bool](-not $JSONPayload.steps.s5)
                        SkipStep6          = [bool](-not $JSONPayload.steps.s6)
                        CleanSweepDownload = [bool]($JSONPayload.cleanModes.s2)
                        CleanSweepLyrics   = [bool]($JSONPayload.cleanModes.s4)
                        CleanSweepCompress = [bool]($JSONPayload.cleanModes.s5)
                    }

                    Invoke-PipelineExecution @CustomRuntimeContext
                    
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"success","message":"Custom step execution initialization accepted cleanly."}')
                    $Response.StatusCode = 200
                }
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
            Log-Engine "⚠️ Request Parsing Context Exception: $_" "33"
            # Force-clear the tracking state so a broken handle doesn't wedge the loop
            $AsyncResult = $null
            try { 
                if ($null -ne $Context) { $Context.Response.Abort() } 
                elif ($null -ne $Response) { $Response.Abort() }
            } catch {}
        }
    }
}
catch {
    # 🟢 SAFE: Extract only the literal text message string instead of serializing the entire object graph
    $ExceptionMessage = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
    Log-Engine "🛑 Fatal HTTP Core Listener Breakdown: $ExceptionMessage" "1;31"
}
finally {
    if ($null -ne $Listener) { 
        try { $Listener.Stop(); $Listener.Close() } catch {} 
    }
    netsh interface portproxy reset | Out-Null
}