using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Profiles;
using MusicPipeline.Results;
using MusicPipeline.SongIdentifiers; //not currently used 
using System.Diagnostics;
namespace MusicPipeline.Pipeline;

class Cookies
{
	public static Result CookieCheck(string ProfileFile)
	{
		//in C# local variables should start with lower case, camel case.
		Profiles.Profile activeProfile = ProfileManager.LoadActiveProfileContext(ProfileFile);
		string logFile = activeProfile.DiagLogFile;
		string cookieFile = activeProfile.CookieFile;
		string YTDLPPath = activeProfile.YTDLPExe;
		string testURL = activeProfile.CheckURL;

		DateTime start = DateTime.UtcNow;

		LogEngine.Out(logFile, "==============================================", "Cookies", 111);
		LogEngine.Out(logFile, "                Cookie Checker                ", "Cookies", 111);
		LogEngine.Out(logFile, "==============================================", "Cookies", 111);

		if (!File.Exists(cookieFile)){
			LogEngine.Out(logFile, "[ERROR] Cookie File could not be found. Please export one.", "Cookies", 203);
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			return CookieDefaults.FileError(false, elapsed);
		}
		if (!File.Exists(YTDLPPath)){
			LogEngine.Out(logFile, "[ERROR] YTDLP Executable could not be found.", "Cookies", 203);
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			return CookieDefaults.FileError(true, elapsed);
		}

		LogEngine.Out(logFile, "[+] Cookie and YTDLP files located sucsessfully!", "Cookies", 76);
		LogEngine.Out(logFile, "[*] Testing cookies on YouTube.", "Cookies", 111);
		//this object initialization can be simplified, or you can create a constructor for ProcessStartInfo.
		// TODO: Make some general thing for every step to use
		ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.CreateNoWindow = false;
        startInfo.UseShellExecute = false;
        startInfo.FileName = YTDLPPath;
        startInfo.WindowStyle = ProcessWindowStyle.Hidden;
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
        		YTDLPProcess.WaitForExit();
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