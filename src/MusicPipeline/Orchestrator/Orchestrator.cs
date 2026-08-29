using System.Text.Json; // System comes first
using MusicPipeline.Profiles; // These are in whatever order they're first used
using MusicPipeline.Results;
using MusicPipeline.Pipeline;
using MusicPipeline.Pipeline.Helpers.Parser;
using MusicPipeline.StepHandler;
using MusicPipeline.Colours; // Colours always before Logging
using MusicPipeline.Tools.LogEngine; // Tools last
namespace MusicPipeline.Orchestrator;

public class Orchestrator
{
	// Class Colour code is 213

	// So I don't need to invoke this class itself
	//yes, you can call the methods directy from the class without an instance of the class.
	//Orchestrator.Start(); in program.cs
	// Need tools
	// 
	public async Task Start(string profileFile = @"C:\MusicTools\MusicPipeline\Sandbox\Config\csProfiles.json")
	{		

		/* First use of Profiles*/ Profile activeProfile = await ProfileManager.LoadActiveProfile(profileFile);
		string logFile = activeProfile.DiagLogFile;
		Console.WriteLine("Test");
		LogEngine l = new LogEngine(activeProfile.DiagLogFile);
		activeProfile.LogEngine = l;
		l.user = "Orchestrator";
		await ProfileManager.SaveProfile(profileFile, activeProfile);
		await l.WipeAsync();
		/*await l.Out("Test", DefaultColours.Error);
		await l.Out("Test Number 2");
		await l.Out(JsonSerializer.Serialize(activeProfile), 54);
		activeProfile.ScannerSleepIntervalSec = 30;
		await ProfileManager.SaveProfile(profileFile, activeProfile);
		Profiles.Profile newActiveProfile = await ProfileManager.LoadActiveProfile(profileFile);
		await l.Out(newActiveProfile.ScannerSleepIntervalSec.ToString(), 36);
		await ProfileManager.SaveProfile(profileFile, DefaultProfiles.DefaultProfile);

 		// First use of Results
		Result Step1Result = await Cookies.CookieCheck(profileFile);
		Handler.HandleResult(Step1Result, profileFile);
		var d = new Downloader();
		List<Result> Step2Results = await d.Download(profileFile);
		foreach (Result r in Step2Results) {
			Handler.HandleResult(r, profileFile);
		}*/
		var par = new Parser();
		await par.ParseYTDLPConfigFile(activeProfile.YTDLPConfigFileOriginal);
	}



	// Needs to do everything that WebsiteEngine.ps1 does

	// FUNCTIONS:
	//
	// LogEngine - Done
	// LoadProfile stuff - WIP, mostly Done
	// Setup and making directories etc
	// Track UUID function - Done
	// Asynchronous library scanner - Improve 
	// Chron daemon
	// Hot reload and git pull functionality - Improve
	// WEB SERVER SHIT
		// Find a suitable socket
		// Proxy map port 80 to the target 
		// Listen on target port
		// Optionally get the external ip and print that
		// URL paths, etc etc
		// Make sure to close it
	// Idea, music streaming server
	// You can stream music from the server to your device
}