using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Profiles;
using MusicPipeline.Results;
using MusicPipeline.SongIdentifiers;
using System.Diagnostics;
namespace MusicPipeline.Pipeline;

class Cookies
{
	public static Result CookieCheck(string ProfileFile)
	{
		Profiles.Profile ActiveProfile = ProfileManager.LoadActiveProfileContext(ProfileFile);
		string LogFile = ActiveProfile.DiagLogFile;
		string CookieFile = ActiveProfile.CookieFile;
		string YTDLPPath = ActiveProfile.YTDLPExe;
		string TestURL = ActiveProfile.CheckURL;

		DateTime Start = DateTime.UtcNow;

		LogEngine.Out(LogFile, "==============================================", "Cookies", 111);
		LogEngine.Out(LogFile, "                Cookie Checker                ", "Cookies", 111);
		LogEngine.Out(LogFile, "==============================================", "Cookies", 111);

		if (!File.Exists(CookieFile)){
			LogEngine.Out(LogFile, "[ERROR] Cookie File could not be found. Please export one.", "Cookies", 203);
			DateTime End = DateTime.UtcNow;
			TimeSpan Elapsed = End - Start;
			return CookieDefaults.FileError(false, Elapsed);
		}
		if (!File.Exists(YTDLPPath)){
			LogEngine.Out(LogFile, "[ERROR] YTDLP Executable could not be found.", "Cookies", 203);
			DateTime End = DateTime.UtcNow;
			TimeSpan Elapsed = End - Start;
			return CookieDefaults.FileError(true, Elapsed);
		}

		LogEngine.Out(LogFile, "[+] Cookie and YTDLP files located sucsessfully!", "Cookies", 76);
		LogEngine.Out(LogFile, "[*] Testing cookies on YouTube.", "Cookies", 111);

		ProcessStartInfo startInfo = new ProcessStartInfo();
        startInfo.CreateNoWindow = false;
        startInfo.UseShellExecute = false;
        startInfo.FileName = YTDLPPath;
        startInfo.WindowStyle = ProcessWindowStyle.Hidden;
        startInfo.Arguments = $"--cookies \"{CookieFile}\" --simulate --quiet {TestURL}";

        try
        {
        	using (Process? YTDLPProcess = Process.Start(startInfo))
        	{
        		YTDLPProcess.WaitForExit();
        		DateTime End = DateTime.UtcNow;
				TimeSpan Elapsed = End - Start;
				//Result res = new Result(true, Elapsed, "no error", new List<MSongIdentifier>(new SongIdentifier("Never Gonna Give You Up", "Rick Astley", "NONE", 0, "m4a", 6.90, 4.20, false, true, true, false)));
        		return new Result("Cookie Verification", true, Elapsed);
        	}
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
        	DateTime End = DateTime.UtcNow;
			TimeSpan Elapsed = End - Start;
        	return new Result("Cookie Verification", false, Elapsed, ex.Message);
        }

	}
}