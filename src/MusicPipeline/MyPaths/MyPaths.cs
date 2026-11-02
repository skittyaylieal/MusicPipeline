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
			// This block handles anything which isn't automatically a directory
			// which is anything not ending in '/'. Ideally, any path which is just [$var] should end in a / if that [$var] is a directory.
			/*
			CASES:
			[$UserDir]/file
			[$UserDir]/Dir/file
			[$ConfigFile] (hypothetical preset which isn't a directory)
			*/
			// First, we need to handle the case of just a variable file
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
					return new(temp.Path.Substring(0, temp.Path.LastIndexOf('/')), true);
				}
			} 
			// If it doesn't end in a '/' or a ']' then it must be one of
			/*
			[$UserDir]/file
			[$UserDir]/Dir/file
			*/
			return new(p.Substring(0, p.LastIndexOf('/')));
		}
	}

	public MyPath GetParent()
	{
		// This will work in the case of [$UserDir]/Dir/file
		// And in [$UserDir]/Dir/
		// But not in the case of [$UserDir]/file
		// Or just plain [$UserDir]/

		/*
		CASES:
		.../Dir/file
		.../Dir/
		[$UserDir]/
		[$UserDir]/Dir/
		[$UserDir]/Dir/file
		[$UserDir]/file
		[$ConfigFile]
		Getting the directory will narrow cases to
		.../Dir/
		[$UserDir]/
		[$UserDir]/Dir/
		(Dir of [$ConfigFile] will be one of the above cases)

		*/

		// Operating on dir for everything
		dir = GetDirectory();
		var fp = dir.FormattedPath;

		bool onlyVariable = (fp[^1] == ']') || (fp[^2] == ']');
		
		if (onlyVariable) {
			string par = Directory.GetParent(dir.Variables?.ElementAt(0).Value.Path ?? "")?.FullName ?? "";
			this.Update();
			//this.parent = new(par, true); // unnecessary
			return new(par, true);
		} else {
			// If it's not only a variable then it's .../Dir/ or [$UserDir]/Dir/
			// We want to strip the /Dir/ from the end
			// RegEx it!
			string parentPattern = @".*\/(.+\/)"; // .* is any char repeated any times. To catch /Dir/
			// \/ matches the literal '/'
			// () is a capturing group capturing just the .+\/
			// .+ matches any char at least once
			// \/ another literal '/'
			// This regex matches the Dir/ of those 2 paths

			// Extract the group
			// Remove it
			var match = Regex.Match(fp, parentPattern);
			string val = match.Groups[0].Value;
			return new(fp.Remove(fp.LastIndexOf(val)), true);
		}
	}

	[SetsRequiredMembers]
	[JsonConstructor]
	public MyPath(string formattedPath) : this(formattedPath, isRaw: false) {}

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
	public MyPath(string formattedPath, bool isRaw = false) : this()
	{

		// Must be last V
		FormattedPath = isRaw ? this.Format(formattedPath).formatted : formattedPath;
		this.Update();
	}

	[SetsRequiredMembers]
	public MyPath(string formattedPath, Dictionary<string, Preset> variables) : this()
	{
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
		UserDir = new(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile).Replace(@"\", "/"), true);
		ScriptDir = new(Directory.GetCurrentDirectory().Replace(@"\", "/"), true);
		RootDir = new(Directory.GetParent(ScriptDir.Path)?.Parent?.FullName.Replace(@"\", "/") ?? "", true);
		UpperRootDir = new(Directory.GetParent(RootDir.Path)?.FullName.Replace(@"\", "/") ?? "", true);
		ConfigDir = new($"{RootDir}/Sandbox/Config", true);
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