namespace MusicPipeline.SongIdentifiers;

public class SongIdentifier
{
	public required string Title {get; set;}
	public required string Artist {get; set;}
	public required string Album {get; set;}
	public required string PermenantID {get; set;}
	public required string Type {get; set;}
	public int SizeMB {get; set;}
	public int SizeCompressed {get; set;}
	public bool Instrumental {get; set;}
	public bool? Lyrics {get; set;}
	public bool? SyncedLyrics {get; set;}
	public bool Lore {get; set;}
	public int? LoreDate {get; set;}

	public SongIdentifier(string title, string artist,
	string album, string id, string type, int sizeMB,
	int sizeCompressed, bool instrumental, bool lyrics,
	bool syncedLyrics, bool lore, int loreDate)
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