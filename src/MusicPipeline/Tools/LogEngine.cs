namespace MusicPipeline.Tools.LogEngine;

public class LogEngine
{
    // Logs to the file
    // Takes ASCII codes
    // Takes the message
    // Takes the profile file? or just the log file
    private const char esc = '\u001B';
    private const string reset = $"\u001B[0m";

    public static void Out(string LogFile, string Message, string User = "System", string Style = "1;36") 
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
        string ColPrefix = $"{esc}[{Style}m{timeStamp} [{User}] {reset}";
        string ProcessedMessage = $"{ColPrefix} {Message}";
        string ProcessedMessageNl = $"\u000A{ProcessedMessage}";

        File.AppendAllText(LogFile, ProcessedMessageNl);
        Console.WriteLine(ProcessedMessage);

    }

    public static void Wipe(string LogFile, string User = "System")
    {
        var l = new LogEngine();
        DateTime current = DateTime.Now;
        string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
        string ColPrefix = $"{esc}[1;36m{timeStamp}";
        File.WriteAllTextAsync(LogFile, $"{ColPrefix} File Cleared by {User}");
    }
}
