namespace MusicPipeline.Metrics;

public class Metric
{
	// TODO: finish
	//I love writing todo bookmark comments like this
	// It just needs to support some other stuff, but I'm not sure what yet lol
	public int MasterCount {get; set;}
	public List<int>? CompressedCounts {get; set;}
	public int LrcCount {get; set;}
	public double MasterSize {get; set;}
	public List<double>? CompressedSizes {get; set;}
}