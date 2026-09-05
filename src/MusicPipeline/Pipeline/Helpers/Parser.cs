using System.Text.RegularExpressions;
using MusicPipeline.Profiles;
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Pipeline.Helpers.Parser;

// TODO: Fix the bug where the output file is only like 
// -o "C:\MusicTools\MusicPipeline\Sandbox\Sandbox_Backup/%(artist|uploader).250s/%(album|play--download-archive "C:\MusicTools\MusicPipeline\Sandbox\Config\downloaded_history.txt"
// And nothing else

public class Parser
{
	public static async Task ParseYTDLPConfigFile(Profile context)
	{
		// TODO: Make this function
		// TODO: Make this use the active profile
		// No idea why it wont work
		//LogEngine? l = new LogEngine(context.DiagLogFile);
		LogEngine? l = context.LogEngine;
		l.user = "Parser";
		string YTDLPOriginalConfigFilePath = context.YTDLPConfigFileOriginal;
		// Parse in the conf
		string? confFileContents = await File.ReadAllTextAsync(YTDLPOriginalConfigFilePath);
		if (confFileContents is null) {
			await l.Out($"YTDLP Config File {YTDLPOriginalConfigFilePath} is blank/invalid", DefaultColours.Error, true);
			return;
		}
		List<string> confFileLines = new List<string>(confFileContents.Split("\n"));
		List<string> confFileLinesFiltered = new();
		List<string> parsedLines = new();
		foreach (string line in confFileLines) {
			if (!Regex.IsMatch(line, @"^\s#")) {
				confFileLinesFiltered.Add(line);
			} else {
				parsedLines.Add(line);
			}
		}
		// Somehow handle the {} variables
		
		foreach (string line in confFileLinesFiltered) {
			Match match = Regex.Match(line, @"\{(\w+)\}");
			if (!match.Success) {
				await l.Out($"Line {line} did not need any replacing");
				parsedLines.Add(line);
				continue;
			} 
			string variable = match.Groups[1].Value;
			await l.Out($"variable = {variable}", DefaultColours.Debug);
			// Uses Reflection somehow idfk
			// TODO: Write a better explanation
			string? replace = typeof(Profile).GetProperty(variable).GetValue(context).ToString();
			await l.Out($"typeof(Profile) = {typeof(Profile)}, Property = {typeof(Profile)?.GetProperty(variable)}, Value = {typeof(Profile)?.GetProperty(variable)?.GetValue(context)}, To String = {typeof(Profile)?.GetProperty(variable)?.GetValue(context).ToString()}. replace = {replace}", DefaultColours.Debug);
			string updatedLine = Regex.Replace(line, @"\{(\w+)\}", replace);
			parsedLines.Add(updatedLine);
		}

		string parentDir = Path.GetDirectoryName(YTDLPOriginalConfigFilePath);
		string tempFilePath = $@"{parentDir}\yt-dlp{Guid.NewGuid()}.conf";
		await File.WriteAllTextAsync(tempFilePath, String.Join("\n", parsedLines));
		Profile activeProfile = await ProfileManager.LoadActiveProfile(context.ProfileFile);
		activeProfile.YTDLPConfigFile = tempFilePath;
		await ProfileManager.SaveProfile(context.ProfileFile, activeProfile);
		// Make a temp file
		// Change the profileFile to include an override
		// At the end of Download then remove the override
	}
}