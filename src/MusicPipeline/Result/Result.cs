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
	public Dictionary<int, List<SongIdentifier>>? Songs; // The int is for multithreaded sections
	
	public Result(string step, bool outcome, TimeSpan elapsed, string error, Dictionary<int, List<SongIdentifier>>? songs)
	{
		Step = step;
		Outcome = outcome;
		Elapsed = elapsed;
		Error = error;
		Songs = songs;
	}

	public Result(string step, bool outcome, TimeSpan elapsed, string error = "", List<SongIdentifier>? songs = null)
	{
		Step = step;
		Outcome = outcome;
		Elapsed = elapsed;
		Error = error;
		Songs = new(); // There's got to be a way to just init the dictionary with these values, but for some reason it's not working
		Songs.Append(new KeyValuePair<int, List<SongIdentifier>>(0, songs ??  new()));
	}

	public Result(string step, TimeSpan elapsed)
	{
		Step = step;
		Outcome = true;
		Error = "";
		Songs = null;
	}

	public Result(string step, TimeSpan elapsed, string error)
	{
		Step = step;
		Outcome = false;
		Error = error;
		Songs = null;
	}
}