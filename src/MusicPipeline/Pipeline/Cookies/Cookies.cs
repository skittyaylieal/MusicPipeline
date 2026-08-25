using System.Diagnostics;
using MusicPipeline.Results;
using MusicPipeline.Profiles;
using MusicPipeline.SongIdentifiers; //not currently used 
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Pipeline.Helpers.Execute;
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
			return CookieDefaults.FileError(false, start);
		}
		if (!File.Exists(YTDLPPath)){
			await LogEngine.Out(logFile, "[ERROR] YTDLP Executable could not be found.", "Cookies", DefaultColours.Error);
			return CookieDefaults.FileError(true, start);
		}

		await LogEngine.Out(logFile, "[+] Cookie and YTDLP files located sucsessfully!", "Cookies", DefaultColours.Success);
		await LogEngine.Out(logFile, "[*] Testing cookies on YouTube.", "Cookies");
		try
		{
			using (Process YTDLPProcess = await Helper.Execute(YTDLPPath, $"--cookies \"{cookieFile}\" --simulate --quiet {testURL}"))
			{
				if (YTDLPProcess is null) {
					DateTime endError = DateTime.UtcNow;
					TimeSpan elapsedError = endError - start;
					return new Result("Cookie Verification", false, elapsedError, "YTDLPProcess is Null");
				}
				// The cookie check uses --quiet so doesn't have any output
				// But this is a useful example for other programs
				/*
				string? currentLine;
				while (!((currentLine = (await YTDLPProcess.StandardOutput.ReadLineAsync())) == null)) {
					if (currentLine != null) {
						await LogEngine.Out(logFile, currentLine, "Cookies");
					}
				}
				*/

				await YTDLPProcess.WaitForExitAsync();
				DateTime end = DateTime.UtcNow;
				TimeSpan elapsed = end - start;
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