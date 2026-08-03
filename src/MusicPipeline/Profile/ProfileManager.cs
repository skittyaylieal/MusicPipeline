using System.Text.Json;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Profiles;

public class ProfileFile
{
    public static readonly Profile DefaultProfile = DefaultProfiles.defaultProfile;
    public static readonly Profile NullProfile = new Profile();
    public required string ActiveProfile {get; set;}
    public required Profile[] Profiles {get; set;}
    public bool NoProfiles()    
    {
        if (Profiles.Length == 0) {
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
    public ProfileFile(Profile[]? profiles = null, string activeProfile = "Default")
    {
        ActiveProfile = activeProfile;
        profiles = [DefaultProfiles.defaultProfile];
        Profiles = profiles;
    }
}


public static class ProfileManager
{
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

    public static void SaveProfileContext(string profileFile)
    {
        // TODO
    }

    public static void SwitchProfileContext(string profileFile)
    {
        // TODO
    }
}
