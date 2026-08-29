using System.Text.RegularExpressions;
using MusicPipeline.Profiles;
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Pipeline.Helpers.Parser;


public class Parser
{
	public async Task ParseYTDLPConfigFile(string profileFile, Profile context)
	{
		// TODO: Make this function
		Profile activeProfile = await ProfileManager.LoadActiveProfile(profileFile);
		LogEngine? l = new LogEngine(activeProfile.DiagLogFile);
		l.user = "Parser";
		string YTDLPOriginalConfigFilePath = activeProfile.YTDLPConfigFileOriginal;
		// Parse in the conf
		string? confFileContents = await File.ReadAllTextAsync(YTDLPOriginalConfigFilePath);
		if (confFileContents is null) {
			await l.Out($"YTDLP Config File {YTDLPOriginalConfigFilePath} is blank/invalid", DefaultColours.Error, true);
			return;
		}
		List<string> confFileLines = new List<string>(confFileContents.Split("\n"));
		List<string> confFileLinesFiltered = new();
		foreach (string line in confFileLines) {
			if (!Regex.IsMatch(line, @"^\s#")) {
				confFileLinesFiltered.Add(line);
			}
		}
		// Somehow handle the {} variables
		foreach (string line in confFileLinesFiltered) {
			Match match = Regex.Match(line, @"\{(\w+)\}");
			if (!match.Success) {
				continue;
			}
			string variable = match.ToString();
			await l.Out($"variable = {variable}", DefaultColours.Debug);
			// Uses Reflection somehow idfk
			// TODO: Write a better explanation
			string? replace = typeof(Profile).GetProperty(variable).GetValue(context).ToString();
			await l.Out($"typeof(Profile) = {typeof(Profile)}, Property = {typeof(Profile)?.GetProperty(variable)}, Value = {typeof(Profile)?.GetProperty(variable)?.GetValue(context)}, To String = {typeof(Profile)?.GetProperty(variable)?.GetValue(context).ToString()}. replace = {replace}", DefaultColours.Debug);
		}
		// Make a temp file
		// Change the profileFile to include an override
		// At the end of Download then remove the override
	}
}