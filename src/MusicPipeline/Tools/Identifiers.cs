namespace MusicPipeline.Tools.SongIdentifiers;

public class SongIdentifier {
	public required string Title {get; set;}
	public required string Artist {get; set;}
	public required string Album {get; set;}
	public required string PermenantID {get; set;}
	public required string Type {get; set;}
	public int SizeMB {get; set;}
	public bool Instrumental {get; set;}
	public int SizeCompressed {get; set;}
	public bool? Lyrics {get; set;}
	public bool? SyncedLyrics {get; set;}
	public bool Lore {get; set;}
	public int? LoreDate {get; set;}
}