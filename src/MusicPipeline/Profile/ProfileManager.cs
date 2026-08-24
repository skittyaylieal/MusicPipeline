using System.Text.Json;
using System.Collections.Generic;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Colours;
namespace MusicPipeline.Profiles;



public class ProfileFile
{
	//public static readonly Profile DefaultProfile = DefaultProfiles.DefaultProfile;
	//if the values below do match your DefaultProfiles.DefaultProfile, I think the line above that you commented out makes sense.
	// Sublime text complains that DefaultProfiles doesn't exist in this context, that's probably why i did it
	/*public static readonly Profile DefaultProfile = new Profile
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
	};*/
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
			//you can use this directly. DefaultProfils.DefaultProfile. Skip having a readonly static field for it
			// a couple lines up i used NullProfile directly, i'll try that here
			// Seems to want DefaultProfiles.
			// we'll see what happens
			// oh i do that down in ProfileManager.LoadActiveProfile()
			profiles = new List<Profile>(){DefaultProfiles.DefaultProfile};
		}
		Profiles = profiles;
	}
	/*
	public bool ProfileAlreadyExists(Profile profileToCheck)
	{
		int count = 0;
		foreach (Profile p in this.Profiles) {
			if (p.Name == profileToCheck.Name) {
				count += 1;
			}
		}
		return count > 0;
	}*/
	public bool ProfileAlreadyExists(Profile profileToCheck) => Profiles.Any(p => p.Name == profileToCheck.Name);
	//the above method can be done more easily like this
	//public bool ProfileAlreadyExists(string profileName) => Profiles.Any(p => p.Name == profileName);
	// I don't understand those operators, but i'll merge it in once i do
	// Thanks for the explanation, this will work fine!
	// So the => replaces {} on one line
	// The Profiles.Any is LINQ, basically just the for loop i had before
	// And the p => p.Name == profileName
	// the p is the profile its doing 
	// (for Profile p in this.Profiles)
	// then its just returning whether or not it hits a Profile p satisfying p.Name == profileName
	// Simples!
}


public static class ProfileManager
{

	public static readonly string LogFile = @"C:\MusicTools\MusicPipeline\Sandbox\csLogFile.log";
	public async static Task<Profile> LoadActiveProfile(string profileFile)
	{
		try {
			File.ReadAllBytes(profileFile);
			await LogEngine.Out(LogFile, $"Read profile file {profileFile} successfully!", "ProfileManager", DefaultColours.Success);
		}
		catch (FileNotFoundException) {
			await LogEngine.Out(LogFile, "The profile file doesn't exist, creating a new DefaultProfile", "ProfileManager", DefaultColours.Error);
			SaveProfileContext(profileFile);
		}
		string jsonString = File.ReadAllText(profileFile);
		await LogEngine.Out(LogFile, jsonString, "Debug", 145);
		ProfileFile? file = JsonSerializer.Deserialize<ProfileFile>(jsonString);
#pragma warning disable CS8602 // If the file were empty that would've already been caught
		if (!file.NoProfiles()) {
			Profile activeProfile = file.GetActiveProfile();
			return activeProfile;
#pragma warning restore CS8602 // I hope I am not disabling this warning innapropriatly, i hope my code is safe enough to warrant it
		} else {
			await LogEngine.Out(LogFile , $"No profiles were found in the file {profileFile}. A default profile has been initialised.", "Profile Manager", DefaultColours.Error);
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

	public static async void SaveProfileContext(string profileFile, Profile? profile = null)
	{
		// TODO: fix
		//next step of todo, name what is broken :)
		// i think i fixed it already actually lol
		if (profile == null) {
			profile = DefaultProfiles.DefaultProfile;
		}
		ProfileFile Existing = GetProfileFile(profileFile);
		if (Existing.ActiveProfile == "ERROR")
		{
			await LogEngine.Out(LogFile, $"Failed to get ProfileFile from {profileFile}, creating new file", "ProfileManager", DefaultColours.Error);
		}
		if (Existing.ProfileAlreadyExists(profile) || Existing.ActiveProfile=="ERROR") {
			Existing.Profiles = new List<Profile>() {profile};
		} else {
			Existing.Profiles.Add(profile);
		}
		ProfileFile ProfileFile = new ProfileFile(Existing.Profiles, profile.Name);

		var Options = new JsonSerializerOptions { WriteIndented = true };
		string JsonToWrite = JsonSerializer.Serialize(ProfileFile, Options);
		File.WriteAllText(profileFile, JsonToWrite);

		await LogEngine.Out(LogFile, $"Wrote new profile {profile.Name} to {profileFile} successfully.", "ProfileManager", DefaultColours.Success);
		
	}

	public static async void SwitchProfileContext(string profileFile)
	{
		// TODO
		await LogEngine.Out(LogFile, "Oopsies, this function doesn't exist yet!", "ProfileManager", DefaultColours.Warning);
	}

	private static async Task<ProfileFile> GetProfileFile(string profileFile)
	{
#pragma warning disable CS8600, CS8603, CS8602 // Again, if the file exists it's so likely to be valid these warnings just clutter the output
		if(Directory.Exists(Directory.GetParent(profileFile).Name)) {
			if (File.Exists(profileFile)) {
				string jsonString = File.ReadAllText(profileFile);
				ProfileFile Result =  JsonSerializer.Deserialize<ProfileFile>(jsonString);
				return Result;
			} else {
				await LogEngine.Out(LogFile, $"ProfileFile {profileFile} doesn't exist.", "ProfileManager", DefaultColours.Error);
				return new ProfileFile(new List<Profile>(){DefaultProfiles.ErrorProfile}, "ERROR");
				//can't do anything after it has already returned, line below is unreachable.
				// Yes I thought i swapped them a while ago
			}
		} else {
			await LogEngine.Out(LogFile, $"Parent directory to profile file path {profileFile} doesn't exist. Creating", "ProfileManager");
			Directory.CreateDirectory(Directory.GetParent(profileFile).Name);
			return await GetProfileFile(profileFile);
		}
#pragma warning restore CS8600, CS8603, CS8602
	}
}
