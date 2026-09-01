using System.Threading;
using System.Diagnostics;
using MusicPipeline.Results;
using MusicPipeline.Profiles;
using MusicPipeline.Pipeline.Helpers.Execute;
using MusicPipeline.Pipeline.Helpers.Parser;
using MusicPipeline.SongIdentifiers;
using MusicPipeline.Colours; 
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Pipeline;

class Downloader
{
	private Profile? activeProfile = null;
	private LogEngine? l = null;
	private string backupDir = "Null";
	private string YTDLPPath = "Null";
	private string cookiePath = "Null";
	private string historyPath = "Null";
	private string[] playlists = ["Null"];
	private string configDir = "Null";
	private string cacheDir = "Null";
	private string outputTemplate = "Null";
	private string downloadArguments = "Null";
	private string YTDLPConfigFile = "Null";
	private int sleepInterval = 0;
	private int maxSleepInterval = 0;
	private int sleepRequests = 0;
	private int maxDownloadThreads = 0;
	private bool cleanSweep = false;
	private DateTime start = new DateTime();
	private List<Result?>? res = null;

	public async Task<List<Result>> Download(string profileFile)
	{
		activeProfile = await ProfileManager.LoadActiveProfile(profileFile);

		backupDir = activeProfile.BackupDir;
		l = activeProfile.LogEngine;
		l.user = "Downloader";
		YTDLPPath = activeProfile.YTDLPExe;
		cookiePath = activeProfile.CookieFile;
		historyPath = activeProfile.HistoryFile;
		playlists = activeProfile.Playlists;
		configDir = $@"{activeProfile.RootDir}\Config";
		cacheDir = $@"{configDir}\.cache";
		outputTemplate = activeProfile.OutputTemplate;
		sleepInterval = activeProfile.SleepInterval;
		maxSleepInterval = activeProfile.MaxSleepInterval;
		sleepRequests = activeProfile.SleepRequests;
		maxDownloadThreads = activeProfile.MaxDownloadThreads;
		cleanSweep = activeProfile.CleanSweepDownload; // Note: Make sure that the profile value of CleanSweepDownload is correct before running
		// TODO add the ytdlp flags to profile file

		res = new List<Result?>();

		DateTime start = DateTime.UtcNow;

		if (Directory.Exists(configDir)) {
			IEnumerable<string> allSubFiles = Directory.EnumerateFiles(configDir, "run_errors_playlist*.txt", SearchOption.AllDirectories);
			foreach (string file in allSubFiles) {
				await l.Out($"File found {file}", DefaultColours.Debug);
				// Temporary debug to check that it's finding the right files
				// It is
				File.Delete(file);
			}
		}

		// Won't be bothering with the vpn stuff, I want to carefully consider how to do it, and whether it's even needed first

		await l.Out("==============================================");
		await l.Out("          YTDLP Song Downloader Step          ");
		await l.Out("==============================================");

		if (!Directory.Exists(backupDir)) {
			await l.Out($"Main backup directory {backupDir} doesn't exist. Creating.");
			Directory.CreateDirectory(backupDir);
		}


		if (cleanSweep) {
			historyPath = $@"{configDir}\pipeline_null_history_{Guid.NewGuid()}.txt";
			await l.Out("Clean sweep activated");
		}

		// URLs should be sanitised already

		// Ok how tf does threading work i'm stuck
		// WAIT
		// If i just make these all private fields
		// And then use foreach parallel to get the index variable
		// Tada!

		// From JleruOHeP on https://stackoverflow.com/questions/23419396/can-you-assign-a-value-only-if-its-greater-less-than-the-current-value#comment35888947_23419396
		maxDownloadThreads = maxDownloadThreads > playlists.Count() ? playlists.Count() : maxDownloadThreads;
		// I believe this effectively does
		/*
		if (maxDownloadThreads < playlist.Count()) {
			maxDownloadThreads = maxDownloadThreads;
		} else {
			maxDownloadThreads = playlist.Count();
		}

		But I'm not 100% sure how the ternary operator works
		*/

		Task? j = null;
		await Parser.ParseYTDLPConfigFile(activeProfile);
		activeProfile = await ProfileManager.LoadActiveProfile(profileFile);
		YTDLPConfigFile = activeProfile.YTDLPConfigFile;
		Parallel.For(0, maxDownloadThreads, async i => j = DownloadThread(i));
		await j;
		l.user = "Downloader";
		List<Result>? results = new List<Result>();
		foreach (Result? r in res) {
			if (res is null) {res = new List<Result?>([r]);}
			else {results.Add(r);}
			// Could also use addRange or something
		}
		Profile currentActiveProfile = await ProfileManager.LoadActiveProfile(profileFile);
		File.Delete(currentActiveProfile.YTDLPConfigFile);
		currentActiveProfile.YTDLPConfigFile = "Null";
		await ProfileManager.SaveProfile(profileFile, currentActiveProfile);
		DateTime end = DateTime.UtcNow;
		TimeSpan elapsed = end - start;
		results.Insert(0, new Result("Downloader", true, elapsed, "", await GetAffectedSongInfo()));
		return results;
	}

	private async Task DownloadThread(int index)
	{
		l.user = "DownloaderThread";
		await l.Out($"Index = {index} Playlists = {playlists}, sleepInterval = {sleepInterval}", DefaultColours.Debug);
		int? colourCode = null;
		// I know this isn't technically the same order as the original but the testing only has one playlist and I prefer the peach colour. Sue me.
		switch (index + 1) {
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

		await l.Out($"Processing Playlist URL: {playlists[index]}", colourCode);

		// Just found out that it supports putting all this in a file so :eyes:
		downloadArguments = $"--config-locations {YTDLPConfigFile}   {playlists[index]}";
		/*
		downloadArguments = string.Concat(
			$" --no-colors ", // Removes colouring from the output, as it would likely mess with the logEngine colouring
			//^ TODO: test without
			$"--verbose ", // Provides full output, necessary for working out which songs broke
			$"--newline ", // Outputs progress bar as new lines, otherwise it would just edit the previous line which doesn't play nice with logging
			$"--sleep-interval {sleepInterval} ", // Minimum bound for how long to sleep between videos
			$"--max-sleep-interval {maxSleepInterval} ", // Sleep length randomly chosen between --sleep-interval and this, to emulate a human and hopefully not get flagged
			$"--sleep-requests {sleepRequests} ", // How long to sleep between every api request, so as to not get throttled or rate limited
			$"--embed-thumbnail ", // Embed thumbnail into the video file as cover art
			$"--convert-thumbnails jpg ", // Convert thumbnail to jpg, or any format for consistency
			//^ I don't know why jpg is used, 
			//^^ TODO: Test different thumbnail formats for size
			$"--ppa EmbedThumbnail+ffmpeg_o:-vf crop=ih:ih ",// PostProccessor arguments. This gives the following arguments to ffmpeg when using EmbedThumbnail
			//^ -vf Video Feed, the thumbnail is embedded as the songs cover art
			//^^ crop=ih:ih crop to a square by the image height
			//^^^ NOTE: This doesn't seem to work, unless it was added after the existing files on my phone were generated, so a postprocessing step may have to be done in c# to fix that
			$"--embed-metadata ", // Embeds youtube metadata into the output file
			$"--parse-metadata title:%(artist)s - %(title)s ", // Parse metadata so that the title equals Artist - Title
			//^ This may not be what I want. Further testing required
			$"--parse-metadata uploader:%(artist)s ", // Sets the artist to the uploader
			$"--no-keep-video ", // Only download the audio stream
			$"--force-overwrites ", // If a file exists, overwrite it
			//^ This is used because a history file is also provided, and if that history file does not contain the video,
			//^^ Then we must have removed that for a reason like the video being downloaded incorrectly, so you want to overwrite with the correct video
			$"--cookies {cookiePath} ", // The cookie file
			$"-P {backupDir} ", // Download intermediary files to the backup directory
			$"-o {outputTemplate} ", // Use the provided output template to define the path of the output file
			//^ This a variable that can be changed in the profile
			//^^ TODO: Make some way for the profile to define these whole arguments
			$"--write-subs ", // Write subtitle files (For lyrics embedded in subtitles or like luke pickman's videos where he puts the current instrument name in the subtitles)
			$"--write-auto-subs ", // In case the auto subtitles are good
			//^ Could be better than nothing once the lyric step comes through
			$"--sub-format ass/srt/vtt/best", // Pretty good formats
			$"--sub-langs all", // All 
			$"--cache-dir {cacheDir} ", // Cache things like downloaders and page stuff
			$"--geo-bypass ", // It tries to bypass georestrictions
			$"--js-runtime deno ", // Use the deno Javascript runtime to handle challenges
			$"--extractor-args youtube:player_js_variant=tv ", // Pretend to be a youtube tv client to get easier javascript challenges; TVs are dumb and not very powerful
			$"-f bestaudio/best ", // Choose the best audio stream quality to download
			$"--extract-audio ", // Extract the audio streams (duh)
			$"--audio-format m4a ", // Use m4a as the audio format to output
			$"--audio-quality 0 ", // 0 is best
			$"--download-archive {historyPath} ", // The history file containing all the processed songs
			//$"--ignore-errors ", // If a song fails, continue
			$"--no-abort-on-error ", // See above
			$"--legacy-server-connect ", // Supports connecting to legacy youtube servers
			//^ Per YTDLPs README "Explicitly allow HTTPS connection to servers that do not support RFC 5746 secure renegotiation"
			$"--socket-timeout 30 ", // If the socket is quiet for more than 30 seconds, give up
			$"{playlists[index]}" // The url of the current playlist
		);
		*/


		try
		{
			using (Process YTDLPProcess = await Helper.Execute(YTDLPPath, downloadArguments))
			{
				if (YTDLPProcess is null) {
					DateTime endError = DateTime.UtcNow;
					TimeSpan elapsedError = endError - start;
					if (res is null) {res = new List<Result?>([new Result("DownloaderThread", false, elapsedError, "YTDLPProcess is Null")]);}
					else {res.Add(new Result("DownloaderThread", false, elapsedError, "YTDLPProcess is Null"));}
					return;
				}
				
				string? currentLine;
				List<string> lines = [""];
				while (!((currentLine = (await YTDLPProcess.StandardOutput.ReadLineAsync())) == null)) {
					if (currentLine != null) {
						await l.Out(currentLine, colourCode);
						lines.Add(currentLine);
					}
				}
				string errorFile = $@"{configDir}\run_errors_playlist{index+1}.txt";
				await File.AppendAllTextAsync(errorFile, String.Join("\n", lines));
				

				await YTDLPProcess.WaitForExitAsync();
				DateTime end = DateTime.UtcNow;
				TimeSpan elapsed = end - start;
				if (res is null) {res = new List<Result?>([new Result("DownloaderThread", true, elapsed, await GetErrorsInThread(index))]);}
				else {res.Add(new Result("DownloaderThread", true, elapsed, await GetErrorsInThread(index)));}
				return;
			}
		}
		catch (System.ComponentModel.Win32Exception ex)
		{
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			if (res is null) {res = new List<Result?>([new Result("DownloaderThread", false, elapsed, ex.Message)]);}
			else {res.Add(new Result("DownloaderThread", false, elapsed, ex.Message));}
		}
		finally
		{
			if (cleanSweep) {File.Delete(historyPath);}
		}
	}

	private async Task<List<SongIdentifier>> GetAffectedSongInfo()
	{
		l.user = "Downloader";
		await l.Out("TODO: URGENT: MAKE GetAffectedSongInfo", DefaultColours.Error, true);
        //return new List<SongIdentifier>(new SongIdentifier("Never Gonna Give You Up", "Rick Astley", "Whenever You Need Somebody", new List<FileInfo>([new FileInfo($@"{backupDir}\Rick Astley\Whenever You Need Somebody\Never Gonna Give You Up.m4a")]), null, "m4a", 8.63, new List<double>([6.32, 5.19]), false, true, true, new FileInfo($@"{backupDir}\Rick Astley\Whenever You Need Somebody\Never Gonna Give You Up.lrc"), false));
        List<FileInfo> paths = [new("Null")];
        List<double> sizesCompressed = new([0.0]);
        FileInfo lyricsPath = new("Null");
        DateTime loreDate = new();
        SongIdentifier songIdentifier =
            new(title: "Null",
            artist: "Null",
            album:"Null",
            paths,
            id: 0,
            type: "Null",
            sizeMB: 0.0,
            sizesCompressed: sizesCompressed,
            instrumental: false,
            lyrics: false,
            syncedLyrics: false,
            lyricsPath,
            lore: false,
            loreDate);
        return [songIdentifier];
	}

	private async Task<string> GetErrorsInThread(int threadIndex)
	{
		l.user = "Downloader";
		await l.Out("TODO: URGENT: MAKE GetErrorsInThread", DefaultColours.Error, true);
		return "TODO";
	} 
}