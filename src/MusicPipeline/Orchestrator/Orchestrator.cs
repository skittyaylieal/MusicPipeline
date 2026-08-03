using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Profiles;
namespace MusicPipeline.Orchestrator;

public class Orchestrator
{
    // So I don't need to invoke this class itself
    private static readonly string logFile = @"C:\MusicTools\MusicPipeline\Sandbox\csLogFile.log";
    private static readonly string profileFile = @"C:\MusicTools\MusicPipeline\Sandbox\csProfileFile.json";
    // Need tools
    // 
    public static void Start(string ProfileFile = @"C:\MusicTools\MusicPipeline\Sandbox\csProfiles.json")
    {
        LogEngine.Wipe(logFile, "Orchestrator");
        LogEngine.Out(logFile, "Test", "Orchestrator", "38;5;203");
        LogEngine.Out(logFile, "Test Number 2", "Orchestrator", "38;5;213");
        ProfileManager.LoadProfileContext(profileFile);
    }
}
