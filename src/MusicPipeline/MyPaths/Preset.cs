using System.Diagnostics.CodeAnalysis;

namespace MusicPipeline;

public class Preset
{
	public string Path = "";
	public bool Folder = false;

	public override string ToString()
	{
		return Path;
	}

	
	public Preset(string path)
	{
		Path = path;
		if (Path[^1] == '/')
		{
			Folder = true;

		} else {
			Folder = false;
		}
	}

	// Hey Chris whats that way of doing this all in one lambda thing?
	
	public Preset(string path, bool folder)
	{
		Path = path;
		Folder = folder;
	}

	public Preset(){ }
}