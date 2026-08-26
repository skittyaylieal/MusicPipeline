using MusicPipeline.Tools.Hasher;
namespace MusicPipeline.SongIdentifiers;

public class SongIdentifier
{
	//for your nullable propeties, the ones followed by ?, favor their non-nullable counterparts unless you have a reason to have them be null sometimes.
	//AI says on the subject "Using nullable types like bool? or DateTime? without a clear architectural need introduces unnecessary complexity,
	//increases the surface area for bugs, and forces downstream developers to write defensive boilerplate code."
	// Done
	public required string Title {get; set;} = "Null";
	public required string Artist {get; set;} = "Null";
	public required string Album {get; set;} = "Null";
	public required List<FileInfo> Paths {get; set;} = new List<FileInfo>([new FileInfo("Null")]);
	public UInt64 PermenantID {get; set;} = 0;
	public required string Type {get; set;} = "Null";
	public double SizeMB {get; set;} = 0.0;
	public List<double> SizesCompressed {get; set;} = new List<double>([0.0]);
	public bool Instrumental {get; set;} = false;
	public bool Lyrics {get; set;} = false;
	public bool SyncedLyrics {get; set;} = false;
	public FileInfo? LyricsPath {get; set;} = new FileInfo("Null");
	public bool Lore {get; set;} = false;
	public DateTime LoreDate {get; set;} = new DateTime();

	public SongIdentifier(string title, string artist,
	string album, List<FileInfo> paths, UInt64? id, string type, double sizeMB,
	List<double> sizesCompressed, bool instrumental, bool lyrics,
	bool syncedLyrics, FileInfo? lyricsPath, bool lore, DateTime loreDate = new DateTime())
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
		if (lyrics) {
			SyncedLyrics = syncedLyrics;
			// TODO: make this code properly support different extensions and actually providing lyric paths
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