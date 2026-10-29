using System.Text.RegularExpressions;
using MusicPipeline.Songs;
using MusicPipeline.Strings;
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Pipeline.Helpers.Download;

public class YTDLPHelpers
{
	private const string _uRLPattern = @"\s*\[youtube:tab\]\s*Extracting\s*URL:\s*(https:\/\/(?:music\.y|www\.y|y)outube.co(?:m|\.uk)\/playlist\?list=.*)";
	//[youtube:tab] Extracting URL: https://music.youtube.com/playlist?list=PLqcuYaDDgyad1-o1HTVnTiZKoluY5enwk
	//good job escaping these square brackets. I didn't understand why until I tested it.
	private const string _songDeclarePattern = @"\s*\[download\]\s*Downloading\s*item\s*(\d+)\s*of\s*(\d+)";
	public static async Task<string> GetUrlFromRunLogFile(MyPath path)
	{
		//l.UserName = "YTDLPHelper";
		// Get all text in file
		string match = "";
		string allFileText = await File.ReadAllTextAsync(path.p);
		List<string> allFileLines = new(allFileText.Split("\n"));
		// Find the url
		foreach (string line in allFileLines) 
		{
			//await l.Out(line, DefaultColours.Debug);
			if (Regex.IsMatch(line, _uRLPattern)) 
			{
				//await l.Out("Matched!", DefaultColours.Debug);
				match = Regex.Match(line, _uRLPattern).Groups[1].Value; // Apparently Groups[0] is the whole match
				//ya, GroupCollection is interesting. I learned about it when first looking at this.
				//https://learn.microsoft.com/en-us/dotnet/api/system.text.regularexpressions.groupcollection?view=net-10.0 

				//await l.Out($"Regex.Match = {Regex.Match(line, _uRLPattern)}, Value = {Regex.Match(line, _uRLPattern).Value}, Groups = {Regex.Match(line, _uRLPattern).Groups}, Groups[0] = {Regex.Match(line, _uRLPattern).Groups[0]}, Groups[1] = {Regex.Match(line, _uRLPattern).Groups[1]}, Groups.Count = {Regex.Match(line, _uRLPattern).Groups.Count}", DefaultColours.Debug);
				break;
			}
		}
		//the above foreach and if don't require curly braces.
		//I'll leave them there if you want them, but C# convention says that opening curly brace should be on a new line in cases like this.
		//I think javascript and java do it with the opening curly brace on the same line, but C# convention explicitly says to not do that.
		//the compiler doesn't care, it's only for human eyes.
		return match;
	}

	//we can use expression body for this method because it's a single line (if you want)
	public static async Task<Dictionary<int, SongIdentifier>> GetSongsFromRunLogFile(MyPath path) 
		=> (await GetAllSongsFromRunLogFile(path)).songs;

	public static async Task<(int total, Dictionary<int, SongIdentifier> songs)> GetAllSongsFromRunLogFile(MyPath path)
	{
		//l.UserName = "YTDLPHelper";
		int total = 0;
		// Get all text in file
		//MatchCollection? matchCollection = null;
		string allFileText = await File.ReadAllTextAsync(path.p);
		Dictionary<int, string> allFileLinesNumbered = await StringHelpers.SplitLinesDict(allFileText);

		//Console.WriteLine(allFileText);
		//Console.WriteLine($"allFileLinesNumbered = {allFileLinesNumbered}");
		//curly braces optional below
		//foreach (KeyValuePair<int, string> x in allFileLinesNumbered) 
			//Console.WriteLine($"{x.Key} : {x.Value}");
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






		}*/
		#endregion codeblock
		//i don't understand why you're using inSong to put every other line in the alternate dictionary??
		//is there a better way to determine which dictionary to add a line to besides the order that it occurred in allFileLinesNumbered?
		//for lists and dictionaries order shouldn't matter, and we shouldn't depend on the order being a certain way.
		//when order matters, array respects order
		// Got it. I just don't know a good way to go through a list and then dynamically add to stuff. I will do it better
		bool inSong = false;
		int songNum = 0;

		Dictionary<int, List<string>> songs = new();

		
		//await l.Out("Debugging:", DefaultColours.Debug);
		//foreach (KeyValuePair<int, string> kvp in allFileLinesNumbered) {
		//	await l.Out($"kvp.Key = {kvp.Key}", DefaultColours.Debug);
		//	await l.Out($"kvp.Value = {kvp.Value}", DefaultColours.Debug);
		//}
		

		for (int i = 0; i < allFileLinesNumbered.Count; i++) {
			string val = allFileLinesNumbered[i];
			// Doing it like this rather than foreach, garuntees it to be in line order
			if (Regex.IsMatch(val, _songDeclarePattern)) {
				//await l.Out("Matched", DefaultColours.Debug);
				// If the current line is a song decleration
				inSong = true;
				//await l.Out($"Line = {val}", DefaultColours.Debug);
				//I think here we probably only care about the first match.
				//Console.WriteLine($"First capture value = {matches[0].Value}, Regex Capture count = {matches.Count}, first Matches() match = {matches[0].Value}, Matches() = {matches}");				
				(int, int) numbersPair = GetFirstTwoNumbersInPattern(val, _songDeclarePattern);
				songNum = numbersPair.Item1;
				total = numbersPair.Item2;
				//await l.Out($"First value in match = {songNum}, Second value in match = {total}", DefaultColours.Debug);

				songs.Add(songNum, [val]);
				//await l.Out($"songs = {songs.ToString()}", DefaultColours.Debug);
				//await l.Out($"songNum = {songNum.ToString()}", DefaultColours.Debug);
				//await l.Out($"songs[songNum] = {songs[songNum].ToString()}", DefaultColours.Debug);
				//await l.Out($"i = {i}", DefaultColours.Debug);
				//foreach (string x in songs[songNum])
				//	await l.Out($"x = {x}", DefaultColours.Debug);
				continue; // Continue to not double count
			}
			// IF I have any issues with things that are after the end of a song but before the start of the next, add a pattern for the end of the song
			else if (inSong == true) {
				//await l.Out("In song", DefaultColours.Debug);
				songs[songNum].Add(val);
				//await l.Out($"songs[songNum] = {songs[songNum].ToString()}", DefaultColours.Debug);
				//await l.Out($"i = {i}", DefaultColours.Debug);
				//foreach (string x in songs[songNum])
				//	await l.Out($"x = {x}", DefaultColours.Debug);
			}
			//else {
			//	await l.Out("Not in song nor matched", DefaultColours.Debug);
			//	await l.Out($"val = {val}, i = {i}", DefaultColours.Debug);
			//	await l.Out($"songs.Count = {songs.Count}, inSong = {inSong}", DefaultColours.Debug);
			//}
		}


		// That was easy https://www.youtube.com/watch/3YmMNpbFjp0



		// So we now have a dictionary of all the text for each song
		// Now we need to make a songIdentifier from that
		// I shall make another helper method!

		return new();
	}

	public static (int, int) GetFirstTwoNumbersInPattern(string val, string songDeclarePattern)
	{
		var firstMatch = Regex.Match(val, songDeclarePattern);
		var firstNum = int.Parse(firstMatch.Groups[1].Value);
		var secondNum = int.Parse(firstMatch.Groups[2].Value);
		return new(firstNum,secondNum);
	}
}
