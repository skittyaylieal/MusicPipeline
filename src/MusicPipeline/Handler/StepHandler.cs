using MusicPipeline.Results;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Profiles;
namespace MusicPipeline.StepHandler;

public static class Handler
{
	public static async void HandleResult(Result result, string ProfileFile)
	{
		//I don't know if Sublime points it out, but the leading "Profiles" on the line below is not required because you have a using statement for it up above.
		// It complains endlessly when i miss it out
		// "Profile is a namespace but being used a type"
		// NOTHING USES IT AS A NAMESPACE
		Profiles.Profile ActiveProfile = await ProfileManager.LoadActiveProfile(ProfileFile);
		string LogFile = ActiveProfile.DiagLogFile;
		string Success = "";
		// Cookie Verification finished successfully/with errors in (elapsed time)
		if (result.Outcome) {Success = "successfully";} else {Success = "with errors";}
		string ElapsedTime = result.Elapsed.ToString(@"dd\:hh\:mm\:ss\.ffff");
		await LogEngine.Out(LogFile, $"{result.Step} finished {Success} in {ElapsedTime}", "StepHandler");
		// TODO: Metrics database etc
	}
}