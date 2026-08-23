using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Colours;
using MusicPipeline.Profiles;
using MusicPipeline.Results;
namespace MusicPipeline.Pipeline;

class Downloader
{
	public static Result Download(string profileFile)
	{
		Profile activeProfile = ProfileManager.LoadActiveProfile(profileFile);
		string backupDir = activeProfile.BackupDir;
	    string YTDLPPath = activeProfile.YTDLPExe;
	    string cookiePath = activeProfile.CookieFile;
	    string historyPath = activeProfile.HistoryFile;
	    string[] playlistURLs = activeProfile.Playlists;
	    string configDir = $"{activeProfile.RootDir}\\Config";
	    string cacheDir = $"{configDir}\\.cache";
	    int sleepInterval = activeProfile.SleepInterval;
	    int maxSleepInterval = activeProfile.MaxSleepInterval;
	    int sleepRequests = activeProfile.SleepRequests;
	    int maxDownloadThreads = activeProfile.MaxDownloadThreads;
	    bool cleanSweep = activeProfile.CleanSweepDownload; // Note: Make sure that the profile value of CleanSweepDownload is correct before running
	   	
	}
}