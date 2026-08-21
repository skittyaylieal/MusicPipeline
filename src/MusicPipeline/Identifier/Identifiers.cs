namespace MusicPipeline.SongIdentifiers;

public class SongIdentifier
{
	public required string Title {get; set;}
	public required string Artist {get; set;}
	public required string Album {get; set;}
	public required UInt64 PermenantID {get; set;}
	public required string Type {get; set;}
	public double SizeMB {get; set;}
	public double SizeCompressed {get; set;}
	public bool Instrumental {get; set;}
	public bool? Lyrics {get; set;}
	public bool? SyncedLyrics {get; set;}
	public bool Lore {get; set;}
	public DateTime? LoreDate {get; set;}

	public SongIdentifier(string title, string artist,
	string album, UInt64 id, string type, double sizeMB,
	double sizeCompressed, bool instrumental, bool lyrics,
	bool syncedLyrics, bool lore, DateTime loreDate = new DateTime())
	{
		Title = title;
		Artist = artist;
		Album = album;
		PermenantID = id;
		Type = type;
		SizeMB = sizeMB;
		SizeCompressed = sizeCompressed;
		Instrumental = instrumental;
		Lyrics = lyrics;
		if (lyrics) {
			SyncedLyrics = syncedLyrics;
		}
		Lore = lore;
		if (lore) {
			LoreDate = loreDate;
		}
	}
}