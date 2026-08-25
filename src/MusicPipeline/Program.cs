// See https://aka.ms/new-console-template for more information
using MusicPipeline.Orchestrator;
// using MusicPipeline.Profiles;
// using System.Text.Json;
using MusicPipeline.Tools.LogEngine;
using System.Diagnostics;
// await Orchestrator.Start();

// Ok lets test stuff

ProcessStartInfo startInfo = new ProcessStartInfo();
startInfo.CreateNoWindow = false;
startInfo.UseShellExecute = false;
startInfo.FileName = @"C:\MusicTools\yt-dlp.exe";
startInfo.WindowStyle = ProcessWindowStyle.Hidden;
startInfo.RedirectStandardOutput = true;
startInfo.Arguments = @"--cookies C:\MusicTools\MusicPipeline\Sandbox\Config\cookies.txt --simulate --quiet https://www.youtube.com/watch?v=dQw4w9WgXcQ";

try
{
	using (Process? YTDLPProcess = Process.Start(startInfo))
	{
		//check for nulls first
		// Done?
		if (YTDLPProcess is null) {
			await LogEngine.Out(@"C:\MusicTools\MusicPipeline\Sandbox\Config\csLogFile.log", "It null");
		}
		string? currentLine;
		while (!((currentLine = (await YTDLPProcess.StandardOutput.ReadLineAsync())) == null)) {
			if (currentLine != null) {
				// 1. Flash it to your master console/global log stream
				await LogEngine.Out(@"C:\MusicTools\MusicPipeline\Sandbox\Config\csLogFile.log", currentLine);
			}
		}

		await YTDLPProcess.WaitForExitAsync();
	}
}
catch (System.ComponentModel.Win32Exception ex) {
	await LogEngine.Out(@"C:\MusicTools\MusicPipeline\Sandbox\Config\csLogFile.log", $"It broke {ex.Message}");
}


// Working!
// Yay!