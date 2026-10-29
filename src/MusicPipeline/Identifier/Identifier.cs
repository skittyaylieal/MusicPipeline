using System.Diagnostics.CodeAnalysis;
using MusicPipeline.Tools.Hasher;
namespace MusicPipeline.Songs;

public class SongIdentifier
{
	public required string Title {get; set;} = "Null";
	public required string Artist {get; set;} = "Null";
	public required string Album {get; set;} = "Null";
	public required List<MyPath> Paths {get; set;} = new ([new ("Null")]);
	public UInt64 PermenantID {get; set;} = 0;
	public required string Type {get; set;} = "Null";
	public double SizeMB {get; set;} = 0.0;
	public List<double> SizesCompressed {get; set;} = new([0.0]);
	public bool Instrumental {get; set;} = false;
	public bool Lyrics {get; set;} = false;
	public bool SyncedLyrics {get; set;} = false;
	public MyPath? LyricsPath {get; set;} = new("Null");
	public bool Lore {get; set;} = false;
	public DateTime LoreDate {get; set;} = new DateTime();

	[SetsRequiredMembers]
	public SongIdentifier(string title, string artist,
	string album, List<MyPath> paths, UInt64? id, string type, double sizeMB,
	List<double> sizesCompressed, bool instrumental, bool lyrics,
	bool syncedLyrics, MyPath? lyricsPath, bool lore, DateTime loreDate = new DateTime())
	{
		Title = title;
		Artist = artist;
		Album = album;
		Paths = paths;
		PermenantID = id ?? Hasher.GetHashForSong(title, artist, album);
		Type = type;
		SizeMB = sizeMB;
		SizesCompressed = sizesCompressed;
		Instrumental = instrumental;
		Lyrics = lyrics;
		if (lyrics && lyricsPath != null) {
			SyncedLyrics = syncedLyrics;
			// TODO: make this code properly support different extensions and actually providing lyric paths
			if (SyncedLyrics) {
				// From LukeH https://stackoverflow.com/a/2201648/22942130
				//int index = paths[0].p.IndexOf(paths[0].Extension);
				//string cleanPath = ( index < 0)
				//	? paths[0].p
				//	: paths[0].p.Remove(index, paths[0].Extension.Length);
				//LyricsPath = lyricsPath ?? new FileInfo($"{cleanPath}.lrc"); 
				LyricsPath = new($"{lyricsPath.GetExtensionLess()}.lrc");
			}
		}
		Lore = lore;
		if (lore) {
			LoreDate = loreDate;
		}
	}

	[SetsRequiredMembers]
	public SongIdentifier(bool Error)
	{
		Title = "ERROR";
		Artist = "ERROR";
		Album = "ERROR";
		Paths = [new("ERROR")];
		PermenantID = 0;
		Type = "ERROR";
		SizeMB = 0.0;
		SizesCompressed = [0.0];
		Instrumental = true;
		Lyrics = true;
		SyncedLyrics = true;
		LyricsPath = new("ERROR");
		Lore = true;
		LoreDate = new();
	}

	[SetsRequiredMembers]
	public SongIdentifier() { }

	[SetsRequiredMembers]
	public SongIdentifier(List<string> scriptOutput, string step)
	{
		SongIdentifier id = this;
		switch (step) {
			case "YTDLP": 
				id = IdentifierHelper.GetIdentifierFromYTDLPOutput(scriptOutput);
				break;
			// TODO: Add more cases with each step
		}
		Title = id.Title;
		Artist = id.Artist;
		Album = id.Album;
		Paths = id.Paths;
		//PermenantID = id ?? Hasher.GetHashForSong(id.Title, id.Artist, id.Album);
		// Can't get an id from the ytdlp output, if the given output can somehow get an id, the helper function should handle all that
		PermenantID = id.PermenantID;
		Type = id.Type;
		SizeMB = id.SizeMB;
		SizesCompressed = id.SizesCompressed;
		Instrumental = id.Instrumental;
		Lyrics = id.Lyrics;
		if (id.Lyrics && id.LyricsPath != null) {
			SyncedLyrics = id.SyncedLyrics;
			// TODO: make this code properly support different extensions and actually providing lyric paths
			if (SyncedLyrics) {
				// From LukeH https://stackoverflow.com/a/2201648/22942130
				LyricsPath = new($"{id.LyricsPath.GetExtensionLess()}.lrc");
			}
		}
		Lore = id.Lore;
		if (id.Lore) {
			LoreDate = id.LoreDate;
		}
	}
}