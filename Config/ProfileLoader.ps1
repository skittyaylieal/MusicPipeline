# profile loader
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
                    HistoryFile             = "C:\MusicTools\MusicPipeline\Config\downloaded_history.txt"
                    YTDLPExe                = "C:\MusicTools\yt-dlp.exe"
                    FFmpegExe               = "C:\MusicTools\ffmpeg.exe"
                    FirefoxExe              = "C:\Program Files\Mozilla Firefox\firefox.exe"
                    CheckURL                = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
                    SleepInterval           = 4
                    MaxSleepInterval        = 12
                    SleepRequests           = 3
                    MaxCompressThreads      = 3
                    MaxDownloadThreads      = 3
                    ScannerSleepIntervalSec = 60
                    ChronDaemonSleepSec     = 1800 
                    
                    NormalIntervalSec       = 1800     
                    CleanIntervalSec        = 604800   
                    
                    NormalStep1             = $true
                    NormalStep2             = $true
                    NormalStep3             = $true
                    NormalStep4             = $true
                    NormalStep5             = $true
                    NormalStep6             = $true
                    
                    CleanSweepDownload      = $true
                    CleanSweepLyrics        = $true
                    CleanSweepCompress      = $true
                    
                    LastNormalRunEpoch      = 0
                    LastCleanRunEpoch       = 0
                    
                    Playlists               = @(
                        "https://www.youtube.com/playlist?list=PLqcuYaDDgyacWpBG6ib-2EKOuQa6aGjZJ",
                        "https://www.youtube.com/playlist?list=PLqcuYaDDgyaeHKssVjz_Nw3qUDwfrwL09",
                        "https://www.youtube.com/playlist?list=PLqcuYaDDgyad_i19iLheoQJLLKJUtwlAr",
                        "https://www.youtube.com/playlist?list=PLqcuYaDDgyach02bt_8R8G7AzE9zSAOkS"
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