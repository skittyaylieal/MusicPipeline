using MusicPipeline.Tools.Hasher;
namespace MusicPipeline.SongIdentifiers;

public class SongIdentifier
{
	//for your nullable propeties, the ones followed by ?, favor their non-nullable counterparts unless you have a reason to have them be null sometimes.
	//AI says on the subject "Using nullable types like bool? or DateTime? without a clear architectural need introduces unnecessary complexity,
	//increases the surface area for bugs, and forces downstream developers to write defensive boilerplate code."
	// Done
	public required string Title {get; set;}
	public required string Artist {get; set;}
	public required string Album {get; set;}
	public required List<FileInfo> Paths {get; set;}
	public UInt64 PermenantID {get; set;}
	public required string Type {get; set;}
	public double SizeMB {get; set;}
	public double SizeCompressed {get; set;}
	public bool Instrumental {get; set;}
	public bool Lyrics {get; set;}
	public bool SyncedLyrics {get; set;}
	public FileInfo LyricsPath {get; set;}
	public bool Lore {get; set;}
	public DateTime LoreDate {get; set;}

	public SongIdentifier(string title, string artist,
	string album, List<FileInfo> paths, UInt64? id, string type, double sizeMB,
	double sizeCompressed, bool instrumental, bool lyrics,
	bool syncedLyrics, FileInfo? lyricsPath, bool lore, DateTime loreDate = new DateTime())
	{
		Title = title;
		Artist = artist;
		Album = album;
		Paths = paths;
		PermenantID = id ?? Hasher.GetHashForSong(title, artist, album);
		Type = type;
		SizeMB = sizeMB;
		SizeCompressed = sizeCompressed;
		Instrumental = instrumental;
		Lyrics = lyrics;
		if (lyrics) {
			SyncedLyrics = syncedLyrics;
			if (SyncedLyrics) {
				// From LukeH https://stackoverflow.com/a/2201648/22942130
				int index = paths[0].FullName.IndexOf(paths[0].Extension);
				string cleanPath = ( index < 0)
					? paths[0].FullName
					: paths[0].FullName.Remove(index, paths[0].Extension.Length);
				LyricsPath = lyricsPath ?? new FileInfo($"{cleanPath}.lrc"); 
			}
		}
		Lore = lore;
		if (lore) {
			LoreDate = loreDate;
		}
	}
}