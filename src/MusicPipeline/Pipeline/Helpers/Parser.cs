using System.Text.RegularExpressions;
using MusicPipeline.Profiles;
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Pipeline.Helpers.Parser;


public class Parser
{
	public async Task ParseYTDLPConfigFile(string profileFile)
	{
		// TODO: Make this function
		Profile activeProfile = await ProfileManager.LoadActiveProfile(profileFile);
		string logFile = activeProfile.DiagLogFile;
		string YTDLPOriginalConfigFilePath = activeProfile.YTDLPConfigFileOriginal;
		// Parse in the conf
		byte[] confFileBytes = File.ReadAllBytes(YTDLPOriginalConfigFilePath);
		string? confFileContents = confFileBytes.ToString();
		if (confFileContents is null) {
			await LogEngine.Out(logFile, $"YTDLP Config File {YTDLPOriginalConfigFilePath} is blank/invalid");
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
			Match match = Regex.Match(line, "({.*})");
			if (!match.Success) {
				continue;
			}
			// Use Reflection somehow idfk
		}
		// Make a temp file
		// Change the profileFile to include an override
		// At the end of Download then remove the override
	}
}