using System.Diagnostics;
using MusicPipeline.Results;
using MusicPipeline.Profiles;
using MusicPipeline.Songs; //not currently used 
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Pipeline.Helpers.Execute;
namespace MusicPipeline.Pipeline;

class Cookies
{
	// Class Colour Code is 112
	/// <summary>
	/// Checks cookies with YTDLP asynchronously
	/// </summary>
	/// <remarks>
	/// <para>
	/// 	Asynchronous method that checks for cookie file, verifies they work.
	/// </para>
	/// <para>
	/// 	Updates YTDLP, runs a --simulate and --quiet ytdlp instance to check the cookies work.
	/// </para>
	/// </remarks>
	/// <returns>Returns a List of Results</returns>
	/// <param name="profileFile">String, the profile file to get global values from.</param>
	public static async Task<List<Result>> CookieCheck(string profileFile)
	{
		//in C# local variables should start with lower case, camel case.
		Profiles.Profile activeProfile = await ProfileManager.LoadActiveProfile(profileFile);
		LogEngine? l = activeProfile.LogEngine;
		l.user = "Cookies";
		await l.Out("Profile Done", DefaultColours.Debug);
		string cookieFile = activeProfile.CookieFile;
		string YTDLPPath = activeProfile.YTDLPExe;
		string testURL = activeProfile.CheckURL;
		List<Result> res = new();

		await l.Out("Variables Done", DefaultColours.Debug);

		DateTime start = DateTime.UtcNow;

		await l.Out("Started timer", DefaultColours.Debug);

		await l.Out("==============================================");
		await l.Out("                Cookie Checker                ");
		await l.Out("==============================================");

		if (!File.Exists(cookieFile)){
			await l.Out("Cookie File could not be found. Please export one.", DefaultColours.Error, true);
			res.Append(CookieDefaults.FileError(false, start));
			goto Return;
		}
		if (!File.Exists(YTDLPPath)){
			await l.Out("YTDLP Executable could not be found.", DefaultColours.Error, true);
			res.Append(CookieDefaults.FileError(true, start));
			goto Return;
		}

		await l.Out("Updating YTDLP");
		res.Append(await Helper.RunSilentAsync(YTDLPPath, "-U", "YTDLP Update", "YTDLPProcess"));

		await l.Out("Cookie and YTDLP files located successfully!", DefaultColours.Success, true);
		await l.Out("Testing cookies on YouTube.");
		try
		{
			using (Process YTDLPProcess = await Helper.Execute(YTDLPPath, $"--cookies \"{cookieFile}\" --simulate --quiet {testURL}"))
			{
				if (YTDLPProcess is null) {
					DateTime endError = DateTime.UtcNow;
					TimeSpan elapsedError = endError - start;
					res.Append(new Result("Cookie Verification", false, elapsedError, "YTDLPProcess is Null"));
					goto Return;
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
				res.Append(new Result("Cookie Verification", true, elapsed));
				goto Return;
			}
		}
		catch (System.ComponentModel.Win32Exception ex)
		{
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			res.Append(new Result("Cookie Verification", false, elapsed, ex.Message));
		}


		Return:
			// Return the list of results
			return res;

	}
}