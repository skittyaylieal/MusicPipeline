using System.Text.Json;
using System.Collections.Generic;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Profiles;



public class ProfileFile
{
    // public static readonly Profile DefaultProfile = DefaultProfiles.DefaultProfile;
    public static readonly Profile DefaultProfile = new Profile
    {
        Name = "Default",
        BackupDir = @"C:\Users\filip\Music\YT_Music_Backup",
        MobileDir = @"C:\Users\filip\Music\YT_Music_Mobile",
        BrokenSongsFile = @"C:\MusicTools\MusicPipeline\Config\broken_songs.json",
        DiagLogFile = @"C:\MusicTools\MusicPipeline\Config\web_console_stream.log",
        CacheFile = @"C:\MusicTools\MusicPipeline\Config\dashboard_cache.json",
        TimingFile = @"C:\MusicTools\MusicPipeline\Config\timing_history.json",
        CookieFile = @"C:\MusicTools\MusicPipeline\Config\cookies.txt",
        HistoryFile = @"C:\MusicTools\MusicPipeline\Config\downloaded_history.txt",
        YTDLPExe = @"C:\MusicTools\yt-dlp.exe",
        FFmpegExe = @"C:\MusicTools\ffmpeg.exe",
        FirefoxExe = @"C:\Program Files\Mozilla Firefox\firefox.exe",
        CheckURL = @"https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        SleepInterval = 4,
        MaxSleepInterval = 12, 
        SleepRequests = 3,
        MaxCompressThreads = 8,
        MaxDownloadThreads = 6,
        MaxLyricThreads = 3,
        ScannerSleepIntervalSec = 60,
        ChronDaemonSleepSec = 1800,
        MaxStreamReturnLines = 15000,
        StartingWebServerPort = 50001,
        NormalIntervalSec = 1800,
        CleanIntervalSec = 604800,
        NormalStep1 = true,
        NormalStep2 = true,
        NormalStep3 = true,
        NormalStep4 = true,
        NormalStep5 = true,
        NormalStep6 = true,
        NormalStep7 = true,
        CleanSweepDownload = true,
        CleanSweepLyrics = true,
        CleanSweepCompress = true,
        CleanSweepLore = true,
        Playlists = [
        "https://www.youtube.com/playlist?list=PLqcuYaDDgyacWpBG6ib-2EKOuQa6aGjZJ",
        "https://www.youtube.com/playlist?list=PLqcuYaDDgyaeHKssVjz_Nw3qUDwfrwL09",
        "https://www.youtube.com/playlist?list=PLqcuYaDDgyad_i19iLheoQJLLKJUtwlAr",
        "https://www.youtube.com/playlist?list=PLqcuYaDDgyach02bt_8R8G7AzE9zSAOkS"
        ],
        LastCleanRunEpoch = 1785532108,
        LastNormalRunEpoch = 1785673837
    };
    public static readonly Profile NullProfile = new Profile();
    public string ActiveProfile {get; set;}
    public List<Profile> Profiles {get; set;}
    public bool NoProfiles()    
    {
        if (Profiles.Count == 0) {
            return true;
        }
        return false;
    }
    public Profile GetActiveProfile()
    {
        foreach (Profile p in Profiles) {
            if (p.Name == ActiveProfile) {
                return p;
            }
        }
        return NullProfile;
    }
    public ProfileFile(List<Profile>? profiles = null, string activeProfile = "Default")
    {
        ActiveProfile = activeProfile;
        if (profiles == null) {
            profiles = new List<Profile>(){DefaultProfile};
        }
        Profiles = profiles;
    }
    public bool ProfileAlreadyExists(Profile profileToCheck)
    {
        int Count = 0;
        foreach (Profile p in this.Profiles) {
            if (p.Name == profileToCheck.Name) {
                Count += 1;
            }
        }
        return Count > 0;
    }
}


public static class ProfileManager
{

    public static readonly string LogFile = @"C:\MusicTools\MusicPipeline\Sandbox\csLogFile.log";
    public static Profile LoadActiveProfileContext(string profileFile)
    {
        try {
            File.ReadAllBytes(profileFile);
            LogEngine.Out(LogFile, $"Read profile file {profileFile} successfully!", "ProfileManager", "38;5;76");
        }
        catch (FileNotFoundException e) {
            LogEngine.Out(LogFile, "The profile file doesn't exist, creating a new DefaultProfile", "ProfileManager", "38;5;203");
            SaveProfileContext(profileFile);
        }
        string jsonString = File.ReadAllText(profileFile);
        ProfileFile? file = JsonSerializer.Deserialize<ProfileFile>(jsonString);
        if (!file.NoProfiles()) {
            Profile activeProfile = file.GetActiveProfile();
            return activeProfile;

        } else {
            LogEngine.Out(LogFile , $"No profiles were found in the file {profileFile}. A default profile has been initialised.", "Profile Manager", "38;5;203");
            SaveProfileContext(profileFile);
            return DefaultProfiles.DefaultProfile;
        }

        // Ok so we have a profile file in this form
        /*
        Implemented
        */

        // And we need to extract the active profile then make an object from it
        // Idea, make a ProfileFile object which holds everything
        // Including the list of profiles etc
        // Then extract active as a Profile

        // Done
    }

    public static void SaveProfileContext(string profileFile, Profile? profile = null)
    {
        // TODO: fix
        if (profile == null) {
            profile = DefaultProfiles.DefaultProfile;
        }
        ProfileFile Existing = GetProfileFile(profileFile);
        if (Existing.ActiveProfile == "ERROR")
        {
            LogEngine.Out(LogFile, "Failed", "ProfileManager", "38;5;124");
            return;
        }
        if (Existing.ProfileAlreadyExists(profile)) {
            Existing.Profiles = new List<Profile>() {profile};
        } else {
            Existing.Profiles.Add(profile);
        }
        ProfileFile ProfileFile = new ProfileFile(Existing.Profiles, profile.Name);

        var Options = new JsonSerializerOptions { WriteIndented = true };
        string JsonToWrite = JsonSerializer.Serialize(ProfileFile, Options);
        File.WriteAllText(profileFile, JsonToWrite);

        LogEngine.Out(LogFile, $"Wrote new profile {profile.Name} to {profileFile} successfully.", "ProfileManager");
        
    }

    public static void SwitchProfileContext(string profileFile)
    {
        // TODO
    }

    public static ProfileFile GetProfileFile(string profileFile)
    {
        try 
        {
            ProfileFile? file = JsonSerializer.Deserialize<ProfileFile>(profileFile);
            return file;
        }
        catch
        {
            LogEngine.Out(LogFile, "Getting profile file failed", "ProfileManager", "38;5;124");
            return new ProfileFile(new List<Profile>(){DefaultProfiles.ErrorProfile}, "ERROR");
        }
    }
}
