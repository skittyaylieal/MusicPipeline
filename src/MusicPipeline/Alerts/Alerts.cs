namespace MusicPipeline.Alerts;

public class Alert
{
	//a class like this that has data but no behavior is sometimes called a "DTO data transfer object" or "POCO plain old CLR object"... CLR is "common language runtime".
	//just fyi, there's nothing to change
	public required string Type {get; set;}
	public required string FixAction {get; set;}
	public required string Message {get; set;}
}
