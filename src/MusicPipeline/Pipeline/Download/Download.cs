using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Colours;
using MusicPipeline.Profiles;
using MusicPipeline.Results;
namespace MusicPipeline.Pipeline;

class Downloader
{
	public Result Download(string profileFile)
	{
		Profile activeProfile = ProfileManager.LoadActiveProfile(profileFile);
		string logFile = activeProfile.DiagLogFile;
		string backupDir = activeProfile.BackupDir;
	    string YTDLPPath = activeProfile.YTDLPExe;
	    string cookiePath = activeProfile.CookieFile;
	    string historyPath = activeProfile.HistoryFile;
	    string[] playlists = activeProfile.Playlists;
	    string configDir = $@"{activeProfile.RootDir}\Config";
	    string cacheDir = $@"{configDir}\.cache";
	    int sleepInterval = activeProfile.SleepInterval;
	    int maxSleepInterval = activeProfile.MaxSleepInterval;
	    int sleepRequests = activeProfile.SleepRequests;
	    int maxDownloadThreads = activeProfile.MaxDownloadThreads;
	    bool cleanSweep = activeProfile.CleanSweepDownload; // Note: Make sure that the profile value of CleanSweepDownload is correct before running
	   	// TODO add the ytdlp flags to profile file

	    DateTime start = DateTime.UtcNow;

	   	// Won't be bothering with the vpn stuff, I want to carefully consider how to do it, and whether it's even needed first

	   	LogEngine.Out(logFile, "=============================================", "Downloader");
	   	LogEngine.Out(logFile, "            YTDLP Song Downloader            ", "Downloader");
	   	LogEngine.Out(logFile, "=============================================", "Downloader");

	   	if (!Directory.Exists(backupDir)) {
	   		Directory.CreateDirectory(backupDir);
	   	}

	   	string outputTemplate = $"{backupDir}/%(artist|uploader).250s/%(album|playlist).250s/%(title).250s.%(ext)s";

	   	if (cleanSweep) {
	   		historyPath = $@"{configDir}\pipeline_null_history_{Guid.NewGuid()}.txt";
	   		// Remove at the end
	   	}

	   	// URLs should be sanitised already


	}

	private void DownloadThread(
		string logFile, string backupDir, string YTDLPPath,
		string cookiePath, string historyPath, string[] playlists,
		string configDir, string cacheDir, int sleepInterval,
		int maxSleepInterval, int sleepRequests, int maxDownloadThreads, int index)
	{
		int? colourCode = null;
		switch (index) {
                case 1:
                	colourCode = 51; // Cyan
                	break; 
                case 2:
                	colourCode = 201;  // Magenta
                	break; 
                case 3:
                	colourCode = 33; //yellow
                	break; 
                case 4:
                	colourCode = 135; // Purple
                	break; 
                case 5:
                	colourCode = 22; // Forest
                	break; 
                case 6:
                	colourCode = 217; // Peach
                	break; 
        }
	}
}