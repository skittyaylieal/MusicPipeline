namespace MusicPipeline.Tools.LogEngine;

public class LogEngine
{
    // Logs to the file
    // Takes ASCII codes
    // Takes the message
    // Takes the profile file? or just the log file
    private const char esc = '\u001B';
    private const string reset = $"\u001B[0m";

    public static void Out(string LogFile, string Message, string User = "System", int Style = 36) 
    {
        /*ArgumentException.ThrowIfNullOrEmpty(LogFile);
        ArgumentException.ThrowIfNullOrEmpty(Message);
        ArgumentException.ThrowIfNullOrEmpty(Style);
        if (!File.Exists(LogFile)) {
            throw new ArgumentException("Log file must exist", nameof(Profiler.LogFile));
        }*/

        var l = new LogEngine();
        DateTime current = DateTime.Now;
        string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
        string colPrefix = $"{esc}[38;5;{Style.ToString()}m{timeStamp} [{User}] {reset}";
        string processedMessage = $"{colPrefix} {Message}";
        string processedMessageNl = $"\u000A{processedMessage}";

        File.AppendAllText(LogFile, processedMessageNl);
        Console.WriteLine(processedMessage);

    }

    public static void Wipe(string LogFile, string User = "System")
    {
        var l = new LogEngine();
        DateTime current = DateTime.Now;
        string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
        string colPrefix = $"{esc}[1;36m{timeStamp}";
        File.WriteAllText(LogFile, $"{colPrefix} File Cleared by {User}{reset}");
    }
}
