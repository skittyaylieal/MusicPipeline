using System.Diagnostics.CodeAnalysis;
using System.Text.RegularExpressions;
using System.Text.Json.Serialization;
using System.Reflection;
namespace MusicPipeline;

// TODO: Make some kind of update function which is called whenever a function modifys something like the path
// So that the parent etc fields can stay up to date
// Hm i cant make those fields default to null


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
	public string path {get => field ?? (field = ToString()); set => (FormattedPath, Variables) = Format(field ?? value);}
	[JsonIgnore]
	public string p {get => field ?? (field = ToString()); set => (FormattedPath, Variables) = Format(field ?? value);}
	[JsonIgnore]
	public MyPath? dir {get => field ?? (field = GetDirectory()); internal set;}
	[JsonIgnore]
	public MyPath? parent {get => field ?? (field = GetParent()); internal set;}

	[JsonIgnore]
	public Dictionary<string, Preset>? Variables {get; set;}

	public required string FormattedPath {get; set;}

	// For format to work properly, order these in terms of which can be nested within the other on a normal system
	// E.g. the path C:/Users/Test/MusicPipeline/src/MusicPipeline/Paths/Paths.cs
	// Which could be said as [$UserDir]/MusicPipeline/src/Musicpipeline/Paths/Paths.cs
	// Or ~/MusicPipeline/src/Musicpipeline/Paths/Paths.cs
	// Or [$RootDir]/src/Musicpipeline/Paths/Paths.cs
	// Or, most succinctly, [$ScriptDir]/Paths/Paths.cs

	//I like this change, empty strings are easier to work with than nulls.

	[JsonIgnore]
	public Preset UserDir {get; set;} = new(""); // C:/Users/Test/
	[JsonIgnore]
	public Preset UpperRootDir {get; set;} = new(""); // UserDir/MusicTools
	[JsonIgnore]
	public Preset RootDir {get; set;} = new(""); // UpperRootDir/MusicPipeline
	[JsonIgnore]
	public Preset ConfigDir {get; set;} = new(""); // RootDir/Config
	[JsonIgnore]
	public Preset ScriptDir {get; set;} = new(""); // RootDir/src/MusicPipeline


	/// <summary>
	///	An override of the ToString function which uses MyPath formatting.
	/// </summary>
	public override string ToString()
	{
		this.Update();
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
			return path.FormattedPath.Replace("~", path.UserDir.Path);
		string? replace = typeof(MyPath)?.GetProperty(match.Groups[1].Value)?.GetValue(path)?.ToString();
		if (replace is null) {
			Console.WriteLine("Oh dear");
			Console.WriteLine($"replace = {replace}, match = {match}, match.Groups[1].Value = {match.Groups[1].Value}, typeof(MyPath)?.GetProperty(match.Groups[1].Value)?.GetValue(path) = {typeof(MyPath)?.GetProperty(match.Groups[1].Value)?.GetValue(path)}");
		}
		return Regex.Replace(path.FormattedPath, @"\[\$(\w+)\]", replace ?? "Null").Replace(@"\", "/");
		// Perfect
	}

	internal void Update()
	{
		// Set all the nullable properties
		path = path ?? ToString();
		p = p ?? path;
		dir = dir ?? GetDirectory();
		parent = parent ?? GetParent();
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
			if (prop.PropertyType != typeof(Preset))
				continue;
			// Arguably the this in the next line could be replaced with  a new MyPath() making this a static function
			res = rawPath.Replace((string?)prop.GetValue(this)?.ToString() ?? "Null", prop.Name != "UserDir" ? $"[${prop.Name}]" : "~");
			vars.Add(prop.Name, (string?)prop.GetValue(new MyPath())?.ToString() ?? "Null");
		}
		this.Update();
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
	public (string formatted, Dictionary<string, Preset> variables) Format(string rawPath)
	{
		string res = rawPath.Replace(@"\", "/");
		Dictionary<string, Preset> vars = new();
		// Iterate through properties in MyPath
		// Replace any instances of that property with the [$] or ~ syntax
		// Need to ignore the "reserved" properties path, p and FormattedPath
		foreach (PropertyInfo prop in typeof(MyPath).GetProperties()) {
			if (prop.PropertyType != typeof(Preset))
				continue;
			// Arguably the this in the next line could be replaced with  a new MyPath() making this a static function
			res = rawPath.Replace((string?)prop.GetValue(this)?.ToString() ?? "Null", prop.Name != "UserDir" ? $"[${prop.Name}]" : "~");
			vars.Add(prop.Name, (Preset?)prop.GetValue(new MyPath()) ?? new("Null"));
		}
		this.Update();
		return (res, vars);
	}


	public string GetExtensionLess()
	{
		string fp = this.FormattedPath;
		int index = fp.LastIndexOf("/");
		if (index >= 0) {
			this.Update();
    		return fp.Substring(0, index);
		}
		this.Update();
    	return "";
	}

	public MyPath GetDirectory()
	{
		if (p[^1] == '/'){
			return new(this);
		} else {
			// So
			// This block handles anything which isn't automatically a directory
			// which is anything not ending in '/'. Ideally, any path which is just [$var] should end in a / if that [$var] is a directory.
			/*
			CASES:
			[$UserDir]/file
			[$UserDir]/Dir/file
			[$ConfigFile] (hypothetical preset which isn't a directory)
			*/
			// First, we need to handle the case of 
			// just a variable file
			// [$ConfigFile]
			if (p[^1] == ']') {
				string varPattern = @".*(\[\$.*\])";
				var match = Regex.Match(p, varPattern);
				var temp = Variables?[match.Value] ?? new Preset();
				if (temp.Folder) {
					p += '/';
					this.Update();
					return new($"{match.Value}/");
				} else {
					// Not a folder, gotta get the actual directory
					return new(temp.Path.Substring(temp.Path.LastIndexOf('/')), true);
				}
			} 
			// If it doesn't end in a '/' or a ']' then it must be one of
			/*
			[$UserDir]/file
			[$UserDir]/Dir/file
			*/
			else {
				return new(p.Substring(p.LastIndexOf('/')));
			}



			/*
			REWORKING ALL OF THIS
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
			}*/

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
			this.update();
			this.parent = new(parent, true)
			return this.parent;
		} else {
			// If it's not only a variable it could still be [$UserDir]/file
			// Reuse this code in GetDirectory()
			

			// Steps:
			// Get the directory (dir)

			// Get the parent of that directory (either by string manipulation or by Directory.GetParent)
			if (dir)
			// Make a new path from it
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
		this.Update();
	}

	[SetsRequiredMembers]
	public MyPath(string formattedPath, Dictionary<string, string> variables)
	{
		UserDir = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile).Replace(@"\", "/");
		ScriptDir = Directory.GetCurrentDirectory().Replace(@"\", "/");
		RootDir = Directory.GetParent(ScriptDir)?.Parent?.FullName.Replace(@"\", "/") ?? "";
		UpperRootDir = Directory.GetParent(RootDir)?.FullName.Replace(@"\", "/") ?? "";
		ConfigDir = $"{RootDir}/Sandbox/Config";
		// Supposedly can replace the duplicated setup with just
		// MyPath();
		// However sublime doesn't like that
		FormattedPath = formattedPath;
		Variables = variables;
		this.Update();
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
		this.Update();
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
		this.Update();
	}
}