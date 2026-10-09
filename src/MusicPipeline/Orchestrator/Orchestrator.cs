using System; // System comes first
using System.Text.Json;
using MusicPipeline.Profiles; // These are in whatever order they're first used
using MusicPipeline.Results;
using MusicPipeline.Pipeline;
using MusicPipeline.Pipeline.Helpers.Parser;
using MusicPipeline.StepHandler;
using MusicPipeline.Colours; // Colours always before Logging
using MusicPipeline.Tools.LogEngine; // Tools last
namespace MusicPipeline.Orchestrator;


// TODO: Add this to sublime settings on windows machines
// "default_line_ending": "unix"
// In user settings preferences -> settings
public class Orchestrator
{
	// Class Colour code is 213

	// So I don't need to invoke this class itself
	//yes, you can call the methods directy from the class without an instance of the class.
	//Orchestrator.Start(); in program.cs
	// Need tools
	// 
	public async Task Start()
	{	
		//Profile oldActiveProfile = DefaultProfiles.DefaultProfile;
		//Console.WriteLine($"Loading profile");
		// Aha. ProfileManager is where the stack overflow starts
		/* First use of Profiles*/ Profile oldActiveProfile = await ProfileManager.LoadActiveProfileAsync();
		//Console.WriteLine(JsonSerializer.Serialize(oldActiveProfile, new JsonSerializerOptions { WriteIndented = true }));
		MyPath logFile = oldActiveProfile.DiagLogFile;
		//Console.WriteLine($"logFile = {logFile}");
		LogEngine logger = new LogEngine(oldActiveProfile.DiagLogFile);
		//Console.WriteLine($"logger = {logger}, logger.logFile = {logger.logFile}, logger.user = {logger.user??"No user set"}");
		//Console.WriteLine("Trying to log");
		await logger.WipeAsync("Orchestrator");
		await logger.Out("Why won't you just work!!!", "Orchestrator", DefaultColours.Error, true);
		//Console.WriteLine("Did that work??");
		oldActiveProfile.LogEngine = logger;
		oldActiveProfile.Name = "Current Working Profile";
		await ProfileManager.SaveProfileAsync(oldActiveProfile);
		Profile activeProfile = await ProfileManager.LoadActiveProfileAsync();
		LogEngine? l = activeProfile.LogEngine;
		l?.user = "Orchestrator";
		await l.WipeAsync();
		await l.Out("Test", DefaultColours.Error, true);
		await l.Out("Other Test", DefaultColours.Warning);
		await l.Out("Test Number 2", true);
		await l.Out(JsonSerializer.Serialize(oldActiveProfile), 54);
		activeProfile.ScannerSleepIntervalSec = 30;
		activeProfile.CleanSweepDownload = true;
		await ProfileManager.SaveProfileAsync(activeProfile);
		Profiles.Profile newActiveProfile = await ProfileManager.LoadActiveProfileAsync();
		await l.Out(newActiveProfile.ScannerSleepIntervalSec.ToString(), 36);
		



 		
 		// First use of Results
		List<Result> Step1Results = await Cookies.CookieCheck();
		await Handler.HandleResults(Step1Results);
		var d = new Downloader();
		List<Result> Step2Results = await d.Download();
		await Handler.HandleResults(Step2Results);
		
		
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
