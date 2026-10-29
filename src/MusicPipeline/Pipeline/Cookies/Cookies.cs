using System.Diagnostics;
using MusicPipeline.Results;
using MusicPipeline.Profiles;
//using MusicPipeline.Songs; //not currently used 
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Pipeline.Helpers.Execute;
namespace MusicPipeline.Pipeline;

//primary constructor syntax. I haven't done this a lot personally, but it's cool.
class Cookies(/*Profile activeProfile, LogEngine logEngine*/)
{
	//public Profile ActiveProfile { get; set; } = activeProfile;
	//public LogEngine LogEngine { get; set; } = logEngine;

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
	/// <returns>A List of Results</returns>
	public async Task<List<Result>> CookieCheck()
	{
		//await LogEngine.Out("Profile Done", DefaultColours.Debug);
		Profile activeProfile = await ProfileManager.LoadActiveProfileAsync();
		MyPath cookieFile = activeProfile.CookieFile;
		MyPath YTDLPPath = activeProfile.YTDLPExe;
		string testURL = activeProfile.CheckURL;
		LogEngine l = activeProfile.LogEngine ?? new(activeProfile.DiagLogFile);
		l.UserName = "Cookies";
		List<Result> res = new();

		await l.Out("Variables Done", DefaultColours.Debug);

		DateTime start = DateTime.UtcNow;

		await l.Out("Started timer", DefaultColours.Debug);

		await l.BuildBanner("Cookie Checker");

		if (!File.Exists(cookieFile.p)){
			await l.Out("Cookie File could not be found. Please export one.", DefaultColours.Error, true);
			res.Append(CookieDefaults.FileError(false, start));
			return res;
		}
		if (!File.Exists(YTDLPPath.p)){
			await l.Out("YTDLP Executable could not be found.", DefaultColours.Error, true);
			res.Append(CookieDefaults.FileError(true, start));
			return res;
		}

		await l.Out("Updating YTDLP");
		res.Append(await Helper.RunSilentAsync(YTDLPPath, "--update-to nightly", "YTDLP Update", "YTDLPProcess"));

		// pip install --upgrade certifi
		// Getting new root certificates for the python enviroment, just in case.
		await l.Out("Updating Certificates");
		res.Append(await Helper.RunSilentAsync("python.exe", "-m pip install --upgrade certifi", "Certificate Update", "PythonProcess"));

		await l.Out("Cookie and YTDLP files located successfully!", DefaultColours.Success, true);
		await l.Out("Testing cookies on YouTube.");
		try
		{
			using (Process? YTDLPProcess = await Helper.Execute(YTDLPPath, $"--cookies \"{cookieFile}\" --simulate --quiet {testURL}"))
			{
				if (YTDLPProcess is null) {
					DateTime endError = DateTime.UtcNow;
					TimeSpan elapsedError = endError - start;
					res.Append(new Result("Cookie Verification", false, elapsedError, "YTDLPProcess is Null"));
					return res;
				}
				// The cookie check uses --quiet so doesn't have any output
				// But this is a useful example for other programs
				/*
				string? currentLine;
				while (!((currentLine = (await YTDLPProcess.StandardOutput.ReadLineAsync())) == null)) {
					if (currentLine != null) {
						await LogEngine.Out(currentLine);
					}
				}
				*/

				await YTDLPProcess.WaitForExitAsync();
				DateTime end = DateTime.UtcNow;
				TimeSpan elapsed = end - start;
				res.Append(new Result("Cookie Verification", true, elapsed));
			}
		}
		catch (System.ComponentModel.Win32Exception ex)
		{
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			res.Append(new Result("Cookie Verification", false, elapsed, ex.Message));
		}
		return res;
	}
}