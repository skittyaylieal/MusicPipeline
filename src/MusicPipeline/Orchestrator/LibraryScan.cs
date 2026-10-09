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
	public async void ScanLibrary()
    {
        Profile activeProfile = await ProfileManager.LoadActiveProfileAsync();
        l = activeProfile.LogEngine;
        l.user = "LibraryScanner";
        MyPath backupDir = activeProfile.BackupDir;
        List<MyPath> compressedDirs = activeProfile.CompressedDirs;
        //List<DirectoryInfo>? compressedDirs = null; // Support for multiple compressed directories will be added at somepoint™
        //string rootDir = "IDFK why it needs this in the source";
        //^ The soure powershell code had this, so in case its neccessary i'm keeping it


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

        IEnumerable<string> masterFiles = await GetMasterFiles();

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

        Dictionary<string,List<string>> compressedFiles = await GetCompressedFiles();

        //what are you trying to do with this line below?
        //var files = masterFiles ?? mobileFiles;
        //maxDownloadThreads = maxDownloadThreads < playlists.Count() ? playlists.Count() : maxDownloadThreads;
        IEnumerable<string> files = masterFiles.Count() < (await ListTools.MaxCountAnyList(compressedFiles)).Length ? compressedFiles[(await ListTools.MaxCountAnyList(compressedFiles)).Name] : masterFiles;
        await (files?.Count() > masterFiles?.Count() ? l.Out($"Compressed Directory {(await ListTools.MaxCountAnyList(compressedFiles)).Name} has {(await ListTools.MaxCountAnyList(compressedFiles)).Length - masterFiles.Count()} more songs than Master", DefaultColours.Warning, true) : l.Out($"The largest compressed directory, {(await ListTools.MaxCountAnyList(compressedFiles)).Name}, has {(await ListTools.MaxCountAnyList(compressedFiles)).Length - masterFiles?.Count()} fewer songs that Master. Declare this directory a subset to dismiss.", DefaultColours.Warning, true));
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

    private async Task<IEnumerable<string>> GetMasterFiles()
    {
        Profile ap = await ProfileManager.LoadActiveProfileAsync();
        MyPath backupDir = ap.BackupDir;
        string songFileSearchPattern = ap.SongFileSearchPattern;
        string lyricFileSearchPattern = ap.LyricFileSearchPattern;
        // FYI, doesn't need to know colour code as the LogEngine works out the correct colour from the Username
        // As long as you use "LibraryScanner" then it'll get the right colour
        List<string> masterFiles = new();
        if (Directory.Exists(backupDir.p))
        {
            masterFiles = new(Directory.EnumerateFiles(backupDir.p, songFileSearchPattern, SearchOption.AllDirectories));
            await l.Out($"Found {masterFiles.Count()} song files in backup directory ({backupDir})");
            var lrcFiles = Directory.EnumerateFiles(backupDir.p, lyricFileSearchPattern, SearchOption.AllDirectories);
            await l.Out($"Found {lrcFiles.Count()} lyric files in backup directory ({backupDir})");
            double masterSize = 0.00;
            foreach (var f in masterFiles) { masterSize += f.Length; }
        }
        else
        {
            Directory.CreateDirectory(backupDir.p);
        }

        return masterFiles;
    }


    private async Task<Dictionary<string,List<string>>> GetCompressedFiles()
    {
        Profile ap = await ProfileManager.LoadActiveProfileAsync();
        List<MyPath> compressedDirs = ap.CompressedDirs;
        string songFileSearchPattern = ap.SongFileSearchPattern;
        Dictionary<string,List<string>> compressedFiles = new();
        List<string> directoryFiles = new();
        foreach (MyPath mobileDir in compressedDirs) {
            if (Directory.Exists(mobileDir.p))
            {
                directoryFiles = new(Directory.EnumerateFiles(mobileDir.p, songFileSearchPattern, SearchOption.AllDirectories));
                await l.Out($"Found {directoryFiles.Count()} song files in compressed directory ({mobileDir})");
                double mobileSize = 0.00;
                foreach (var f in directoryFiles) { mobileSize += f.Length; }
                compressedFiles.Add(mobileDir.p,  directoryFiles);
            }
            else
            {
                Directory.CreateDirectory(mobileDir.p);
            }
        }
        return compressedFiles;
    }
}