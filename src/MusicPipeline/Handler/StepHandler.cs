using MusicPipeline.Results;
using MusicPipeline.Tools.LogEngine;
using MusicPipeline.Profiles;
namespace MusicPipeline.StepHandler;

public static class Handler
{
	public static async Task HandleResult(Result result, string ProfileFile)
	{
		//I don't know if Sublime points it out, but the leading "Profiles" on the line below is not required because you have a using statement for it up above.
		// It complains endlessly when i miss it out
		// "Profile is a namespace but being used a type"
		// NOTHING USES IT AS A NAMESPACE
		Profiles.Profile ActiveProfile = await ProfileManager.LoadActiveProfile(ProfileFile);
		LogEngine l = ActiveProfile.LogEngine;
		l.user = "StepHandler";
		string Success = "";
		// Cookie Verification finished successfully/with errors in (elapsed time)
		if (result.Outcome) {Success = "successfully";} else {Success = "with errors";}
		string ElapsedTime = result.Elapsed.ToString(@"dd\:hh\:mm\:ss\.ffff");
		await l.Out($"{result.Step} finished {Success} in {ElapsedTime}");
		// TODO: Metrics database etc
		// As in, make it handle the songs and things that were affected by the step and do what's necessary
	}
}