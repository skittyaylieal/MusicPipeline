namespace MusicPipeline.Results;

public static class CookieDefaults
{
	public static Result FileError(bool YTDLP, TimeSpan Elapsed)
	{
		Result Res = new Result("Cookie Verification", false, Elapsed);
		if(YTDLP){Res.Error = "YTDLP executable not found";}
		else {Res.Error = "Cookie file not found";}
		return Res;
	}
}