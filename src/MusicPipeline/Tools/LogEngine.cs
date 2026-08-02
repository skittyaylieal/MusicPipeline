namespace MusicPipeline.Tools.LogEngine;

public class LogEngine
{
    // Logs to the file
    // Takes ASCII codes
    // Takes the message
    // Takes the profile file? or just the log file

    public static void Out(string LogFile, string Message, string User = "System", string Style = "1;36") 
    {
        /*ArgumentException.ThrowIfNullOrEmpty(LogFile);
        ArgumentException.ThrowIfNullOrEmpty(Message);
        ArgumentException.ThrowIfNullOrEmpty(Style);
        if (!File.Exists(LogFile)) {
            throw new ArgumentException("Log file must exist", nameof(Profiler.LogFile));
        }*/

        char esc = '\u001B';
        string reset = $"{esc}[0m";
        DateTime current = DateTime.Now;
        string TimeStamp = "[" + current.ToString("HH:mm:ss") + "]";
        string ColPrefix = $"{esc}[{Style}m{TimeStamp} [{User}] {reset}";
        string ProcessedMessage = $"{ColPrefix} {Message}";

        File.AppendAllText(LogFile, ProcessedMessage);
        Console.WriteLine(ProcessedMessage);

    }
}
