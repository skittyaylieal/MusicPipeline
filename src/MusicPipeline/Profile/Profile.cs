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
	public string BackupDir {get; set;} = "Null";
	public List<string> CompressedDirs {get; set;} = ["Null"];
	public string BrokenSongsFile {get; set;} = "Null";
	public string DiagLogFile {get; set;} = "Null";
	public string CacheFile {get; set;} = "Null";
	public string TimingFile {get; set;} = "Null";
	public string CookieFile {get; set;} = "Null";
	public string HistoryFile {get; set;} = "Null";
	public string ProfileFile {get; set;} = "Null";
	public string YTDLPExe {get; set;} = "Null";
	public string FFmpegExe {get; set;} = "Null";
	public string FirefoxExe {get; set;} = "Null";
	public string CheckURL {get; set;} = "Null";
	public string RootDir {get; set;} = "Null";
	public string ScriptRootDir {get; set;} = "Null";
	public string YTDLPConfigFileOriginal {get; set;} = "Null";
	public string YTDLPConfigFile {get; set;} = "Null";
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
	public string[] Playlists {get; set;} = ["Null"];
	public int LastCleanRunEpoch {get; set;} = 0;
	public int LastNormalRunEpoch {get; set;} = 0;
	public LogEngine? LogEngine {get; set;} = null;
}
