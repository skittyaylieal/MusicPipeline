using System.IO;
using MusicPipeline.Tools.Hasher;
using MusicPipeline.Profiles;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Orchestrator;

public class Scanner
{
	public async void ScanLibrary(string ProfileFile)
	{
		Profile activeProfile = ProfileManager.LoadActiveProfileContext(ProfileFile);
		string logFile = activeProfile.DiagLogFile;
		string backupDir = activeProfile.BackupDir;
		string mobileDir = activeProfile.MobileDir;
		List<DirectoryInfo>? compressedDirs = null; // Support for multiple compressed directories will be added at somepoint™
		//string rootDir = "IDFK why it needs this in the source";
		//^ The soure powershell code had this, so in case its neccessary i'm keeping it
		string songFileSearchPattern = "*.m4a"; // TODO add this, and most other variables or literals that could conceivably need changing, to the profile
		string lyricFileSearchPattern = "*.lrc";

		const int colourCode = 117;

		// OK Directory.EnumerateFiles should work?
		
		if (Directory.Exists(backupDir)) {
			var masterFiles = Directory.EnumerateFiles(backupDir, songFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {masterFiles.Count()} song files in backup directory ({backupDir})", "LibraryScanner", colourCode);
			var lrcFiles = Directory.EnumerateFiles(backupDir, lyricFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {lrcFiles.Count()} lyric files in backup directory ({backupDir})", "LibraryScanner", colourCode);
			double masterSize = 0.00;
			foreach (var f in masterFiles) {masterSize += f.Length;}
		} else {
			Directory.CreateDirectory(backupDir);
			var masterFiles = null;
		}
		if (Directory.Exists(mobileDir)) {
			var mobileFiles = Directory.EnumerateFiles(mobileDir, songFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {mobileFiles.Count()} song files in mobile directory ({mobileDir})", "LibraryScanner", colourCode);
			double mobileSize = 0.00;
			foreach (var f in mobileFiles) {mobileSize += f.Length;}
		} else {
			Directory.CreateDirectory(mobileDir);
			var mobileFiles = null;
		}

		var files = masterFiles ?? mobileFiles;
		if (files is null) {
			// TODO, once theres multiple compressed folders then text should read "None of {List of folder names} exist or are empty. Exiting"
			LogEngine.Out(logFile, "Neither Backup nor Mobile Directory exist or are empty. Exiting", "LibraryScanner", 203);
			return;
		}
		
		// Oh god now i need to make a database or something
		// I need a list of Identifiers

		foreach (var f in files) {

		}

		// so i have to go through every file in the masterfiles and make an Identifier object for it, then link the lrc and any compressed paths

		// Go through each and get info
		// Compile info and Metric cache

	}
}