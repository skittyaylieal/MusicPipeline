using System.Diagnostics;
using MusicPipeline.Results;
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
		startInfo.Arguments = $"{arguments}";

		return Process.Start(startInfo);
	}

	public static async Task<Result> RunSilentAsync(string path, string arguments, string user, string procName)
	{
		DateTime start = DateTime.UtcNow;
		ProcessStartInfo startInfo = new ProcessStartInfo();
		startInfo.CreateNoWindow = true;
		startInfo.UseShellExecute = false;
		startInfo.FileName = path;
		startInfo.WindowStyle = ProcessWindowStyle.Hidden;
		startInfo.RedirectStandardOutput = true;
		startInfo.Arguments = $"{arguments}";

		Process? proc = Process.Start(startInfo);
		try
		{
			using (proc)
			{
				if (proc is null) {
					DateTime endError = DateTime.UtcNow;
					TimeSpan elapsedError = endError - start;
					return new Result(user, false, elapsedError, $"{procName} is Null");
				}
				/*
				string? currentLine;
				while (!((currentLine = (await proc.StandardOutput.ReadLineAsync())) == null)) {
					if (currentLine != null) {
						await l.Out(currentLine);
					}
				}
				*/

				await proc.WaitForExitAsync();
				DateTime end = DateTime.UtcNow;
				TimeSpan elapsed = end - start;
				return new Result(user, true, elapsed);
			}
		}
		catch (System.ComponentModel.Win32Exception ex)
		{
			DateTime end = DateTime.UtcNow;
			TimeSpan elapsed = end - start;
			return new Result(user, false, elapsed, ex.Message);
		}
	}

}