using MusicPipeline.Tools.LogEngine;
namespace MusicPipeline.Profiles;

//TODO: make the profile initialise to defaults

//by having default values down below, that's sort of the default.
//if you're wanting to be able to swap out different defaults like the two in DefaultProfiles,
//  it's less about swapping, and more about just using those ones. 
//Profile myCurrentProfile = DefaultProfiles.DefaultProfile;
//do whatever you want with myCurrentProfile.

// Its more getting a set of defaults that will work and i can have like to post publicly

public class Profile
{
	public string Name {get; set;} = "Null";
	public MyPath BackupDir {get; set;} = new("Null");
	public List<MyPath> CompressedDirs {get; set;} = [new("Null")];
	public MyPath BrokenSongsFile {get; set;} = new("Null");
	public MyPath DiagLogFile {get; set;} = new("Null");
	public MyPath CacheFile {get; set;} = new("Null");
	public MyPath TimingFile {get; set;} = new("Null");
	public MyPath CookieFile {get; set;} = new("Null");
	public MyPath HistoryFile {get; set;} = new("Null");
	public MyPath ProfileFile {get; set;} = new("Null");
	public MyPath YTDLPExe {get; set;} = new("Null");
	public MyPath FFmpegExe {get; set;} = new("Null");
	public MyPath FFmpegBinDir {get; set;} = new("Null");
	public MyPath FirefoxExe {get; set;} = new("Null");
	public MyPath YTDLPConfigFileOriginal {get; set;} = new("Null");
	public MyPath YTDLPConfigFile {get; set;} = new("Null");
	public string CheckURL {get; set;} = "Null";
	public MyPath? ShellShortcut {get; set;} = null; // Nullable because this can't be assumed by default Profile
	public string? ShellCommandFlag {get; set;} = null; // Ditto
	//public string CustomYTDLPArguments {get; set;} = "Null";
	public string SongFileSearchPattern {get; set;} = "Null";
	public string LyricFileSearchPattern {get; set;} = "Null";
	//public string Property {get; set;} = "Null";
	public int SleepInterval {get; set;} = 0;
	public int MaxSleepInterval {get; set;} = 0;
	public int SleepRequests {get; set;} = 0;
	public int MaxCompressThreads {get; set;} = 0;
	public int MaxDownloadThreads {get; set;} = 0;
	public int MaxLyricThreads {get; set;} = 0;
	public int ScannerSleepIntervalSec {get; set;} = 0;
	public int ChronDaemonSleepSec {get; set;} = 0;
	public int MaxStreamReturnLines {get; set;} = 0;
	public int StartingWebServerPort {get; set;} = 0;
	public int NormalIntervalSec {get; set;} = 0;
	public int CleanIntervalSec {get; set;} = 0;
	//public int Property {get; set;} = 0;
	public bool NormalStep1 {get; set;} = false;
	public bool NormalStep2 {get; set;} = false;
	public bool NormalStep3 {get; set;} = false;
	public bool NormalStep4 {get; set;} = false;
	public bool NormalStep5 {get; set;} = false;
	public bool NormalStep6 {get; set;} = false;
	public bool NormalStep7 {get; set;} = false;
	public bool CleanSweepDownload {get; set;} = false;
	public bool CleanSweepLyrics {get; set;} = false;
	public bool CleanSweepCompress {get; set;} = false;
	public bool CleanSweepLore {get; set;} = false;
	//public bool Property {get; set;} = false;
	public string[] Playlists {get; set;} = ["Null"];
	public int LastCleanRunEpoch {get; set;} = 0;
	public int LastNormalRunEpoch {get; set;} = 0;
	public LogEngine? LogEngine {get; set;} = null;
}
