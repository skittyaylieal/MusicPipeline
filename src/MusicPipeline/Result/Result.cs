using MusicPipeline.Songs;
namespace MusicPipeline.Results;

public class Result
{
	// The result 
	// The time the step took
	// Any errors
	// Any processed songs and what to do with them
	public string Step;
	public bool Outcome;
	public TimeSpan Elapsed;
	public string? Error;
	public List<SongIdentifier>? Songs;
	
	public Result(string step, bool outcome, TimeSpan elapsed, string error = "", List<SongIdentifier>? songs = null)
	{
		Step = step;
		Outcome = outcome;
		Elapsed = elapsed;
		Error = error;
		Songs = songs;
	}
}