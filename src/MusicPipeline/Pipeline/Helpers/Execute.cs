using System.Diagnostics;
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
		startInfo.Arguments = $"{arguments} 2>&1";

		return Process.Start(startInfo);
	}
}