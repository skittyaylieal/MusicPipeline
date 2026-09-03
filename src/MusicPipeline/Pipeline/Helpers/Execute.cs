using System.Diagnostics;
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Pipeline.Helpers.Execute;

public class Helper
{
	public static async Task<Process?> Execute(string path, string arguments)
	{
		
		ProcessStartInfo startInfo = new ProcessStartInfo();
		startInfo.CreateNoWindow = true;
		startInfo.UseShellExecute = false;
		startInfo.FileName = path;
		startInfo.WindowStyle = ProcessWindowStyle.Hidden;
		startInfo.RedirectStandardOutput = true;
		startInfo.RedirectStandardError = true;
		startInfo.Arguments = $"{arguments}";

		return Process.Start(startInfo);
	}

	public static async Task<List<string>> ProcessOutput(Process process, LogEngine l, int? colourCode)
	{
		StreamReader stdOut = process.StandardOutput;
		StreamReader stdErr = process.StandardError;
		List<string> lines = new();
		string lastOut = "";
		string lastErr = "";
		string? currOut = "";
		string? currErr = "";
		while (((currOut = await stdOut.ReadLineAsync()) != lastOut) ) {/*|| ((currErr = await stdErr.ReadLineAsync()) != lastErr)) {*/
			// So this runs whenever either the error line or output lines are different
			// Now to determine which
			if (currOut != lastOut) {
				await l.Out(currOut, colourCode);
				lines.Add(currOut);
			}
			if (currErr != lastErr) {
				int? errCode = colourCode;
				if (currErr.Contains("WARNING: ")) {errCode = DefaultColours.Warning;}
				else if (currErr.Contains("ERROR: ")) {errCode = DefaultColours.Error;}
				await l.Out(currErr, errCode);
				lines.Add(currErr);
			}
		}
		return lines;
		// Hopefully this works!

		// Ok we need to get the current line 
		// But only the line thats just been output
		// The error only updates when theres a new error line
		// So if the error has changed we have to output that
		// But stdOut only updates when a new line is output
		// More research on StreamReaders is required
	}
}