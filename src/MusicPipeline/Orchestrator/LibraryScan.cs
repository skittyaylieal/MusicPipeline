using System.IO;
using MusicPipeline.Tools.Hasher;
using MusicPipeline.Profiles;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Orchestrator;

public class Scanner
{
	// Class Colour Code is 177
	public async void ScanLibrary(string ProfileFile)
	{
		Profile activeProfile = ProfileManager.LoadActiveProfileContext(ProfileFile);
		string logFile = activeProfile.DiagLogFile;
		string backupDir = activeProfile.BackupDir;
		string mobileDir = activeProfile.MobileDir;
		string rootDir = "IDFK why it needs this in the source";
		string songFileSearchPattern = "*.m4a"; // TODO add this, and most other variables or literals that could conceivably need changing, to the profile
		string lyricFileSearchPattern = "*.lrc";


		// OK Directory.EnumerateFiles should work?
		
		if (Directory.Exists(backupDir) {
			var masterFiles = Directory.EnumerateFiles(backupDir, songFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {masterFiles.Count()} song files in backup directory ({backupDir})", "LibraryScanner", 177);
			var lrcFiles = Directory.EnumerateFiles(backupDir, lyricFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {lrcFiles.Count()} lyric files in backup directory ({backupDir})", "LibraryScanner", 177);
			double masterSize = 0.00;
			foreach (var f in masterFiles) {masterSize += f.Length;}
		} else {
			Directory.CreateDirectory(backupDir);
		}
		if (Directory.Exists(mobileDir) {
			var mobileFiles = Directory.EnumerateFiles(mobileDir, songFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {mobileFiles.Count()} song files in mobile directory ({mobileDir})", "LibraryScanner", 177);
			double mobileSize = 0.00;
			foreach (var f in mobileFiles) {mobileSize += f.Length;}
		} else {
			Directory.CreateDirectory(mobileDir);
		}
		
		// Oh god now i need to make a database or something
		
		// Go through each and get info
		// Compile info and Metric cache

	}
}