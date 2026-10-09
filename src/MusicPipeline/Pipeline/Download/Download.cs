using System.Threading;
using System.Diagnostics;
using MusicPipeline.Results;
using MusicPipeline.Profiles;
using MusicPipeline.Pipeline.Helpers.Execute;
using MusicPipeline.Pipeline.Helpers.Parser;
using MusicPipeline.Pipeline.Helpers.Download;
using MusicPipeline.Songs;
using MusicPipeline.Colours; 
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Pipeline;

class Downloader
{
	#region private fields
	private Profile? activeProfile = null;
	private LogEngine? l = null;
	private string backupDir = "Null";
	private string YTDLPPath = "Null";
	private string cookiePath = "Null";
	private string historyPath = "Null";
	private string[] playlists = ["Null"];
	private string configDir = "Null";
	private string cacheDir = "Null";
	private string downloadArguments = "Null";
	private string YTDLPConfigFile = "Null";
	private string customArguments = "Null";
	private int sleepInterval = 0;
	private int maxSleepInterval = 0;
	private int sleepRequests = 0;
	private int maxDownloadThreads = 0;
	private bool cleanSweep = false;
	private DateTime start = new DateTime();
	private Dictionary<int, Result?> res = new();
	private Dictionary<int, List<SongIdentifier>> songs = new(); // TODO: Finish up the SongInfo classes
	#endregion private fields

	public async Task<List<Result>> Download()
	{
		activeProfile = await ProfileManager.LoadActiveProfileAsync();
		// Set all the values from the profile.
		// They need to be class fields so the downloader can access
		//	^ downloader can access it just like how it's happening in the lines below.
		//	it doesn't need to be assigned to these new private fields.
		//	question though: who SHOULD own what? right now profile owns everything.
		backupDir = activeProfile.BackupDir.p;
		//directory information: do you want profile managing that?
		l = activeProfile.LogEngine;
		//for logging, I think while we're in the Downloader, it should get its own logger.
		l.user = "Downloader";
		YTDLPPath = activeProfile.YTDLPExe.p;
		cookiePath = activeProfile.CookieFile.p;
		historyPath = activeProfile.HistoryFile.p;		
		playlists = activeProfile.Playlists;
		//location of these above files all also relating to directory, probably should belong to profile? (like they already do)
		cacheDir = new MyPath("[$ConfigDir]/.cache").p;
		//these two above take root dir from profile, but then change it to be their own thing.
		//i'm thinking if root directory really belongs to profile, these two should too.
		sleepInterval = activeProfile.SleepInterval;
		maxSleepInterval = activeProfile.MaxSleepInterval;
		sleepRequests = activeProfile.SleepRequests;
		//the above 3 should probably belong to Downloader, would you agree? sleeping feels like the job of a downloader.
		maxDownloadThreads = activeProfile.MaxDownloadThreads;
		//I think this one (above) definitely should belong to downloader!
		cleanSweep = activeProfile.CleanSweepDownload; // Note: Make sure that the profile value of CleanSweepDownload is correct before running
		customArguments = activeProfile.CustomYTDLPArguments;

		var iAmDebugging = true;

		// ClearOutErrorFiles() does more than what LogEngine should be responsible for, so I would recommend against moving that code into LogEngine.
		DateTime officialStartTime = DateTime.UtcNow;
		await LogStartTime(l, iAmDebugging, officialStartTime);
		await ClearOutErrorFiles(l);
		await WriteBanner(l);
		await CreateBackupDirectory(l);
		await SetCleanSweep(l, new MyPath("null").ConfigDir, cleanSweep);
		//v From JleruOHeP on https://stackoverflow.com/questions/23419396/can-you-assign-a-value-only-if-its-greater-less-than-the-current-value#comment35888947_23419396
		SetMaxDownloadThreads();
		// Won't be bothering with the vpn stuff, I want to carefully consider how to do it, and whether it's even needed first
		// URLs should be sanitised already
	
		Task? j = null; // Initialise a blank task to be assigned by each thread
						// I don't know if this works with multiple threads lol it probably doesn't
						// Ey looks like it does! sweet!
		
		//i recommend renaming the below method.
		//it parses files, but the main output is that it writes files.
		await Parser.ParseYTDLPConfigFile(); // Parse the config file, adding variables into the {} text
		activeProfile = await ProfileManager.LoadActiveProfileAsync(); // Get the new config file (If we move to the contained approach this will be reworked ofc)
		YTDLPConfigFile = activeProfile.YTDLPConfigFile.p; // Set the new value
		Parallel.For(0, maxDownloadThreads, i => j = DownloadThread(i)); // Run the parallel for
		await j; // Await the task
		List<Result>? results = new List<Result>(); // An intermediary list
		foreach (KeyValuePair<int, Result?> r in res)
		{ // Go through each result from each thread
			results.Add(r.Value); // Add the result to the main list
			songs.Add(r.Key, await GetAffectedSongInfoInThread(r.Key)); // Get the songs for that thread
			// TODO: MAKE THIS await CheckWarningsInThread(r.Key);
		}
		Profile currentActiveProfile = await ProfileManager.LoadActiveProfileAsync(); // A copy of the profile for changing 
		File.Delete(currentActiveProfile.YTDLPConfigFile.p); // Delete the temporary config file made with the new variables
		currentActiveProfile.YTDLPConfigFile.FormattedPath = "Null"; // Set it back to the default "Null" (Maybe change this to set it to what default profile uses?)
		await ProfileManager.SaveProfileAsync(currentActiveProfile); // Save changes
		DateTime end = DateTime.UtcNow; // The official end time
		TimeSpan elapsed = end - officialStartTime; // The elapsed TimeSpan
		await l.Out($"elapsed = {elapsed}, end = {end}, start = {officialStartTime}", DefaultColours.Debug); // Debugging
		results.Insert(0, new Result("Downloader", true, elapsed, "", songs)); // Final Result
		return results;
	}

	private void SetMaxDownloadThreads()
	{
		bool morePlaylistsThanThreadsAllowed = maxDownloadThreads > playlists.Length;
		if (morePlaylistsThanThreadsAllowed)
			maxDownloadThreads = playlists.Length;
	}

	private async Task SetCleanSweep(LogEngine l, string configDir, bool isCleanSweep)
	{
		if (isCleanSweep)
		{
			// If cleanSweep then fake file
			//activeProfile.HistoryFile = historyPath;
			//await ProfileManager.SaveProfile(profileFile, activeProfile);
			historyPath = $@"{configDir}/pipeline_null_history_{Guid.NewGuid()}.txt";
			await l.Out("Clean sweep active"); // Logging
		}
	}

	private async Task CreateBackupDirectory(LogEngine l)
	{
		if (Directory.Exists(backupDir))
			return;

		await l.Out($"Main backup directory {backupDir} doesn't exist. Creating.");
		Directory.CreateDirectory(backupDir);
	}

	private async Task LogStartTime(LogEngine l, bool IAmDebugging, DateTime officialStartTime)
	{
		if (IAmDebugging)
			await l.Out($"start = {officialStartTime}", DefaultColours.Debug);
	}

	private async Task WriteBanner(LogEngine l)
	{
		await l.Out("==============================================");
		await l.Out("          YTDLP Song Downloader Step          ");
		await l.Out("==============================================");
	}

	private async Task ClearOutErrorFiles(LogEngine l)
	{
		if (!Directory.Exists(configDir)) {
			return;	
		}
		IEnumerable<string> errorFiles = Directory.EnumerateFiles(configDir, "run_errors_playlist*.txt", SearchOption.AllDirectories); // Find error files. Not sure why I called it sub?
		foreach (string file in errorFiles) {
			await l.Out($"File found {file}", DefaultColours.Debug); // Debugging
																	 // Temporary debug to check that it's finding the right files
																	 // It is
			File.Delete(file);
		}
	}

	public enum ColoUUUrCode
	{
		Peach = 217,
		Magenta = 201,
		Yellow = 33,
		Purple = 135,
		Forest = 22,
		Cyan = 51
		// TODO: add more cases by looking through https://color-palette.hexdocs.pm/ansi_color_codes.html once necessary.
	}

	private async Task DownloadThread(int index)
	{
		LogEngine? log = new(l.logFile);
		log.user = $"DownloaderThread-{index+1}";
		DateTime threadStart = DateTime.UtcNow;
		await log.Out($"Index = {index} Playlist = {playlists[index]}, customArgs = {customArguments}", DefaultColours.Debug);
		int? colourCode = null;

		switch (index) {
			case 0:
				colourCode = (int)ColoUUUrCode.Peach;
				break; 
			case 1:
				colourCode = (int)ColoUUUrCode.Magenta;
				break; 
			case 2:
				colourCode = (int)ColoUUUrCode.Yellow;
				break; 
			case 3:
				colourCode = (int)ColoUUUrCode.Purple;
				break; 
			case 4:
				colourCode = (int)ColoUUUrCode.Forest;
				break; 
			case 5:
				colourCode = (int)ColoUUUrCode.Cyan;
				break;
		}

		string errorLogPath = $@"{configDir}playlist${index}_run_errors.txt";

		if (File.Exists(errorLogPath)) 
			File.Delete(errorLogPath);

		await log.Out($"Processing Playlist URL: {playlists[index]}", colourCode);

		// Just found out that it supports putting all this in a file so :eyes:
		//downloadArguments = $"--config-locations {YTDLPConfigFile}  \"{customArguments}\"  --download-archive \"{historyPath}\"  {playlists[index]}";
		downloadArguments = $"--config-locations {YTDLPConfigFile}  --download-archive \"{historyPath}\"  {playlists[index]}";
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

		string YTDLPArgs = $"/c \"{YTDLPPath} {downloadArguments} 2>&1\"";
		try
		{
			using (Process? YTDLPProcess = await Helper.Execute("cmd.exe", YTDLPArgs))
			{
				if (YTDLPProcess is null) {
					DateTime endError = DateTime.UtcNow;
					TimeSpan elapsedError = endError - threadStart;
					await log.Out($"elapsed = {elapsedError}, end = {endError}, start = {start}, threadStart = {threadStart}", DefaultColours.Debug);
					res.Add(index, new Result("DownloaderThread", false, elapsedError, "YTDLPProcess is Null"));
					return;
				}

				/*string lastOutputLine = "";
				string lastErrorLine = "";
				List<string> lines = new();
				while (!((await YTDLPProcess.StandardOutput.ReadLineAsync() ?? await YTDLPProcess.StandardError.ReadLineAsync()) == null)) {
					string? currentOutput = await YTDLPProcess.StandardOutput.ReadLineAsync();
					string? currentError = await YTDLPProcess.StandardError.ReadLineAsync();
					if (currentOutput != null || currentError != null) {
						if (lastOutputLine != currentOutput) {await log.Out(currentOutput, colourCode); lines.Add(currentOutput);}
						int? errorCode = colourCode;
						if (currentError.Contains("WARNING: ")) {errorCode = DefaultColours.Warning;}
						else if (currentError.Contains("ERROR: ")) {errorCode = DefaultColours.Error;}
						if (lastErrorLine != currentError) {await log.Out(currentError, errorCode); lines.Add(currentError);}
					}
					lastOutputLine = currentOutput; lastErrorLine = currentError;
				}
				*/

				// Ok redoing this

				/*
				KeyValuePair<string, int> currentLine = new; // The line and the colour
				List<string> lines = new();
				while (!((currentLine = await Helper.ProcessOutput(YTDLPProcess, colourCode)) is null)) {
					log.Out(currentLine.Key, currentLine.Value);
					lines.Add(currentLine);
				}
				*/

				/*
				// That won't work, trying again
				List<string> lines = await Helper.ProcessOutput(YTDLPProcess, l, colourCode);
				*/

				// This is all ridiculous

				string? currentLine;
				List<string> lines = [""];
				while (!((currentLine = (await YTDLPProcess.StandardOutput.ReadLineAsync())) == null)) {
					if (currentLine != null) {
						int? errorCode = colourCode;
						if (currentLine.Contains("WARNING: ")) {errorCode = DefaultColours.Warning;}
						else if (currentLine.Contains("ERROR: ")) {errorCode = DefaultColours.Error;}
						await log.Out(currentLine, errorCode);
						lines.Add(currentLine);
						// May be worth manually appending the current line
						// Will do that if I ever run into issues with the program crashing and only having the log output
					}
				}
				string errorFile = $@"{configDir}/run_errors_playlist{index+1}.txt";
				await File.AppendAllTextAsync(errorFile, String.Join("\n", lines));
				

				await YTDLPProcess.WaitForExitAsync();
				DateTime end = DateTime.UtcNow;
				TimeSpan elapsed = end - threadStart;
				await log.Out($"elapsed = {elapsed}, end = {end}, start = {start}, threadStart = {threadStart}", DefaultColours.Debug);
				KeyValuePair<bool, string> errors = await GetErrorsInThread(index);
				res.Add(index, new Result("DownloaderThread", errors.Key, elapsed, errors.Value));
				return;
			}
		}
		catch (System.ComponentModel.Win32Exception ex)
		{
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - threadStart;
			await log.Out($"elapsed = {elapsed}, end = {end}, start = {start}, threadStart = {threadStart}", DefaultColours.Debug);
			res.Add(index, new Result("DownloaderThread", elapsed, ex.Message));
		}
		finally
		{
			if (cleanSweep) File.Delete(historyPath);
		}
	}

	private async Task<List<SongIdentifier>> GetAffectedSongInfoInThread(int index)
	{
		l.user = "Downloader";
		await l.Out("TODO: URGENT: MAKE GetAffectedSongInfo", DefaultColours.Error, true);
		//return new List<SongIdentifier>(new SongIdentifier("Never Gonna Give You Up", "Rick Astley", "Whenever You Need Somebody", new List<FileInfo>([new FileInfo($@"{backupDir}\Rick Astley\Whenever You Need Somebody\Never Gonna Give You Up.m4a")]), null, "m4a", 8.63, new List<double>([6.32, 5.19]), false, true, true, new FileInfo($@"{backupDir}\Rick Astley\Whenever You Need Somebody\Never Gonna Give You Up.lrc"), false));

		//moved the code for creating this default case of SongIdentifier into a constructor
		var songIdentifier = new SongIdentifier();
		//currently you're not doing anything with this variable besides returning it as the only member of a list.
		//I'm sure you'll want to modify it in some way before returning it.

		string path = $@"{configDir}/run_errors_playlist{index+1}.txt";
		// Parse URL
		string playlistURL = await YTDLPHelpers.GetUrlFromRunLogFile(path);		
		if (playlistURL != "")
		{
			//I don't know what you're going to use the url for, but wrote this if to help protected it.
			// URL is for double checking the playlist didn't get fucked up
			// I was running into issues with my config file not working properly and trying to read random other values so I'll add at some point some failsafe stuff to the geturl method
			// So that if someone runs it with a broken config file they can help fix it
			await l.Out(playlistURL, DefaultColours.Debug);
		}

		// Get all the songs
		var data = await YTDLPHelpers.GetAllSongsFromRunLogFile(path);
		Dictionary<int, SongIdentifier> allSongs = data.songs;
		int totalSongs = data.total; // Some things may want to check that the total is the same as the number of 
		// Ignore errors
			// Use a helper to get the list of every individual song
			// Then go through each one thats labelled as an error

		return [songIdentifier];
	}

	private async Task<KeyValuePair<bool, string>> GetErrorsInThread(int threadIndex)
	{
		l.user = "Downloader";
		await l.Out("TODO: URGENT: MAKE GetErrorsInThread", DefaultColours.Error, true);
		return new(true, "TODO");
	} 
}