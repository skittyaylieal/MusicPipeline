using System.IO;
using MusicPipeline.Tools.Hasher;
using MusicPipeline.Profiles;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Colours;
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


		// OK Directory.EnumerateFiles should work?
		/*
			by declaring masterFiles and mobileFiles outside the scope of the if statement
			they should be null by default, and you set them for the normal cases with your
			Directory.EnumerateFiles() method.
			With what you had before, the variables were scoped to the if, and the else respectively.
			They couldn't be used later on on what is now line 54.
		*/
		IEnumerable<string>? masterFiles; // ? means it initialises as null
		if (Directory.Exists(backupDir)) {
			masterFiles = Directory.EnumerateFiles(backupDir, songFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {masterFiles.Count()} song files in backup directory ({backupDir})", "LibraryScanner");
			var lrcFiles = Directory.EnumerateFiles(backupDir, lyricFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {lrcFiles.Count()} lyric files in backup directory ({backupDir})", "LibraryScanner");
			double masterSize = 0.00;
			foreach (var f in masterFiles) {masterSize += f.Length;}
		} else {
			Directory.CreateDirectory(backupDir);
		}

        IEnumerable<string>? mobileFiles;
        if (Directory.Exists(mobileDir)) {
			mobileFiles = Directory.EnumerateFiles(mobileDir, songFileSearchPattern, SearchOption.AllDirectories);
			LogEngine.Out(logFile, $"Found {mobileFiles.Count()} song files in mobile directory ({mobileDir})", "LibraryScanner");
			double mobileSize = 0.00;
			foreach (var f in mobileFiles) {mobileSize += f.Length;}
		} else {
			Directory.CreateDirectory(mobileDir);
		}

		//what are you trying to do with this line below?
		var files = masterFiles ?? mobileFiles;
		if (files is null) {
			// TODO, once theres multiple compressed folders then text should read "None of {List of folder names} exist or are empty. Exiting"
			LogEngine.Out(logFile, "Neither Backup nor Mobile Directory exist or are empty. Exiting", "LibraryScanner", DefaultColours.Error);
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