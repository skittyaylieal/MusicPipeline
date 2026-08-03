namespace MusicPipeline.Profiles;

public class DefaultProfiles
{
	public static readonly Profile defaultProfile = new Profile
	{
		Name = "Default",
		BackupDir = @"C:\Users\filip\Music\YT_Music_Backup",
		MobileDir = @"C:\Users\filip\Music\YT_Music_Mobile",
		BrokenSongsFile = @"C:\MusicTools\MusicPipeline\Config\broken_songs.json",
		DiagLogFile = @"C:\MusicTools\MusicPipeline\Config\web_console_stream.log",
		CacheFile = @"C:\MusicTools\MusicPipeline\Config\dashboard_cache.json",
		TimingFile = @"C:\MusicTools\MusicPipeline\Config\timing_history.json",
		CookieFile = @"C:\MusicTools\MusicPipeline\Config\cookies.txt",
		HistoryFile = @"C:\MusicTools\MusicPipeline\Config\downloaded_history.txt",
		YTDLPExe = @"C:\MusicTools\yt-dlp.exe",
		FFmpegExe = @"C:\MusicTools\ffmpeg.exe",
		FirefoxExe = @"C:\Program Files\Mozilla Firefox\firefox.exe",
		CheckURL = @"https://www.youtube.com/watch?v=dQw4w9WgXcQ",
		SleepInterval = 4,
		MaxSleepInterval = 12, 
		SleepRequests = 3,
		MaxCompressThreads = 8,
		MaxDownloadThreads = 6,
		MaxLyricThreads = 3,
		ScannerSleepIntervalSec = 60,
		ChronDaemonSleepSec = 1800,
		MaxStreamReturnLines = 15000,
		StartingWebServerPort = 50001,
		NormalIntervalSec = 1800,
		CleanIntervalSec = 604800,
		NormalStep1 = true,
		NormalStep2 = true,
		NormalStep3 = true,
		NormalStep4 = true,
		NormalStep5 = true,
		NormalStep6 = true,
		NormalStep7 = true,
		CleanSweepDownload = true,
		CleanSweepLyrics = true,
		CleanSweepCompress = true,
		CleanSweepLore = true,
		Playlists = [
		"https://www.youtube.com/playlist?list=PLqcuYaDDgyacWpBG6ib-2EKOuQa6aGjZJ",
		"https://www.youtube.com/playlist?list=PLqcuYaDDgyaeHKssVjz_Nw3qUDwfrwL09",
		"https://www.youtube.com/playlist?list=PLqcuYaDDgyad_i19iLheoQJLLKJUtwlAr",
		"https://www.youtube.com/playlist?list=PLqcuYaDDgyach02bt_8R8G7AzE9zSAOkS"
		],
		LastCleanRunEpoch = 1785532108,
		LastNormalRunEpoch = 1785673837
	};
}