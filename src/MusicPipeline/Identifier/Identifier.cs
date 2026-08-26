using MusicPipeline.Colours;
using MusicPipeline.Tools.LogEngine;
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
	public List<double> SizesCompressed {get; set;}
	public bool Instrumental {get; set;}
	public bool Lyrics {get; set;}
	public bool SyncedLyrics {get; set;}
	public FileInfo? LyricsPath {get; set;}
	public bool Lore {get; set;}
	public DateTime LoreDate {get; set;}

	public async Task<SongIdentifier> SongIdentifier(string title, string artist,
	string album, List<FileInfo> paths, UInt64? id = null, string type, double sizeMB,
	List<double> sizesCompressed, bool instrumental, bool lyrics,
	bool syncedLyrics, FileInfo? lyricsPath, bool lore, DateTime? loreDate = null)
	{
		this.Title = title;
		this.Artist = artist;
		this.Album = album;
		this.Paths = paths;
		this.PermenantID = id ?? Hasher.GetHashForSong(title, artist, album);
		this.Type = type;
		this.SizeMB = sizeMB;
		this.SizesCompressed = sizesCompressed;
		this.Instrumental = instrumental;
		this.Lyrics = lyrics;
		if (lyrics) {
			this.SyncedLyrics = syncedLyrics;
			// TODO: make this code properly support different extensions and actually providing lyric paths
			if (this.SyncedLyrics) {
				// From LukeH https://stackoverflow.com/a/2201648/22942130
				int index = paths[0].FullName.IndexOf(paths[0].Extension);
				string cleanPath = ( index < 0)
					? paths[0].FullName
					: paths[0].FullName.Remove(index, paths[0].Extension.Length);
				this.LyricsPath = lyricsPath ?? new FileInfo($"{cleanPath}.lrc"); 
			}
		}
		this.Lore = lore;
		if (lore) {
			if (loreDate == null) {
				this.LoreDate = new DateTime();
				await LogEngine.Out(null, "LoreDate has not been provided. Please fix.", "SongIdentifierConstructor", DefaultColours.Error);
			} else {
				this.LoreDate = loreDate;
			}
		}
		return this;
	}
}