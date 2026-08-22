namespace MusicPipeline.Tools.LogEngine;

public class LogEngine
{
    // Logs to the file
    // Takes ASCII codes
    // Takes the message
    // Takes the profile file? or just the log file
    private const char esc = '\u001B';
    private const string reset = $"\u001B[0m";

    public static void Out(string LogFile, string Message, string User = "System", int Style = 256) 
    {
        /*ArgumentException.ThrowIfNullOrEmpty(LogFile);
        ArgumentException.ThrowIfNullOrEmpty(Message);
        ArgumentException.ThrowIfNullOrEmpty(Style);
        if (!File.Exists(LogFile)) {
            throw new ArgumentException("Log file must exist", nameof(Profiler.LogFile));
        }*/

        //var l = new LogEngine(); //looks like this variable is not used.
        DateTime current = DateTime.Now; //because this variable is used online once you can inline it below.
        string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
        //what is colPrefix, the 38 and the 5?
        //these would be called "magic numbers" if it's not clear from the code what they are.
        // I've been meaning to put more explanatory comments for a bit
        string colPrefix = $"{esc}[38;5;{Style.ToString()}m{timeStamp} [{User}] {reset}";
        // colPrefix
        // The escape marks that this is ANSI escaped colouring, not raw text
        // The [38;5; marks that the following value is an ANSI256 colour code.
        // The reset resets the text colour back to white for the actual message
        // I have considered adding an option to make the whole message that colour
        string processedMessage = $"{colPrefix} {Message}";
        string processedMessageNl = $"\u000A{processedMessage}";

        File.AppendAllText(LogFile, processedMessageNl);
        Console.WriteLine(processedMessage);

    }

    // I think theres some kind of summary thing i'm supposed to use for this but idk how that works
    // Wipe just overwrites the file with a simple file cleared message
    public static void Wipe(string LogFile, string User = "System")
    {
        var l = new LogEngine();
        DateTime current = DateTime.Now;
        string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
        string colPrefix = $"{esc}[1;36m{timeStamp}";
        File.WriteAllText(LogFile, $"{colPrefix} File Cleared by {User}{reset}");
    }
}
