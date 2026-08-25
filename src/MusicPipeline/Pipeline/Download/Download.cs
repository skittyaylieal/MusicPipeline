using System.Threading;
using MusicPipeline.Results;
using MusicPipeline.Profiles;
using MusicPipeline.Colours; 
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Pipeline;

class Downloader
{
	private Profile? activeProfile = null;
	private string logFile = "Null";
	private string backupDir = "Null";
	private string YTDLPPath = "Null";
	private string cookiePath = "Null";
	private string historyPath = "Null";
	private string[] playlists = ["Null"];
	private string configDir = "Null";
	private string cacheDir = "Null";
	private int sleepInterval = 0;
	private int maxSleepInterval = 0;
	private int sleepRequests = 0;
	private int maxDownloadThreads = 0;
	private bool cleanSweep = false;

	public async Task<Result> Download(string profileFile)
	{
		activeProfile = await ProfileManager.LoadActiveProfile(profileFile);
		logFile = activeProfile.DiagLogFile;
		backupDir = activeProfile.BackupDir;
		YTDLPPath = activeProfile.YTDLPExe;
		cookiePath = activeProfile.CookieFile;
		historyPath = activeProfile.HistoryFile;
		playlists = activeProfile.Playlists;
		configDir = $@"{activeProfile.RootDir}\Config";
		cacheDir = $@"{configDir}\.cache";
		sleepInterval = activeProfile.SleepInterval;
		maxSleepInterval = activeProfile.MaxSleepInterval;
		sleepRequests = activeProfile.SleepRequests;
		maxDownloadThreads = activeProfile.MaxDownloadThreads;
		cleanSweep = activeProfile.CleanSweepDownload; // Note: Make sure that the profile value of CleanSweepDownload is correct before running
		// TODO add the ytdlp flags to profile file

		DateTime start = DateTime.UtcNow;

		// Won't be bothering with the vpn stuff, I want to carefully consider how to do it, and whether it's even needed first

		await LogEngine.Out(logFile, "=============================================", "Downloader");
		await LogEngine.Out(logFile, "			YTDLP Song Downloader			", "Downloader");
		await LogEngine.Out(logFile, "=============================================", "Downloader");

		if (!Directory.Exists(backupDir)) {
			Directory.CreateDirectory(backupDir);
		}

		string outputTemplate = $"{backupDir}/%(artist|uploader).250s/%(album|playlist).250s/%(title).250s.%(ext)s";

		if (cleanSweep) {
			historyPath = $@"{configDir}\pipeline_null_history_{Guid.NewGuid()}.txt";
			// Remove at the end
		}

		// URLs should be sanitised already

		// Ok how tf does threading work i'm stuck
		// WAIT
		// If i just make these all private fields
		// And then use foreach parallel to get the index variable
		// Tada!

		// From JleruOHeP on https://stackoverflow.com/questions/23419396/can-you-assign-a-value-only-if-its-greater-less-than-the-current-value#comment35888947_23419396
		maxDownloadThreads = maxDownloadThreads < playlists.Count() ? playlists.Count() : maxDownloadThreads;
		// I believe this effectively does
		/*
		if (maxDownloadThreads < playlist.Count()) {
			maxDownloadThreads = maxDownloadThreads;
		} else {
			maxDownloadThreads = playlist.Count();
		}

		But I'm not 100% sure how the ternary operator works
		*/

		Parallel.For(0, maxDownloadThreads, async i => await DownloadThread(i));

	}

	private async Task DownloadThread(int index)
	{
		int? colourCode = null;
		// I know this isn't technically the same order as the original but the testing only has one playlist and I prefer the peach colour. Sue me.
		switch (index) {
			case 1:
				colourCode = 217; // Peach
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
				colourCode = 51; // Cyan
				break;
			// TODO: add more cases by looking through https://color-palette.hexdocs.pm/ansi_color_codes.html once necessary.
		}

		string errorLogPath = $@"{configDir}playlist${index}_run_errors.txt";
		if (File.Exists(errorLogPath)) {File.Delete(errorLogPath);}

		await LogEngine.Out(logFile, $"Processing Playlist URL: {playlists[index]}", "Downloader", colourCode);


		/*
		args in progress
						"--no-colors
				--verbose
				--newline
				--sleep-interval $using:LocalSleepInterval
				--max-sleep-interval $using:LocalMaxSleepInterval
				--sleep-requests $using:LocalSleepRequests
				--embed-thumbnail
				--convert-thumbnails jpg
				--ppa EmbedThumbnail+ffmpeg_o:-vf crop=ih:ih
				--embed-metadata
				--parse-metadata title:%(artist)s - %(title)s
				--parse-metadata uploader:%(artist)s
				--no-keep-video
				--force-overwrites
				--cookies $using:LocalCookiePath
				-P {LocalBackupDir}
				-o {OutputTemplate}
				--cache-dir {LocalCacheDir}
				--geo-bypass
				--js-runtime deno
				--extractor-args youtube:player_js_variant=tv
				-f bestaudio/best
				--extract-audio
				--audio-format m4a
				--audio-quality 0
				--download-archive {LocalActiveHistoryLog}
				--ignore-errors
				--no-abort-on-error
				--legacy-server-connect
				--socket-timeout 30
				{PlaylistURL}"
			*/

	}
}