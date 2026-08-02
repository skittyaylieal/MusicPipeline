namespace MusicPipeline.Tools.LogEngine;

public class LogEngine
{
    // Logs to the file
    // Takes ASCII codes
    // Takes the message
    // Takes the profile file? or just the log file

    public static void Out(string LogFile, string Message, string Style = "1;36") 
    {
        /*ArgumentException.ThrowIfNullOrEmpty(LogFile);
        ArgumentException.ThrowIfNullOrEmpty(Message);
        ArgumentException.ThrowIfNullOrEmpty(Style);
        if (!File.Exists(LogFile)) {
            throw new ArgumentException("Log file must exist", nameof(Profiler.LogFile));
        }*/

        string Contents = File.ReadAllText(LogFile);
        Contents += Message;
        File.WriteAllText(LogFile, Contents);

    }
}
