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
		Console.WriteLine(activeProfile);
		LogEngine? l = activeProfile.LogEngine;
		l.user = "Cookies";
		await l.Out("Profile Done", DefaultColours.Debug);
		string cookieFile = activeProfile.CookieFile;
		string YTDLPPath = activeProfile.YTDLPExe;
		string testURL = activeProfile.CheckURL;

		await l.Out("Variables Done", DefaultColours.Debug);

		DateTime start = DateTime.UtcNow;

		await l.Out("Started timer", DefaultColours.Debug);

		await l.Out("==============================================");
		await l.Out("                Cookie Checker                ");
		await l.Out("==============================================");

		if (!File.Exists(cookieFile)){
			await l.Out("[ERROR] Cookie File could not be found. Please export one.", DefaultColours.Error, true);
			return CookieDefaults.FileError(false, start);
		}
		if (!File.Exists(YTDLPPath)){
			await l.Out("[ERROR] YTDLP Executable could not be found.", DefaultColours.Error, true);
			return CookieDefaults.FileError(true, start);
		}

		await l.Out("[+] Cookie and YTDLP files located sucsessfully!", DefaultColours.Success, true);
		await l.Out("[*] Testing cookies on YouTube.");
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
						await l.Out(currentLine);
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