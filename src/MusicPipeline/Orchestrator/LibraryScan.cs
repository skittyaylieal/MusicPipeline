using MusicPipeline.Tools.Hasher;
using MusicPipeline.Profiles;
namespace MusicPipeline.Orchestrator;

public class Scanner
{
	public async void ScanLibrary(string ProfileFile)
	{
		Profile ActiveProfile = ProfileManager.LoadActiveProfileContext(ProfileFile);
		string LogFile = ActiveProfile.DiagLogFile;
		string BackupDir = ActiveProfile.BackupDir;
		string MobileDir = ActiveProfile.MobileDir;
		string RootDir = "IDFK why it needs this in the source";

		// Get all files in master
		// Get all files in backup
		// Go through each and get info
		// Compile info and MEtric cache

	}
}