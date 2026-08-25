namespace MusicPipeline.Tools.ListTools;

public class ListTools
{
	public async void MaxCountAnyList(Dictionary<string, IEnumerable> target, bool returnListName = false)
	{
		int highest = 0;
		foreach(KeyValuePair<string, IEnumerable> kvp in target) {
			//var files = masterFiles.Count < MaxCountAnyList(compressedFiles) ? compressedFiles : masterFiles;
			highest = kvp.Value.Count > highest ? kvp.Value.Count : highest;
		}
	}
}