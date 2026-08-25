using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Colours;
using MusicPipeline.Profiles;
using MusicPipeline.Results;
using MusicPipeline.SongIdentifiers; //not currently used 
using System.Diagnostics;
namespace MusicPipeline.Pipeline;

class Cookies
{
	// Class Colour Code is 112
	public static async Task<Result> CookieCheck(string ProfileFile)
	{
		//in C# local variables should start with lower case, camel case.
		Profiles.Profile activeProfile = await ProfileManager.LoadActiveProfile(ProfileFile);
		string logFile = activeProfile.DiagLogFile;
		await LogEngine.Out(logFile, "Profile Done", "Cookies", DefaultColours.Debug);
		string cookieFile = activeProfile.CookieFile;
		string YTDLPPath = activeProfile.YTDLPExe;
		string testURL = activeProfile.CheckURL;

		await LogEngine.Out(logFile, "Variables Done", "Cookies", DefaultColours.Debug);

		DateTime start = DateTime.UtcNow;

		await LogEngine.Out(logFile, "Started timer", "Cookies", DefaultColours.Debug);

		await LogEngine.Out(logFile, "==============================================", "Cookies");
		await LogEngine.Out(logFile, "                Cookie Checker                ", "Cookies");
		await LogEngine.Out(logFile, "==============================================", "Cookies");

		if (!File.Exists(cookieFile)){
			await LogEngine.Out(logFile, "[ERROR] Cookie File could not be found. Please export one.", "Cookies", DefaultColours.Error);
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			return CookieDefaults.FileError(false, elapsed);
		}
		if (!File.Exists(YTDLPPath)){
			await LogEngine.Out(logFile, "[ERROR] YTDLP Executable could not be found.", "Cookies", DefaultColours.Error);
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			return CookieDefaults.FileError(true, elapsed);
		}

		await LogEngine.Out(logFile, "[+] Cookie and YTDLP files located sucsessfully!", "Cookies", DefaultColours.Success);
		await LogEngine.Out(logFile, "[*] Testing cookies on YouTube.", "Cookies");
		//this object initialization can be simplified, or you can create a constructor for ProcessStartInfo.
		// TODO: Make some general thing for every step to use
		ProcessStartInfo startInfo = new ProcessStartInfo();
		startInfo.CreateNoWindow = false;
		startInfo.UseShellExecute = false;
		startInfo.FileName = YTDLPPath;
		startInfo.WindowStyle = ProcessWindowStyle.Hidden;
		startInfo.RedirectStandardOutput = true;
		startInfo.Arguments = $"--cookies \"{cookieFile}\" --simulate --quiet {testURL}";

		try
		{
			using (Process? YTDLPProcess = Process.Start(startInfo))
			{
				//check for nulls first
				// Done?
				if (YTDLPProcess is null) {
					DateTime endError = DateTime.UtcNow;
					TimeSpan elapsedError = endError - start;
					return new Result("Cookie Verification", false, elapsedError, "YTDLPProcess is Null");
				}
				string? currentLine;
				/*
				while (true) {
					try {
						currentLine = await YTDLPProcess.StandardOutput.ReadLineAsync();
						if (currentLine != null) {
							await LogEngine.Out(logFile, "Outputted", "Cookies", DefaultColours.Debug);
							break;
						}
					} catch (InvalidOperationException) {
						Stopwatch stopwatch = Stopwatch.StartNew();
						while (true)
						{
						    //some other processing to do possible
						    await LogEngine.Out(logFile, "Waiting", "Cookies", DefaultColours.Debug);
						    if (stopwatch.ElapsedMilliseconds >= 5)
						    {
						        break;
						    }
						}
						continue;
					}
				}
				*/
				// Ok don't do that lol
				// It doesn't exit
				// Weird, because that implies that it was never getting an output, and just crashing
				// Meaning something else isn't working properly
				// But it should be outputting on standard
				// This while decleration is an absolute mess, but basically it assigns the variable and then checks if it's null
				// To not set the variable to the bool "await YTDLPProcess.StandardOutput.ReadLineAsync() == null"
				// You need all those brackets
				// Maybe some helper function? StandardOutputAsync or smth
				while (!((currentLine = (await YTDLPProcess.StandardOutput.ReadLineAsync())) == null)) {
					if (currentLine != null) {
						// 1. Flash it to your master console/global log stream
						await LogEngine.Out(logFile, currentLine, "Cookies");
					}
				}

				await YTDLPProcess.WaitForExitAsync();
				DateTime end = DateTime.UtcNow;
				TimeSpan elapsed = end - start;
				//Result res = new Result(true, Elapsed, "no error", new List<MSongIdentifier>(new SongIdentifier("Never Gonna Give You Up", "Rick Astley", "NONE", 0, "m4a", 6.90, 4.20, false, true, true, false)));
				return new Result("Cookie Verification", true, elapsed);
			}
		}
		catch (System.ComponentModel.Win32Exception ex)
		{
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			return new Result("Cookie Verification", false, elapsed, ex.Message);
		}

	}
}