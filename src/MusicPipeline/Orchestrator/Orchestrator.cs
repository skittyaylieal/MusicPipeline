using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Orchestrator;

public class Orchestrator
{
    private string LogFile = @"C:\MusicTools\MusicPipeline\Sandbox\csLogFile.log";
    // Need tools
    static void Start()
    {
        var o = new Orchestrator();
        LogEngine.Out(o.LogFile, "Test");
    }
}
