namespace MusicPipeline.Results;

public static class CookieDefaults
{
	public static Result FileError(bool YTDLP, DateTime start)
	{
		/*
		Result Res = new Result("Cookie Verification", false, Elapsed);
		if(YTDLP){Res.Error = "YTDLP executable not found";}
		else {Res.Error = "Cookie file not found";}
		return Res;
		*/

		//I changed the flow of this method.
		//See if you like the style.
		//The logic is the same.
		
		// I prefer this, much more what i was going for, thanks
		// Added

		DateTime end = DateTime.UtcNow;
		TimeSpan elapsed = end - start;

		var error = "Cookie file not found";
		if (YTDLP)
			error = "YTDLP executable not found";
		return new Result("Cookie Verification", false, elapsed, error);
		
	}
}