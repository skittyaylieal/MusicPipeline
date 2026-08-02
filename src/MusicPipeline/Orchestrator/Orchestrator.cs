using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Orchestrator;

public class Orchestrator
{
    // So I don't need o
    private static readonly string LogFile = @"C:\MusicTools\MusicPipeline\Sandbox\csLogFile.log";
    // Need tools
    public static void Start()
    {
        LogEngine.Wipe(LogFile, "Orchestrator");
        LogEngine.Out(LogFile, "Test", "Orchestrator", "38;5;203");
        LogEngine.Out(LogFile, "Test Number 2", "Orchestrator", "38;5;213");
    }
}
