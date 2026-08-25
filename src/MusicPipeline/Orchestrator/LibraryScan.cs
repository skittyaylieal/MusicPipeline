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
        Profile activeProfile = await ProfileManager.LoadActiveProfile(ProfileFile);
        string logFile = activeProfile.DiagLogFile;
        string backupDir = activeProfile.BackupDir;
        string mobileDir = activeProfile.MobileDir;
        //List<DirectoryInfo>? compressedDirs = null; // Support for multiple compressed directories will be added at somepoint™
        //string rootDir = "IDFK why it needs this in the source";
        //^ The soure powershell code had this, so in case its neccessary i'm keeping it
        string songFileSearchPattern = "*.m4a"; // TODO add this, and most other variables or literals that could conceivably need changing, to the profile
        string lyricFileSearchPattern = "*.lrc";

        const int colourCode = 117;

        // OK Directory.EnumerateFiles should work?
        /*
			by declaring masterFiles and mobileFiles outside the scope of the if statement
			they should be null by default, and you set them for the normal cases with your
			Directory.EnumerateFiles() method.
			With what you had before, the variables were scoped to the if, and the else respectively.
			They couldn't be used later on on what is now line 54.
		*/
        // change my comments above so that it says whatever helps you learn best instead of beling like dialogue from me to you.

        //you have a nice clean chunk of code down here.
        //this is a good opportunity to "extract to method" refactor.
        //currently ScanLibrary() is long. There's a code smell named "long method".
        //methods should be short because it helps make everything a little more "atomic".
        //there are some gurus in the programming scene that are real sticklers for this, but you can take it with a grain of salt.

        //so what does this chunk of code do?
        //that's where we'll start with moving it to a method.
        //figuring out the name.
        //it
        //checks for the backup directory and creates one if it doesn't already exist
        //we can ignore the logging when considering what to name it, that's not the primary purpose of the method
        //it creates a list of master files
        //it creates a list of lyric files
        //it calculates the number of letters of all file names? i think, but never uses the variable
        //  for unused variables, either use them or lose them :)
        //ok so I'll name it GetMasterFiles()

        IEnumerable<string>? masterFiles = await GetMasterFiles(logFile, backupDir, songFileSearchPattern, lyricFileSearchPattern, colourCode);

        //so this refactor benefits us in many ways
        //1) ScanLibrary() is shorter and more expressive.
        //2) the piece of code that is now GetMasterFiles is more testable.
        //3) seeing it as GetMasterFiles() can spur some ideas like "hey, this is real similar to my next step of getting mobile files!"
        //      maybe a single method could handle both? (yes probably, and we can look into that later)
        //4) I don't know how it is in Sublime, but for VS if you click the method name usage, and press F12, it goes to the definition of that method.
        //      I mention this because my coworker hates when I extract to method refactor, because he claims it makes it harder for him to read...
        //      Addressing what I feel is an invalid criticism of the refactor.
        //5) IDK, I'm just trying to come up with a bunch of junk :) do you like having me as a tutor? I'm enjoying myself!
        //6) I'm sure there are lots of other reasons too!

        IEnumerable<string>? mobileFiles = null;
        if (Directory.Exists(mobileDir))
        {
            mobileFiles = Directory.EnumerateFiles(mobileDir, songFileSearchPattern, SearchOption.AllDirectories);
            await LogEngine.Out(logFile, $"Found {mobileFiles.Count()} song files in mobile directory ({mobileDir})", "LibraryScanner", colourCode);
            double mobileSize = 0.00;
            foreach (var f in mobileFiles) { mobileSize += f.Length; }
        }
        else
        {
            Directory.CreateDirectory(mobileDir);
        }

        //what are you trying to do with this line below?
        var files = masterFiles ?? mobileFiles;
        if (files is null)
        {
            // TODO, once theres multiple compressed folders then text should read "None of {List of folder names} exist or are empty. Exiting"
            await LogEngine.Out(logFile, "Neither Backup nor Mobile Directory exist or are empty. Exiting", "LibraryScanner", DefaultColours.Error);
            return;
        }

        // Oh god now i need to make a database or something
        // I need a list of Identifiers

        foreach (var f in files)
        {

        }

        // so i have to go through every file in the masterfiles and make an Identifier object for it, then link the lrc and any compressed paths

        // Go through each and get info
        // Compile info and Metric cache

    }

    private static async Task<IEnumerable<string>?> GetMasterFiles(string logFile, string backupDir, string songFileSearchPattern, string lyricFileSearchPattern, int colourCode)
    {
        //maybe tomorrow we'll break this method into smaller pieces because it's doing too many disparate things.
        IEnumerable<string>? masterFiles = null;
        if (Directory.Exists(backupDir))
        {
            masterFiles = Directory.EnumerateFiles(backupDir, songFileSearchPattern, SearchOption.AllDirectories);
            await LogEngine.Out(logFile, $"Found {masterFiles.Count()} song files in backup directory ({backupDir})", "LibraryScanner", colourCode);
            var lrcFiles = Directory.EnumerateFiles(backupDir, lyricFileSearchPattern, SearchOption.AllDirectories);
            await LogEngine.Out(logFile, $"Found {lrcFiles.Count()} lyric files in backup directory ({backupDir})", "LibraryScanner", colourCode);
            double masterSize = 0.00;
            foreach (var f in masterFiles) { masterSize += f.Length; }
        }
        else
        {
            Directory.CreateDirectory(backupDir);
        }

        return masterFiles;
    }
}