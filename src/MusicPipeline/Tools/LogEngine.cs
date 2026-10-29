using System.Collections;
using System.Diagnostics.CodeAnalysis;
using System.Text.Json.Serialization;
using MusicPipeline.Colours;
using MusicPipeline.Profiles;
using static System.Net.Mime.MediaTypeNames;
namespace MusicPipeline.Tools.LogEngine;

public class LogEngine
{
	// TODO: Profile file but also fix that bug where the file's locked
	// Logs to the file
	// Takes ASCII codes
	// Takes the message
	// Takes the profile file? or just the log file
	// Ok maybe we take the profile file after all lol
	public const string _bannerBar = "==============================================";
	private const char _escapeCharacter = '\u001B';
	private const string _asni256ColourCodeStart = "[38;5;";
	private readonly string _clearFontColour = $"{_escapeCharacter}[0m";

	public required MyPath LogFile {get; set;} = new("Null");
	public string? UserName {get; set;}

	private async Task MyOut(string message, string userName = "", int? fontColourCode = null, bool applyColourToEntireMessage = false)
	{
		string userToUse = "";
		if (UserName != null)
			userToUse = UserName;
		if (userName != "")
			userToUse = userName;
		if (userToUse == "") {
			await Engine("To use Out() without a user please set a user in the class", "System", DefaultColours.Error, true);
			await Engine(message, "Error", fontColourCode, applyColourToEntireMessage);
		}
		else
			await Engine(message, userToUse, fontColourCode, applyColourToEntireMessage);
	}

	public async Task Out(string message) => await MyOut(message);
	public async Task Out(string message, bool applyColourToEntireMessage) => await MyOut(message, "", applyColourToEntireMessage: applyColourToEntireMessage);
	public async Task Out(string message, string userName) => await MyOut(message, userName);
	public async Task Out(string message, int? fontColourCode) => await MyOut(message, "", fontColourCode, false);
	public async Task Out(string message, int? fontColourCode, bool applyColourToEntireMessage) => await MyOut(message, "", fontColourCode, applyColourToEntireMessage);
	public async Task Out(string message, string userName, int? fontColourCode, bool applyColourToEntireMessage) => await MyOut(message, userName, fontColourCode, applyColourToEntireMessage);

	private async Task Engine(string message, string userName, int? fontColourCode, bool applyColourToEntireMessage = false, MyPath? logFileParam = null)
	{
		// Maybe make it try to find the log file if it's set as "Null"
		/*ArgumentException.ThrowIfNullOrEmpty(LogFile);
		ArgumentException.ThrowIfNullOrEmpty(Message);
		ArgumentException.ThrowIfNullOrEmpty(Style);
		if (!File.Exists(LogFile)) {
			throw new ArgumentException("Log file must exist", nameof(Profiler.LogFile));
		}*/
		if (LogFile.p == "Null" & logFileParam != null) {LogFile = logFileParam ?? new("Null");}

		bool fontColourCodeIsBlack = fontColourCode == 0;
		if (fontColourCodeIsBlack)
			await Engine("0 is black, do not use it", "System", DefaultColours.Error, true);
		if (fontColourCode == null)
		{
			var field = typeof(DefaultColours).GetField(userName);
			if (field != null)
				fontColourCode = (int)field.GetValue(null)!;
			else
				await Engine("Given username was invalid or not in the default colours", "System", DefaultColours.Warning, true);
		}

		//var l = new LogEngine(); //looks like this variable is not used.
		DateTime current = DateTime.Now;
		string timeStamp = "[" + current.ToString("HH:mm:ss") + "]";
		string colPrefix = $"{_escapeCharacter}[38;5;{fontColourCode.ToString()}m{timeStamp} [{userName}] {(applyColourToEntireMessage ? "" : _clearFontColour)}";
		string processedMessage = $"{colPrefix} {message} {_clearFontColour}";
		string dateYear = current.Date.ToString("dd/MM/yyyy");
		string processedMessageDate = $"\u000A{_escapeCharacter}{_asni256ColourCodeStart}{DefaultColours.Date}m{dateYear} {_clearFontColour} {processedMessage}";
		
		// TODO: Make sure all directories above the logfile exist before trying to append to the file.
		for (int i = 0; i < 5; i++) {
			try {
				await File.AppendAllTextAsync(LogFile.p, processedMessageDate);
				break;
			}
			catch (System.IO.IOException e) {
				// This can also mean the directory containing the log file doesn't exist
				/*Console.WriteLine($"{timeStamp} Oops, IO Exception!");
				Console.WriteLine($"e.Message = {e.Message}, e.Source = {e.Source}");
				foreach (DictionaryEntry data in e.Data) {
					Console.WriteLine($"data.Key = {data.Key}, data.Value = {data.Value}");
				}*/
				//Console.WriteLine($"{esc}[38;5;203m{timeStamp} [System] TODO: Fix this a better way {reset}");
				await Engine($"File lock: e = {e}", "System", DefaultColours.Error, true);
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
	public async Task WipeAsync() => await WipeAsync(UserName ?? "Null");

	public async Task WipeAsync(string user)
	{
		DateTime current = DateTime.Now;
		string timeStamp = $"[{current.ToString("HH:mm:ss")}]";
		string colPrefix = $"{_escapeCharacter}[38;5;{typeof(DefaultColours)?.GetField(user)?.GetValue(null)?.ToString()}m{timeStamp}";
		string dateYear = current.Date.ToString("dd/MM/yyyy");
		string tempMessage = $"{colPrefix} File Cleared by {user}{_clearFontColour}";
		string processedMessage = $"{_escapeCharacter}[38;5;{DefaultColours.Date.ToString()}m{dateYear} {_clearFontColour} {tempMessage}";
		await File.WriteAllTextAsync(LogFile.p, processedMessage);
	}

	public async Task BuildBanner(string text, bool applyColourToEntireMessage = false, int? fontColourCode = null, string userName = "")
	{
		await Out(_bannerBar);
		await Out(BuildMiddleLine(text, _bannerBar.Length));
		await Out(_bannerBar);
	}

	public static string BuildMiddleLine(string text, int barLength)
	{
		double spacesLength = barLength - text.Length;
		spacesLength = spacesLength / 2;
		var spacesLenghIsWholeNumber = spacesLength % 1 != 0.5;
		if (spacesLenghIsWholeNumber)
			return BuildSimpleLine(text, spacesLength);
		return BuildComplexLine(text, spacesLength);
	}

	private static string BuildSimpleLine(string text, double spacesLength)
	{
		var spaces = new string(' ', (int)spacesLength);
		return spaces + text + spaces;
	}

	private static string BuildComplexLine(string text, double spacesLength)
	{
		var roundedDownSpaces = (int)spacesLength;
		var spacesLeft = new string(' ', roundedDownSpaces);
		var spacesRight = new string(' ', roundedDownSpaces + 1);
		return spacesLeft + text + spacesRight;
	}

	[SetsRequiredMembers]
	public LogEngine(string LogFile, string? userName = null)
	{
		this.LogFile = new(LogFile, true);
		UserName = userName ?? UserName;
	}

	[SetsRequiredMembers]
	[JsonConstructor]
	public LogEngine(MyPath LogFile, string? userName = null)
	{
		this.LogFile = LogFile;
		UserName = userName ?? UserName;
	}

	[SetsRequiredMembers]
	public LogEngine(LogEngine original)
	{
		LogFile = original.LogFile;
		UserName = original.UserName;
	}

}
