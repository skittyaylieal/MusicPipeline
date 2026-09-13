namespace MusicPipeline.Strings;

public class StringHelpers 
{
	public static async Task<Dictionary<int, string>> SplitLinesDict(string allText)
	{
		Console.WriteLine("Test");
		List<string> lines = new(allText.Split("\n"));
		Console.WriteLine($"lines is {lines}, count is {lines.Count()}, allText length is {allText.Length}");
		Dictionary<int, string> res = new();
		for (int i = 0; i < (lines.Count()); i++) {
			res.Add(i, lines[i]);
			Console.WriteLine($"New line, {res[i]}");
		}
		Console.WriteLine(res);
		return res;
	}
}