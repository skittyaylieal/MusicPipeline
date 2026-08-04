using System.Text.Json;
using System.Collections.Generic;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Profiles;



public class ProfileFile
{
    public static readonly Profile DefaultProfile = DefaultProfiles.DefaultProfile;
    public static readonly Profile NullProfile = new Profile();
    public required string ActiveProfile {get; set;}
    public required List<Profile> Profiles {get; set;}
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
        profiles = new List<Profile>(){DefaultProfiles.DefaultProfile};
        Profiles = profiles;
    }
}


public static class ProfileManager
{

    public static readonly string LogFile = @"C:\MusicTools\MusicPipeline\Sandbox\csLogFile.log";
    public static void LoadProfileContext(string profileFile)
    {
        string jsonString = File.ReadAllText(profileFile);
        ProfileFile? file = JsonSerializer.Deserialize<ProfileFile>(jsonString);
        if (!file.NoProfiles()) {
            Profile activeProfile = file.GetActiveProfile();
        } else {
            LogEngine.Out(@"C:\MusicTools\MusicPipeline\Sandbox\csLogFile.log", $"No profiles were found in the file {profileFile}. A default profile has been initialised.", "Profile Manager", "38;5;203");
            // TODO: Save to profile file
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

    public static void SaveProfileContext(string profileFile, Profile profile)
    {
        // TODO: fix
        ProfileFile Existing = GetProfileFile(profileFile);
        if (Existing.ActiveProfile == "Error")
        {
            LogEngine.Out(LogFile, "Failed", "ProfileManager", "38;5;124");
            return;
        }
        Existing.Profiles.Add(profile);
        ProfileFile File = new ProfileFile(Existing.Profiles, profile.Name);
        LogEngine.Out(LogFile, "Did something", "ProfileManager");
        
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
            return new ProfileFile(new List<Profile>(){DefaultProfiles.ErrorProfile}, "Error");
        }
    }
}
