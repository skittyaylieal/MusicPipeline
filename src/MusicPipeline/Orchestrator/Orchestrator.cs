using System.Text.Json; // System comes first
using MusicPipeline.Profiles; // These are in whatever order they're first used
using MusicPipeline.Results;
using MusicPipeline.Pipeline;
using MusicPipeline.StepHandler;
using MusicPipeline.Colours; // Colours always before Logging
using MusicPipeline.Tools.LogEngine; // Tools last
namespace MusicPipeline.Orchestrator;

public static class Orchestrator
{
	// Class Colour code is 213

	// So I don't need to invoke this class itself
	//yes, you can call the methods directy from the class without an instance of the class.
	//Orchestrator.Start(); in program.cs
	// Need tools
	// 
	public static async Task Start(string profileFile = @"C:\MusicTools\MusicPipeline\Sandbox\csProfiles.json")
	{
		

		/* First use of Profiles*/ Profiles.Profile activeProfile = await ProfileManager.LoadActiveProfile(profileFile);
		string logFile = activeProfile.DiagLogFile;
		Console.WriteLine("Test");
		await LogEngine.WipeAsync(logFile, "Orchestrator");
		await LogEngine.Out(logFile, "Test", "Orchestrator", 203);
		await LogEngine.Out(logFile, "Test Number 2", "Orchestrator");
		await LogEngine.Out(logFile, JsonSerializer.Serialize(activeProfile), "Orchestrator", 54);
		activeProfile.ScannerSleepIntervalSec = 30;
		await ProfileManager.SaveProfileContext(profileFile, activeProfile);
		Profiles.Profile NewActiveProfile = await ProfileManager.LoadActiveProfile(profileFile);
		await LogEngine.Out(logFile, NewActiveProfile.ScannerSleepIntervalSec.ToString(), "Orchestrator", 36);
		
 		// First use of Results
		Result Step1Result = await Cookies.CookieCheck(profileFile);
		Handler.HandleResult(Step1Result, profileFile);
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