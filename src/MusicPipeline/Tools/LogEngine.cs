namespace MusicPipeline.Tools.LogEngine;

public class LogEngine
{
    // Logs to the file
    // Takes ASCII codes
    // Takes the message
    // Takes the profile file? or just the log file
    private char esc = '\u001B';
    private string reset = $"{esc}[0m";
    private DateTime current = DateTime.Now;
    private string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";


    public static void Out(string LogFile, string Message, string User = "System", string Style = "1;36") 
    {
        /*ArgumentException.ThrowIfNullOrEmpty(LogFile);
        ArgumentException.ThrowIfNullOrEmpty(Message);
        ArgumentException.ThrowIfNullOrEmpty(Style);
        if (!File.Exists(LogFile)) {
            throw new ArgumentException("Log file must exist", nameof(Profiler.LogFile));
        }*/

        var l = new LogEngine();
        string ColPrefix = $"{l.esc}[{Style}m{l.timeStamp} [{User}] {l.reset}";
        string ProcessedMessage = $"{ColPrefix} {Message}";
        string ProcessedMessageNl = $"\u000A{ProcessedMessage}";

        File.AppendAllText(LogFile, ProcessedMessageNl);
        Console.WriteLine(ProcessedMessage);

    }

    public static void Wipe(string LogFile, string User = "System")
    {
        var l = new LogEngine();
        string ColPrefix = $"{l.esc}[1;36m{l.timeStamp}";
        File.WriteAllTextAsync(LogFile, $"{ColPrefix} File Cleared by {User}")
    }
}
