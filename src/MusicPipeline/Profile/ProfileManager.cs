using System.Text.Json;
using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Profiles;

public class ProfileFile
{
    public static Profile defaultProfile = DefaultProfiles.defaultProfile;
    public static Profile nullProfile = new Profile();
    public required string activeProfile {get; set;}
    public required Profile[] profiles {get; set;}
    public bool NoProfiles()    
    {
        if (profiles.Length == 0) {
            return true;
        }
        return false;
    }
    public Profile ActiveProfile()
    {
        foreach (Profile p in profiles) {
            if (p.Name == activeProfile) {
                return p;
            }
        }
        return nullProfile;
    }
}


public static class ProfileManager
{
    public static void LoadProfileContext(string profileFile)
    {
        string jsonString = File.ReadAllText(profileFile);
        ProfileFile? file = JsonSerializer.Deserialize<ProfileFile>(jsonString);
        if (!file.NoProfiles()) {
            Profile activeProfile = file.ActiveProfile();
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
