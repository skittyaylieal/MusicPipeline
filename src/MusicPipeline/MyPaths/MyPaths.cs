using System.Text.RegularExpressions;
using System.Diagnostics.CodeAnalysis;
using System.Text.Json.Serialization;
using System.Reflection;
namespace MusicPipeline;



/// <summary>
/// A custom Path class for handling common paths across different systems.
/// </summary>
/// <remarks>
/// <para>
/// 	Handles a custom formatting system and automatic path finding
/// </para>
/// <para>
/// 	Uses a format syntax of [$VarName] in a string, and the hardcoded ~ for UserDir
/// </para>
/// <para>
/// 	Overrides ToString to support $"" and Console.Write natively
/// </para>
/// <para>
/// 	Uses Reflection to convert any formatted string into a valid path.
/// </para>
/// </remarks>
public class MyPath
{

	// TODO: Warn user when a string doesn't end a 
	// [$Var]
	// E.g. just [$

	// Hehe idk what I'm doing
	// ~ is UserDir
	// Others are [$VarName]
	// I guess I make regexes for those at some point
	// Root script and config can be done from the running directory
	// And ConfigDir is being kept as a variable so that I can make it use sandbox right now and move it to main repo later.
	[JsonIgnore]
	public string path {get => ToString(); set => (FormattedPath, Variables) = Format(value);}
	[JsonIgnore]
	public string p {get => ToString(); set => (FormattedPath, Variables) = Format(value);}
	[JsonIgnore]
	public MyPath dir {get => GetDirectory();}
	[JsonIgnore]
	public MyPath parent {get => GetParent();}

	[JsonIgnore]
	public Dictionary<string, string>? Variables {get; set;}

	public required string FormattedPath {get; set;}

	// For format to work properly, order these in terms of which can be nested within the other on a normal system
	// E.g. the path C:/Users/Test/MusicPipeline/src/MusicPipeline/Paths/Paths.cs
	// Which could be said as [$UserDir]/MusicPipeline/src/Musicpipeline/Paths/Paths.cs
	// Or ~/MusicPipeline/src/Musicpipeline/Paths/Paths.cs
	// Or [$RootDir]/src/Musicpipeline/Paths/Paths.cs
	// Or, most succinctly, [$ScriptDir]/Paths/Paths.cs

	//I like this change, empty strings are easier to work with than nulls.

	[JsonIgnore]
	public string UserDir {get; set;} = ""; // C:/Users/Test/
	[JsonIgnore]
	public string UpperRootDir {get; set;} = ""; // UserDir/MusicTools
	[JsonIgnore]
	public string RootDir {get; set;} = ""; // UpperRootDir/MusicPipeline
	[JsonIgnore]
	public string ConfigDir {get; set;} = ""; // RootDir/Config
	[JsonIgnore]
	public string ScriptDir {get; set;} = ""; // RootDir/src/MusicPipeline


	/// <summary>
	///	An override of the ToString function which uses MyPath formatting.
	/// </summary>
	public override string ToString()
	{
		return TakeFullPathWithMyPathSyntaxAndTurnItIntoAStringUsingTheGivenPathObjectForDirectoryReferences(this);
	}


	/// <summary>
	/// Internal static method to convert a custom MyPath formatted path and turn it into a normal path.
	/// </summary>
	/// <remarks>
	/// <para>
	/// 	Uses regex to find each [$VarName] and uses reflection to convert that into the value of that variable.
	/// 	Takes all references from path parameter.
	/// </para>
	/// </remarks>
	/// <param name="path"> The MyPath object to be used for replacement variables. </param>
	/// <returns>A string representing the full path expanded using MyPath formatting.</returns>
	internal static string TakeFullPathWithMyPathSyntaxAndTurnItIntoAStringUsingTheGivenPathObjectForDirectoryReferences(MyPath path)
	{
		// I don't even know how the path syntax works yet so um
		// Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
		// From https://stackoverflow.com/users/24472/larry

		// Find every ~ and replace with UserDir
		// Find every thing between [$ and ] and replace the whole thing with that property in this class. same logic as the parser
		Match match = Regex.Match(path.FormattedPath, @"\[\$(\w+)\]");
		if (!match.Success)
			return path.FormattedPath.Replace("~", path.UserDir);
		string? replace = typeof(MyPath)?.GetProperty(match.Groups[1].Value)?.GetValue(path)?.ToString();
		if (replace is null) {
			Console.WriteLine("Oh dear");
			Console.WriteLine($"replace = {replace}, match = {match}, match.Groups[1].Value = {match.Groups[1].Value}, typeof(MyPath)?.GetProperty(match.Groups[1].Value)?.GetValue(path) = {typeof(MyPath)?.GetProperty(match.Groups[1].Value)?.GetValue(path)}");
		}
		return Regex.Replace(path.FormattedPath, @"\[\$(\w+)\]", replace ?? "Null").Replace(@"\", "/");
		// Perfect
	}

	/// <summary>
	///	Formats a normal path into a MyPath formatted path, using the MyPath's properties.
	/// </summary>
	/// <remarks>
	/// <para>
	/// 	Uses Reflection to get the values and names of this MyPath's properties, then replaces any instance of a value in <paramref name="rawPath"/> with the properties name.
	/// </para>
	/// <param name="rawPath"/>
	///	The normal path, as a string, to format.
	/// </param>
	/// <returns>MyPath with the FormattedPath</returns>
	public MyPath FormatToMyPath(string rawPath)
	{
		string res = rawPath.Replace(@"\", "/");
		Dictionary<string, string> vars = new();
		// Iterate through properties in MyPath
		// Replace any instances of that property with the [$] or ~ syntax
		// Need to ignore the "reserved" properties path, p and FormattedPath
		foreach (PropertyInfo prop in typeof(MyPath).GetProperties()) {
			if (prop.Name == "path" || prop.Name == "p" || prop.Name == "FormattedPath")
				continue;
			// Arguably the this in the next line could be replaced with  a new MyPath() making this a static function
			res = rawPath.Replace((string?)prop.GetValue(this) ?? "Null", prop.Name != "UserDir" ? $"[${prop.Name}]" : "~");
			vars.Add(prop.Name, (string?)prop.GetValue(new MyPath()) ?? "Null");
		}
		return new(res, vars);
	}

	/// <summary>
	///	Formats a normal path into a MyPath formatted path, using the MyPath's properties.
	/// </summary>
	/// <remarks>
	/// <para>
	/// 	Uses Reflection to get the values and names of this MyPath's properties, then replaces any instance of a value in <paramref name="rawPath"/> with the properties name.
	/// </para>
	/// <param name="rawPath"/>
	///	The normal path, as a string, to format.
	/// </param>
	/// <returns>string tuple with the FormattedPath and the variables in it</returns>
	public (string formatted, Dictionary<string, string> variables) Format(string rawPath)
	{
		string res = rawPath.Replace(@"\", "/");
		Dictionary<string, string> vars = new();
		// Iterate through properties in MyPath
		// Replace any instances of that property with the [$] or ~ syntax
		// Need to ignore the "reserved" properties path, p and FormattedPath
		foreach (PropertyInfo prop in typeof(MyPath).GetProperties()) {
			if (prop.Name == "path" || prop.Name == "p" || prop.Name == "FormattedPath")
				continue;
			// Arguably the this in the next line could be replaced with  a new MyPath() making this a static function
			res = rawPath.Replace((string?)prop.GetValue(this) ?? "Null", prop.Name != "UserDir" ? $"[${prop.Name}]" : "~");
			vars.Add(prop.Name, (string?)prop.GetValue(new MyPath()) ?? "Null");
		}
		return (res, vars);
	}


	public string GetExtensionLess()
	{
		string fp = this.FormattedPath;
		int index = fp.LastIndexOf("/");
		if (index >= 0)
    		return fp.Substring(0, index);
    	return "";
	}

	public MyPath GetDirectory()
	{
		if (p[^1] == '/'){
			return new(this);
		} else {
			// In the simplest case, [$UserDir]/Dir/file
			// Then you can lop off up to the Dir/
			// But if its [$UserDir]/file 
			// Then you have to get the actual directory and try to format it again
			string upper = p.Substring(0, p.LastIndexOf("/"));
			if (upper[^1] == ']') {
				// Harder case
				// Check if it's an actual hard case then handle
				string varPattern = @".*(\[\$.*\])";
				Match match = Regex.Match(upper, varPattern);
				if (match.Success) {
					return new(upper);
				} else {
					// Oops
					return new("Null");
				}
			} else {
				return new(upper);
			}

		}
	}

	public MyPath GetParent()
	{
		// This will work in the case of [$UserDir]/Dir/file
		// And in [$UserDir]/Dir/
		// But not in the case of [$UserDir]/file
		// Or just plain [$UserDir]/
		/*
		bool onlyVariable = (p[^1] == ']') || (p[^2] == ']')
		
		if (onlyVariable) {
			string parent = Directory.GetParent(variables[^1].Value);
			return new(parent, true);
		} else {
			// If it's not only a variable it could still be [$UserDir]/file
			// Reuse this code in GetDirectory()

		}

		*/

		string parent = p.Substring(0, p.LastIndexOf("/") - 1).Substring(0, p.LastIndexOf("/"));
		return new();
	}

	[SetsRequiredMembers]
	[JsonConstructor]
	public MyPath(string formattedPath) : this(formattedPath, isRaw: false)
	{
	}

	[SetsRequiredMembers]
	/// <summary>
	/// Instantiates new MyPath object.
	/// </summary>
	/// <param name="formattedPath">
	/// The formatted path to use for this new MyPath. Can be a normal path.
	/// </param>
	/// <param name="isRaw">
	/// Optional other argument, if new MyPath(C:/Users/Test/") is used it will format automatically. True must be manually specified for raw paths.
	/// </param>
	public MyPath(string formattedPath, bool isRaw = false)
	{
		// Returns C:\Users\(Username) on my machine
		UserDir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile).Replace(@"\", "/");
		ScriptDir = Directory.GetCurrentDirectory().Replace(@"\", "/");
		RootDir = Directory.GetParent(ScriptDir)?.Parent?.FullName.Replace(@"\", "/") ?? "";
		UpperRootDir = Directory.GetParent(RootDir)?.FullName.Replace(@"\", "/") ?? "";
		ConfigDir = $"{RootDir}/Sandbox/Config";

		// Must be last V
		FormattedPath = isRaw ? this.Format(formattedPath).formatted : formattedPath;
	}

	[SetsRequiredMembers]
	public MyPath(string formattedPath, Dictionary<string, string> variables)
	{
		UserDir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile).Replace(@"\", "/");
		ScriptDir = Directory.GetCurrentDirectory().Replace(@"\", "/");
		RootDir = Directory.GetParent(ScriptDir)?.Parent?.FullName.Replace(@"\", "/") ?? "";
		UpperRootDir = Directory.GetParent(RootDir)?.FullName.Replace(@"\", "/") ?? "";
		ConfigDir = $"{RootDir}/Sandbox/Config";
		FormattedPath = formattedPath;
		Variables = variables;
	}

	[SetsRequiredMembers]
	public MyPath()
	{
		UserDir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile).Replace(@"\", "/");
		ScriptDir = Directory.GetCurrentDirectory().Replace(@"\", "/");
		RootDir = Directory.GetParent(ScriptDir)?.Parent?.FullName.Replace(@"\", "/") ?? "";
		UpperRootDir = Directory.GetParent(RootDir)?.FullName.Replace(@"\", "/") ?? "";
		ConfigDir = $"{RootDir}/Sandbox/Config";
		FormattedPath = "";
	}


	[SetsRequiredMembers]
	public MyPath(MyPath original)
	{
		UserDir = original.UserDir;
		ScriptDir = original.ScriptDir;
		RootDir = original.RootDir;
		UpperRootDir = original.UpperRootDir;
		ConfigDir = original.ConfigDir;
		FormattedPath = original.FormattedPath;
	}
}