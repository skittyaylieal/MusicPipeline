# profile loader
function Load-ProfileContext {
    try {
        $Global:ProfileData = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
        $Active = $Global:ProfileData.ActiveProfile
        for ($Config in $Global:ProfileData.Profiles) {
            if ($Config.Name = $Active) {
                $Global:ActiveConfig = $Config
            }
        }

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