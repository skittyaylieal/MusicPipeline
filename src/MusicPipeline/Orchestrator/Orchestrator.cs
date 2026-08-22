using System.Text.Json;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Profiles;
using MusicPipeline.Pipeline;
using MusicPipeline.StepHandler;
using MusicPipeline.Results;
namespace MusicPipeline.Orchestrator;

public static class Orchestrator
{
    // So I don't need to invoke this class itself
    //yes, you can call the methods directy from the class without an instance of the class.
    //Orchestrator.Start(); in program.cs
    private static readonly string LogFile = @"C:\MusicTools\MusicPipeline\Sandbox\csLogFile.log";
    private static readonly string ProfileFile = @"C:\MusicTools\MusicPipeline\Sandbox\csProfileFile.json";
    // Need tools
    // 
    public static void Start(string profileFile = @"C:\MusicTools\MusicPipeline\Sandbox\csProfiles.json")
    {
        LogEngine.Wipe(LogFile, "Orchestrator");
        LogEngine.Out(LogFile, "Test", "Orchestrator", 203);
        LogEngine.Out(LogFile, "Test Number 2", "Orchestrator", 213);
        Profiles.Profile ActiveProfile = ProfileManager.LoadActiveProfileContext(profileFile);
        LogEngine.Out(LogFile, JsonSerializer.Serialize(ActiveProfile), "Orchestrator", 54);
        ActiveProfile.ScannerSleepIntervalSec = 30;
        ProfileManager.SaveProfileContext(profileFile, ActiveProfile);
        Profiles.Profile NewActiveProfile = ProfileManager.LoadActiveProfileContext(profileFile);
        LogEngine.Out(LogFile, NewActiveProfile.ScannerSleepIntervalSec.ToString(), "Orchestrator", 36);

        Result Step1Result = Cookies.CookieCheck(ProfileFile);
        Handler.HandleResult(Step1Result, ProfileFile);
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