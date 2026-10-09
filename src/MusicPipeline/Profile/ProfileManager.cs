using System.Text.Json;
using System.Text.Json.Serialization;
using System.Collections.Generic;
using MusicPipeline.Tools.SafetyCheck;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Colours;
namespace MusicPipeline.Profiles;



public class ProfileFile
{
	//public static readonly Profile DefaultProfile = DefaultProfiles.DefaultProfile;
	//if the values below do match your DefaultProfiles.DefaultProfile, I think the line above that you commented out makes sense.
	// Sublime text complains that DefaultProfiles doesn't exist in this context, that's probably why i did it
	/*
	public static readonly Profile DefaultProfile = new Profile
	{
		Name = "Default",
		BackupDir = @"C:/Users/filip/Music/YT_Music_Backup",
		MobileDir = @"C:/Users/filip/Music/YT_Music_Mobile",
		BrokenSongsFile = @"C:/MusicTools/MusicPipeline/Config/broken_songs.json",
		DiagLogFile = @"C:/MusicTools/MusicPipeline/Config/web_console_stream.log",
		CacheFile = @"C:/MusicTools/MusicPipeline/Config/dashboard_cache.json",
		TimingFile = @"C:/MusicTools/MusicPipeline/Config/timing_history.json",
		CookieFile = @"C:/MusicTools/MusicPipeline/Config/cookies.txt",
		HistoryFile = @"C:/MusicTools/MusicPipeline/Config/downloaded_history.txt",
		YTDLPExe = @"C:/MusicTools/yt-dlp.exe",
		FFmpegExe = @"C:/MusicTools/ffmpeg.exe",
		FirefoxExe = @"C:/Program Files/Mozilla Firefox/firefox.exe",
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
	*/
	public static readonly Profile NullProfile = new Profile();
	public string ActiveProfileName {get; set;}
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
			if (p.Name == ActiveProfileName) {
				return p;
			}
		}
		return NullProfile;
	}
	[JsonIgnore]
	public Profile ActiveProfile {get => field = GetActiveProfile(); set;}

	public ProfileFile(List<Profile>? profiles = null, string? activeProfileName = null)
	{
		ActiveProfileName = activeProfileName ?? ((profiles) ?? [DefaultProfiles.DefaultProfile])[0].Name;
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

	public string? toString()
	{
		string? x = "";
		try {
			x = $"ActiveProfile = {this.ActiveProfile}, Profiles = {this.Profiles}, this = {this}. First Profile = {this.Profiles[0]}";
		} catch {
			x = this.ToString();
		}
		return x;
	}
}


public class ProfileManager
{
	// Need a new Profile ActiveProfile which works by getting and setting to the Profile File but that will need more work
	// Some kind of way to have it work asynchronously, but also let you set and get properties of it by fetching from the file instead of fetching from ram
	// Hmmmmmmmm
	// TODO: Make an UpdateProfileValue function that takes a property of the profile and thread-safely updates the file
	private static LogEngine? logger = null;
	private static async Task<MyPath> GetProfileFilePathAsync()
	{
		return new("[$RootDir]/Config/csProfiles.json");
	}
	
	public async static Task<Profile> LoadActiveProfileAsync()
	{
		MyPath profileFilePath = await GetProfileFilePathAsync();
		// Skipping this. Not sure why it's here to begin with
		// Oh if the file doesn't exist
		// Oops
		try {
			//Console.WriteLine("Trying to read all bytes");
			File.ReadAllBytes(profileFilePath.p);
			//Console.WriteLine("Read all bytes");
			//await logger.Out($"Read profile file {profileFile} successfully!", DefaultColours.Success, true);
		}
		catch (FileNotFoundException) {
			//Console.WriteLine("Caught a FileNotFoundException");
			//await logger.Out("The profile file doesn't exist, creating a new DefaultProfile", DefaultColours.Error, true);
			await SaveProfileAsync(DefaultProfiles.DefaultProfile);
		}
		catch {
			//Console.WriteLine("Caught something else");
			//await logger.Out("Json read failed", DefaultColours.Error, true);
			//await logger.Out(e.Message, DefaultColours.Debug);
			return DefaultProfiles.ErrorProfile;
		}
		//Console.WriteLine("Getting jsonString");
		string jsonString = File.ReadAllText(profileFilePath.p);
		//Console.WriteLine($"jsonString = {jsonString}");
		//await logger.Out(jsonString, DefaultColours.Debug);
		//Console.WriteLine("Deserializing jsonString");
		ProfileFile? file = new();
		try {
			file = JsonSerializer.Deserialize<ProfileFile>(jsonString);
		} catch (System.Text.Json.JsonException) {
			var Options = new JsonSerializerOptions { WriteIndented = true };
			string JsonToWrite = JsonSerializer.Serialize(new ProfileFile([DefaultProfiles.DefaultProfile]), Options);
			File.WriteAllText(profileFilePath.p, JsonToWrite);
		}
		//Console.WriteLine($"file = {file?.toString()}");
#pragma warning disable CS8602 // If the file were empty that would've already been caught
		if (!file.NoProfiles()) {
			Profile activeProfile = file.GetActiveProfile();
			return activeProfile;
		} else {
			await DefaultProfiles.DefaultProfile.LogEngine.Out($"No profiles were found in the file {profileFilePath}. A default profile has been initialised.", "ProfileManager", DefaultColours.Error, true);
			await SaveProfileAsync(DefaultProfiles.DefaultProfile);
			return DefaultProfiles.DefaultProfile;
		}
#pragma warning restore CS8602 // I hope I am not disabling this warning innapropriatly, I think my code is safe enough to warrant it

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

	public static async Task SaveProfileAsync(Profile? profile = null, bool overrideParam = false/*, bool fullDebugOverride = false*/)
	{
		MyPath profileFilePath = await GetProfileFilePathAsync();
		//Console.WriteLine("Saving a profile");
		// TODO: fix
		//next step of todo, name what is broken :)
		// i think i fixed it already actually lol
		/*if (fullDebugOverride) {
			ProfileFile debugProfileFile = new ProfileFile(new([profile]), profile.Name);
			var debugOptions = new JsonSerializerOptions { WriteIndented = true };
			string debugJsonToWrite = JsonSerializer.Serialize(debugProfileFile, debugOptions);
			File.WriteAllText(profileFile, debugJsonToWrite);
		}*/

		if (profile == null) {
			//Console.WriteLine("Profile is null");
			profile = DefaultProfiles.DefaultProfile;
			logger = DefaultProfiles.DefaultProfile.LogEngine;
		} else if (await SafetyCheck.CheckProfileToBeSaved(profile) & !overrideParam) {await (logger ?? new("Null")).Out("A new profile that matchs a default profile exactly is being added. Please check that this is intentional, and if so pass override", "ProfileManager", DefaultColours.Error, true); return;}
		//Console.WriteLine("Getting existing profile file");
		ProfileFile Existing = await GetProfileFileAsync();
		if (Existing.ActiveProfileName == "ERROR")
		{
			//Console.WriteLine("Error Profile");
			await (DefaultProfiles.DefaultProfile.LogEngine ?? new ("Null")).Out($"Failed to get ProfileFile from {profileFilePath}, creating new file", DefaultColours.Error, true);
		}
		if (Existing.ProfileAlreadyExists(profile) || Existing.ActiveProfileName=="ERROR") {
			Existing.Profiles = new List<Profile>() {profile};
		} else {
			Existing.Profiles.Add(profile);
		}
		ProfileFile ProfileFile = new ProfileFile(Existing.Profiles, profile.Name);

		//Console.WriteLine("Writing Profile file");
		var Options = new JsonSerializerOptions { WriteIndented = true };
		string JsonToWrite = JsonSerializer.Serialize(ProfileFile, Options);
		File.WriteAllText(profileFilePath.p, JsonToWrite);
		if (!(profile.LogEngine is null)) {
			// Should probably give it a new logengine?
			LogEngine l = new(profile.DiagLogFile, "ProfileManager");
			profile.LogEngine = l;
			await l.Out($"Wrote new profile {profile.Name} to {profileFilePath} successfully.", DefaultColours.Success, true);
		} else {
			await (DefaultProfiles.DefaultProfile.LogEngine ?? new ("Null")).Out($"Wrote new profile {profile.Name} to {profileFilePath} successfully.", DefaultColours.Success, true);
		}
	}

	public static async Task SwitchProfileAsync()
	{
		//MyPath profileFilePath = await GetProfileFilePathAsync();
		// TODO
		await (await GetProfileFileAsync()).ActiveProfile.LogEngine.Out("Oopsies, this function doesn't exist yet!", "ProfileManager", DefaultColours.Warning, true);
		throw new NotImplementedException();
	}

	private static async Task<ProfileFile> GetProfileFileAsync()
	{
		//Console.WriteLine("Getting Profile File");
		MyPath profileFilePath = await GetProfileFilePathAsync();
		if(Directory.Exists(Directory.GetParent(profileFilePath.p)?.ToString())) {
			if (File.Exists(profileFilePath.p)) {
				//Console.WriteLine("File exists");
				//Console.WriteLine("Getting Json string");
				string jsonString = File.ReadAllText(profileFilePath.p);
				ProfileFile Result = new([DefaultProfiles.ErrorProfile], "ERROR");
				try {
					Result = JsonSerializer.Deserialize<ProfileFile>(jsonString) ?? Result;
				} catch {
					return Result;
				}
				return Result;
			} else {
				await (DefaultProfiles.DefaultProfile.LogEngine ?? new ("Null")).Out($"ProfileFile {profileFilePath} doesn't exist.", "ProfileManager", DefaultColours.Error, true);
				return new ProfileFile(new List<Profile>(){DefaultProfiles.ErrorProfile}, "ERROR");
				//can't do anything after it has already returned, line below is unreachable.
				// Yes I thought i swapped them a while ago
			}
		} else {
			await (logger ?? new("Null")).Out($"Parent directory to profile file path {profileFilePath} doesn't exist. Creating", "ProfileManager");
			Directory.CreateDirectory(Directory.GetParent(profileFilePath.p).Name);
			return await GetProfileFileAsync();
		}
	}
}
