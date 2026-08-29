using System.IO;
using MusicPipeline.Profiles;
using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Tools.Hasher;
using MusicPipeline.Tools.ListTools;
namespace MusicPipeline.Orchestrator;

// TODO: Fix getmasterfiles

public class Scanner
{
    private LogEngine l;
	public async void ScanLibrary(string ProfileFile)
    {
        Profile activeProfile = await ProfileManager.LoadActiveProfile(ProfileFile);
        l = activeProfile.LogEngine;
        l.user = "LibraryScanner";
        string backupDir = activeProfile.BackupDir;
        List<string> compressedDirs = activeProfile.CompressedDirs;
        //List<DirectoryInfo>? compressedDirs = null; // Support for multiple compressed directories will be added at somepoint™
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

        IEnumerable<string>? masterFiles = await GetMasterFiles(backupDir, songFileSearchPattern, lyricFileSearchPattern);

        //so this refactor benefits us in many ways
        //1) ScanLibrary() is shorter and more expressive.
        //2) the piece of code that is now GetMasterFiles is more testable.
        //3) seeing it as GetMasterFiles() can spur some ideas like "hey, this is real similar to my next step of getting mobile files!"
        //      maybe a single method could handle both? (yes probably, and we can look into that later)
        // A single method could probably handle both but I think a compressed dir method would be better
        // I'm thinking how to make the mobile directory use the compressed dirs list instead of being a special case
        //4) I don't know how it is in Sublime, but for VS if you click the method name usage, and press F12, it goes to the definition of that method.
        //      I mention this because my coworker hates when I extract to method refactor, because he claims it makes it harder for him to read...
        //      Addressing what I feel is an invalid criticism of the refactor.
        //5) IDK, I'm just trying to come up with a bunch of junk :) do you like having me as a tutor? I'm enjoying myself!
        //6) I'm sure there are lots of other reasons too!

        Dictionary<string,IEnumerable<string>?>? compressedFiles = await GetCompressedFiles(compressedDirs, songFileSearchPattern);

        //what are you trying to do with this line below?
        //var files = masterFiles ?? mobileFiles;
        //maxDownloadThreads = maxDownloadThreads < playlists.Count() ? playlists.Count() : maxDownloadThreads;
        IEnumerable<string>? files = masterFiles?.Count() < Int32.Parse(await ListTools.MaxCountAnyList(compressedFiles)) ? compressedFiles[await ListTools.MaxCountAnyList(compressedFiles, true)] : masterFiles;
        await (files?.Count() > masterFiles?.Count() ? l.Out($"Compressed Directory {await ListTools.MaxCountAnyList(compressedFiles, true)} has {Int32.Parse(await ListTools.MaxCountAnyList(compressedFiles)) - masterFiles?.Count()} more songs than Master", DefaultColours.Warning, true) : l.Out($"The largest compressed directory, {await ListTools.MaxCountAnyList(compressedFiles, true)}, has {Int32.Parse(await ListTools.MaxCountAnyList(compressedFiles)) - masterFiles?.Count()} fewer songs that Master. Declare this directory a subset to dismiss.", DefaultColours.Warning, true));
        //var files;
        if (files is null)
        {
            // TODO, once theres multiple compressed folders then text should read "None of {List of folder names} exist or are empty. Exiting"
            await l.Out("Neither Backup nor Mobile Directory exist or are empty. Exiting", DefaultColours.Error, true);
            return;
        }

        // Oh god now i need to make a database or something
        // I need a list of Identifiers

        foreach (string f in files)
        {

        }

        // so i have to go through every file in the masterfiles and make an Identifier object for it, then link the lrc and any compressed paths

        // Go through each and get info
        // Compile info and Metric cache

    }

    private async Task<IEnumerable<string>?> GetMasterFiles(string backupDir, string songFileSearchPattern, string lyricFileSearchPattern)
    {
        //maybe tomorrow we'll break this method into smaller pieces because it's doing too many disparate things.
        // FYI, doesn't need to know colour code as the LogEngine works out the correct colour from the Username
        // As long as you use "LibraryScanner" then it'll get the right colour
        IEnumerable<string>? masterFiles = null;
        if (Directory.Exists(backupDir))
        {
            masterFiles = Directory.EnumerateFiles(backupDir, songFileSearchPattern, SearchOption.AllDirectories);
            await l.Out($"Found {masterFiles.Count()} song files in backup directory ({backupDir})");
            var lrcFiles = Directory.EnumerateFiles(backupDir, lyricFileSearchPattern, SearchOption.AllDirectories);
            await l.Out($"Found {lrcFiles.Count()} lyric files in backup directory ({backupDir})");
            double masterSize = 0.00;
            foreach (var f in masterFiles) { masterSize += f.Length; }
        }
        else
        {
            Directory.CreateDirectory(backupDir);
        }

        return masterFiles;
    }


    private async Task<Dictionary<string,IEnumerable<string>?>?> GetCompressedFiles(List<string> compressedDirs, string songFileSearchPattern)
    {
        Dictionary<string,IEnumerable<string>?>? compressedFiles = null;
        IEnumerable<string>? directoryFiles = null;
        foreach (string mobileDir in compressedDirs) {
            if (Directory.Exists(mobileDir))
            {
                directoryFiles = Directory.EnumerateFiles(mobileDir, songFileSearchPattern, SearchOption.AllDirectories);
                await l.Out($"Found {directoryFiles.Count()} song files in compressed directory ({mobileDir})");
                double mobileSize = 0.00;
                foreach (var f in directoryFiles) { mobileSize += f.Length; }
                compressedFiles.Add(mobileDir,  directoryFiles);
            }
            else
            {
                Directory.CreateDirectory(mobileDir);
            }
        }
        return compressedFiles;
    }
}