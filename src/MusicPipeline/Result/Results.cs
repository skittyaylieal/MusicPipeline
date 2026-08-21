using MusicPipeline.SongIdentifiers;
namespace MusicPipeline.Results;

public class Result
{
	// The result 
	// The time the step took
	// Any errors
	// Any processed songs and what to do with them

	public required bool Outcome;
	public required TimeSpan Elapsed;
	public string? Error;
	public List<SongIdentifier>? Songs;
	
	public Result(bool outcome, TimeSpan elapsed, string error = "", List<SongIdentifier>? songs = null)
	{
		Outcome = outcome;
		Elapsed = elapsed;
		Error = error;
		Songs = songs;
	}
}