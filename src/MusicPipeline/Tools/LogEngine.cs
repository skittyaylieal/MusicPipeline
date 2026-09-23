using System.Diagnostics.CodeAnalysis;
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
	public required string logFile {get; set;} = "Null";
	public string? user {get; set;}

	/*public async Task Out(string logFile, string message, string user = "System", int? style = null)
	{
		await Engine(message, user, style, logFile);
	}*/

	public async Task Out(string message, string userParam, int? style = null, bool colourFullString = false) 
	{
		// New system
		Console.WriteLine("This is the first overload used in Orchestrator");
		Console.WriteLine($"message = {message}, userParam = {userParam}, style = {(style is null? style.ToString(): "A style was not given")}, colourFullString = {colourFullString}");
		await Engine(message, userParam, style, colourFullString);
	}

	public async Task Out(string message, int? style, bool colourFullString = false)
	{
		Console.WriteLine("This is the first overload used in ProfileManager");
		Console.WriteLine($"message = {message}, this.user = {this.user}, style = {style}, colourFullString = {colourFullString}");
		if (user is null) {await Engine("To use Out() without a user please set a user in the class", "System", DefaultColours.Error, true);}
		else {await Engine(message, user, style, colourFullString);}
	}

	public async Task Out(string message, bool colourFullString = false)
	{
		if (user is null) {await Engine("To use Out() without a user please set a user in the class", "System", DefaultColours.Error, true);}
		else {await Engine(message, user, null, colourFullString);}
	}

	private async Task Engine(string message, string user, int? style, bool colourFullString = false, string? logFileParam = null)
	{
		/*ArgumentException.ThrowIfNullOrEmpty(LogFile);
		ArgumentException.ThrowIfNullOrEmpty(Message);
		ArgumentException.ThrowIfNullOrEmpty(Style);
		if (!File.Exists(LogFile)) {
			throw new ArgumentException("Log file must exist", nameof(Profiler.LogFile));
		}*/
		if (logFile == "Null" & logFileParam != null) {logFile = logFileParam;}
		Console.WriteLine("You have reached the Engine");

		switch (style) {
			case 0:
				style = 36;
				await Engine("0 is black, do not use it", "System", DefaultColours.Error, true);
				break;
			case null:
				Console.WriteLine($"Finding value for user {this.user}");
				// Should've been omitted
				var field = typeof(DefaultColours).GetField(user);
				Console.WriteLine($"field = {field}");
				if (field != null) {
					style = (int)field.GetValue(null)!;
					Console.WriteLine($"style = {style}");
				}
				else {
					// Wrong Username given
					style = 36;
					Console.WriteLine("Wrong username");
					await Engine("Given username was invalid or not in the default colours", "System", DefaultColours.Warning, true);
				}
				break;
		}

		Console.WriteLine("Style is now correct/was specified");
		//var l = new LogEngine(); //looks like this variable is not used.
		DateTime current = DateTime.Now;
		Console.WriteLine($"current = {current}");
		string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
		Console.WriteLine($"timeStamp = {timeStamp}");
		//what is colPrefix, the 38 and the 5?
		//these would be called "magic numbers" if it's not clear from the code what they are.
		// I've been meaning to put more explanatory comments for a bit
		string colPrefix = $"{esc}[38;5;{style.ToString()}m{timeStamp} [{user}] {(colourFullString ? "" : reset)}";
		Console.WriteLine($"colPrefix = {colPrefix} {reset}");
		// colPrefix
		// The escape marks that this is ANSI escaped colouring, not raw text
		// The [38;5; marks that the following value is an ANSI256 colour code.
		// The reset resets the text colour back to white for the actual message
		// I have considered adding an option to make the whole message that colour
		string processedMessage = $"{colPrefix} {message} {reset}";
		Console.WriteLine($"processedMessage = {processedMessage}");
		string dateYear = current.Date.ToString("dd/MM/yyyy");
		Console.WriteLine($"dateYear = {dateYear}");
		string processedMessageDate = $"\u000A{esc}[38;5;{DefaultColours.Date.ToString()}m{dateYear} {reset} {processedMessage}";
		Console.WriteLine($"processedMessageDate = {processedMessageDate}");

		
		for (int i = 0; i < 5; i++) {
			try {
				await File.AppendAllTextAsync(logFile, processedMessageDate);
				break;
			}
			catch (System.IO.IOException) {
				Console.WriteLine($"{timeStamp} Oops, IO Exception!");
				//Console.WriteLine($"{esc}[38;5;203m{timeStamp} [System] TODO: Fix this a better way {reset}");
				await Engine("File lock", "System", DefaultColours.Error, true);
				Thread.Sleep(50);
				continue;
			}
		}
		Console.WriteLine(processedMessage);
	}

	// I think theres some kind of summary thing I'm supposed to use for this but idk how that works
	// Wipe just overwrites the file with a simple file cleared message
	/// <summary>
	/// Asynchronously overwrites the current logfile with one line saying the time of the date and the user who requested it.
	/// </summary>
	public async Task WipeAsync()
	{
		DateTime current = DateTime.Now;
		string timeStamp = $"[{current.ToString("HH:mm:ss")}]";
		string colPrefix = $"{esc}[38;5;{typeof(DefaultColours).GetField(user).GetValue(null).ToString()}m{timeStamp}";
		string dateYear = current.Date.ToString("dd/MM/yyyy");
		string tempMessage = $"{colPrefix} File Cleared by {user}{reset}";
		string processedMessage = $"{esc}[38;5;{DefaultColours.Date.ToString()}m{dateYear} {reset} {tempMessage}";
		await File.WriteAllTextAsync(logFile, processedMessage);
	}

    [SetsRequiredMembers]
	public LogEngine(string LogFile, string? User = null)
	{
		logFile = LogFile;
		user = User;
	}

	/*[SetsRequiredMembers]
	public LogEngine(LogEngine original)
	{
		logFile = original.logFile;
		user = original.user;
	}*/
}
