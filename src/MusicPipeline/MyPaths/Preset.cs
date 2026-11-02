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
		if (path == "") {
			Path = path;
			Folder = false;
			return;
		}
		if (path[^1] == '/')
		{
			Folder = true;
			Path = path.Substring(0, path.Length - 1); // Remove the /
		} else {
			Folder = false;
			Path = path;
		}
	}

	// Hey Chris what's that way of doing this all in one lambda thing?
	
	public Preset(string path, bool folder)
	{
		Path = path;
		Folder = folder;
	}

	public Preset(){ }
}