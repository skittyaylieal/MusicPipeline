using System.Text.RegularExpressions;
using MusicPipeline.Songs;
//using MusicPipeline.Strings;
namespace MusicPipeline.Pipeline.Helpers.Download;

//renamed this file to match the class name.
public class YTDLPHelpers
{
	//these fields are only used in this class, and so shouldn't be made visible.
	//they are never modified, and their values are known at compilation, so they should be const.
	//nameing convention for private members is camelCase with a leading underscore.
	private const string _uRLPattern = @"\[youtube:tab\] Extracting URL: (https://(?:music.y|www.y|y)outube.co(?:m|.uk)/playlist?list=.*)";
	private const string _songDeclarePattern = @"\[download\] Downloading item (\d+) of (\d+)";
	public static async Task<string> GetUrlFromRunLogFile(string path)
	{
		// Get all text in file
		string match = "";
		string allFileText = await File.ReadAllTextAsync(path);
		List<string> allFileLines = new(allFileText.Split("\n"));
		// Find the url
		foreach (string line in allFileLines) 
		{
			if (Regex.IsMatch(line, _uRLPattern)) 
			{
				match = Regex.Match(line, _uRLPattern).Value;
			}
		}
		//the above foreach and if don't require curly braces.
		//I'll leave them there if you want them, but C# convention says that opening curly brace should be on a new line in cases like this.
		//I think javascript and java do it with the opening curly brace on the same line, but C# convention explicitly says to not do that.
		//the compiler doesn't care, it's only for human eyes.
		return match;
	}

	//we can use expression body for this method because it's a single line (if you want)
	public static async Task<Dictionary<int, SongIdentifier>> GetSongsFromRunLogFile(string path) 
		=> (await GetAllSongsFromRunLogFile(path)).songs;

	public static async Task<(int total, Dictionary<int, SongIdentifier> songs)> GetAllSongsFromRunLogFile(string path)
	{
		int total = 0;
		// Get all text in file
		MatchCollection? matchCollection = null;
		string allFileText = await File.ReadAllTextAsync(path);
		Dictionary<int, string> allFileLinesNumbered = new(await StringHelpers.SplitLinesDict(allFileText));

		Console.WriteLine(allFileText);
		Console.WriteLine(allFileLinesNumbered);
		//curly braces optional below
		foreach (KeyValuePair<int, string> x in allFileLinesNumbered) 
		{
			Console.WriteLine($"{x.Key} : {x.Value}");
		}
		#region codeblock
		/*Dictionary<(int line, int song), (int line, int songEnd)> songToLine = new();
		foreach (KeyValuePair<int, string> kvp in allFileLinesNumbered) {
			int curSong = 0;
			if (Regex.IsMatch(kvp.Value, SongDeclarePattern)) {
				matchCollection = Regex.Matches(kvp.Value, SongDeclarePattern);
				foreach (Match match in matchCollection) {
					if (i == 0) {
						curSong = int.Parse(match.Value);
					} else {
						total = int.Parse(match.Value);
					}
					i++;
				}
			}
			songToLine.Append((kvp.Key, curSong));
		}
		// Get all the text between each song decleration, including the number
		foreach ((int lineNum, string line) in allFileLinesNumbered) {
			// So we have the current line number
			// We need to test if it is between any pair 

		}*/
		#endregion codeblock
		//i don't understand why you're using inSong to put every other line in the alternate dictionary??
		//is there a better way to determine which dictionary to add a line to besides the order that it occurred in allFileLinesNumbered?
		//for lists and dictionaries order shouldn't matter, and we shouldn't depend on the order being a certain way.
		//when order matters, array respects order
		bool inSong = false;
		Dictionary<int, int> songStarts = new();
		Dictionary<int, int> songEnds = new();
		foreach (KeyValuePair<int, string> kvp in allFileLinesNumbered)  // Loops through all the lines
		{
			//used Match() here instead.
			var match = Regex.Match(kvp.Value, _songDeclarePattern);
			if (match.Success) 
			{
				// So we have the current line number as well as the matches
				var thisDownloadItemNumber = int.Parse(match.Groups[1].Value);
				var totalNumberOfDownloadItems = int.Parse(match.Groups[2].Value);
				if (!inSong)  // Adds the song data to the 2 lists
				{
					inSong = true;
					//I don't think this will work anymore because match.Value should return the entire match... which isn't an int
					//I don't know what you're attempting to do here.
					//the values in allFileLinesNumbered should be strings that may or may not match _songDeclarePattern
					//when they match the first value I named thisDownloadItemNumber up above, and the second number I named totalNumberOfDownloadItems up above.
					//you can throw this all away if it doesn't help, but I bet you're probably wanting Match().
					songStarts.Add(kvp.Key, thisDownloadItemNumber); 
				} 
				else 
				{
					inSong = false;
					songEnds.Add(kvp.Key - 1, thisDownloadItemNumber); // Adds the previous line number
				}
			}
		}

		Console.WriteLine(songStarts);
		Console.WriteLine(songEnds);
		foreach (KeyValuePair<int, int> x in songStarts) {
			Console.WriteLine(x.Key);
			Console.WriteLine(x.Value);
		}


		// Now we have list of start
		inSong = false;
		int songNum = 0;
		Dictionary<int, List<string>> songs= new();
		foreach (KeyValuePair<int, string> kvp in allFileLinesNumbered) {
			if (songStarts.TryGetValue(kvp.Key, out int value)) {
				inSong = true;
				songNum = value;
				songs.Add(value, new(kvp.Key));
			}
			if (inSong)
				songs[songNum].Add(kvp.Value);
			if (songEnds.TryGetValue(kvp.Key, out int endVal) && endVal == songNum) {
				inSong = false;
			} else if (endVal != songNum) {
				//await l.Out("Oh dear"); // IF I ever get round to making that system where the activeProfile is contained in the ProfileManager class, then use that here
				// TODO: Handle this (If it's even a possible case??)
			}
		}

		Console.WriteLine(songs);
		foreach (KeyValuePair<int, List<string>> x in songs) {
			Console.WriteLine(x);
			Console.WriteLine(x.Key);
			foreach (string v in x.Value) {
				Console.WriteLine(v);
			}
		}

		// So we now have a dictionary of all the text for each song
		// Now we need to make a songIdentifier from that
		// I shall make another helper method!

		// Go through each match and check it for being a song

		return new();
	}
}
