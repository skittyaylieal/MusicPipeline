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
		await Engine(message, userParam, style, colourFullString);
	}

	public async Task Out(string message, int? style, bool colourFullString = false)
	{
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

		switch (style) {
			case 0:
				style = 36;
				await Engine("0 is black, do not use it", "System", DefaultColours.Error, true);
				break;
			case null:
				// Should've been omitted
				var field = typeof(DefaultColours).GetField(user);
				if (field != null) {
					style = (int)field.GetValue(null)!;
				}
				else {
					// Wrong Username given
					style = 36;
					await Engine("Given username was invalid or not in the default colours", "System", DefaultColours.Warning, true);
				}
				break;
		}

		//var l = new LogEngine(); //looks like this variable is not used.
		DateTime current = DateTime.Now;
		string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
		//what is colPrefix, the 38 and the 5?
		//these would be called "magic numbers" if it's not clear from the code what they are.
		// I've been meaning to put more explanatory comments for a bit
		string colPrefix = $"{esc}[38;5;{style.ToString()}m{timeStamp} [{user}] {(colourFullString ? "" : reset)}";
		// colPrefix
		// The escape marks that this is ANSI escaped colouring, not raw text
		// The [38;5; marks that the following value is an ANSI256 colour code.
		// The reset resets the text colour back to white for the actual message
		// I have considered adding an option to make the whole message that colour
		string processedMessage = $"{colPrefix} {message} {reset}";
		string dateYear = current.Date.ToString("dd/MM/yyyy");
		string processedMessageDate = $"\u000A{esc}[38;5;{DefaultColours.Date.ToString()}m{dateYear} {reset} {processedMessage}";

		
		for (int i = 0; i < 10; i++) {
			StreamWriter sw = new StreamWriter(logFile);
			try {
				sw.WriteLine(processedMessage);
				await File.AppendAllTextAsync(logFile, processedMessageDate);
			}
			catch (System.IO.IOException) {
				//Console.WriteLine($"{timeStamp} Oops, IO Exception!");
				//Console.WriteLine($"{esc}[38;5;203m{timeStamp} [System] TODO: Fix this a better way {reset}");
				await Engine("File lock", "System", DefaultColours.Error, true);
			}
			finally {
				sw.Close();
			}
			Thread.Sleep(5);
		}
		Console.WriteLine(processedMessage);

		/*
			
		try
		{
			//Pass the filepath and filename to the StreamWriter Constructor
			StreamWriter sw = new StreamWriter("C:\\Test.txt");
			//Write a line of text
			sw.WriteLine("Hello World!!");
			//Write a second line of text
			sw.WriteLine("From the StreamWriter class");
			//Close the file
			sw.Close();
		}
		catch(Exception e)
		{
			Console.WriteLine("Exception: " + e.Message);
		}
		finally
		{
			Console.WriteLine("Executing finally block.");
		}

		*/
	}

	// I think theres some kind of summary thing I'm supposed to use for this but idk how that works
	// Wipe just overwrites the file with a simple file cleared message
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
}
