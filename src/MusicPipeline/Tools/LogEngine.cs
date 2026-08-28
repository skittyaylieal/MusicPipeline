using MusicPipeline.Profiles;
using MusicPipeline.Colours;
namespace MusicPipeline.Tools.LogEngine;

public class LogEngine
{
	// TODO: Profile file but also fix that bug where the file's locked
	// Logs to the file
	// Takes ASCII codes
	// Takes the message
	// Takes the profile file? or just the log file
	// Ok maybe we take the profile file after all lol
	private const char esc = '\u001B';
	private const string reset = $"\u001B[0m";

	public static async Task Out(string? logFile, string message, string user = "System", int? style = null) 
	{
		/*ArgumentException.ThrowIfNullOrEmpty(LogFile);
		ArgumentException.ThrowIfNullOrEmpty(Message);
		ArgumentException.ThrowIfNullOrEmpty(Style);
		if (!File.Exists(LogFile)) {
			throw new ArgumentException("Log file must exist", nameof(Profiler.LogFile));
		}*/

		if (logFile is null) {
			// This means a system thing like a constructor which doesn't have access to the current LogFile has had to send a message
			// I don't know what to do here
			// Directory.GetParent(workingDirectory).Parent.Parent.FullName
			string? likelyProfileFile = null;
			string? possibleProjectDirectory = Directory.GetParent(Directory.GetCurrentDirectory())?.Parent?.Parent?.Parent?.Parent?.FullName;
			IEnumerable<string> allSubFiles = Directory.EnumerateFiles(possibleProjectDirectory);
			foreach (string subFile in allSubFiles) {
				if (subFile.Contains("profiles.json")) {likelyProfileFile = subFile;}
			}
			Profile activeProfile = await ProfileManager.LoadActiveProfile(likelyProfileFile);
			logFile = activeProfile.DiagLogFile;
		}


		// TODO: Make this a case switch thingy
		if (style is null) {
			// Should've been omitted
			var field = typeof(DefaultColours).GetField(user);
			if (field != null) {
				style = (int)field.GetValue(null)!;
			}
			else {
				// Wrong Username given
				style = 36;
				await Out(logFile, "Given username was invalid or not in the default colours", "System", DefaultColours.Warning);
			}
		}

		if (style == 0) {
			style = 36;
			await Out(logFile, "0 is black, do not use it", "System", DefaultColours.Error);
		}

		//var l = new LogEngine(); //looks like this variable is not used.
		DateTime current = DateTime.Now; //because this variable is used online once you can inline it below.
		string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
		//what is colPrefix, the 38 and the 5?
		//these would be called "magic numbers" if it's not clear from the code what they are.
		// I've been meaning to put more explanatory comments for a bit
		string colPrefix = $"{esc}[38;5;{style.ToString()}m{timeStamp} [{user}] {reset}";
		// colPrefix
		// The escape marks that this is ANSI escaped colouring, not raw text
		// The [38;5; marks that the following value is an ANSI256 colour code.
		// The reset resets the text colour back to white for the actual message
		// I have considered adding an option to make the whole message that colour
		string processedMessage = $"{colPrefix} {message}";
		string processedMessageNl = $"\u000A{processedMessage}";

		await File.AppendAllTextAsync(logFile, processedMessageNl);
		Console.WriteLine(processedMessage);

	}

	// I think theres some kind of summary thing i'm supposed to use for this but idk how that works
	// Wipe just overwrites the file with a simple file cleared message
	public static async Task WipeAsync(string logFile, string user = "System")
	{
		//var l = new LogEngine();
		DateTime current = DateTime.Now;
		string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
		string colPrefix = $"{esc}[1;36m{timeStamp}";
		await File.WriteAllTextAsync(logFile, $"{colPrefix} File Cleared by {user}{reset}");
	}
}
