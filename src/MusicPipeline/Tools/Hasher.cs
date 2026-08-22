using System.Text;
using System.IO.Hashing;
namespace MusicPipeline.Tools.Hasher;

public static class Hasher
{
	public static UInt64 GetHashForSong(string Title, string Artist, string Album = "NONE")
	{
		string str = $"{Title}-{Artist}-{Album}";
		var strBytes = Encoding.UTF8.GetBytes(str);
		return BitConverter.ToUInt64(XxHash64.Hash(strBytes));
	}
}

// NOT WORKING
// TEST STUFF

// describe how it's not working as first step of testing & getting it to work.

// Already fixed, that was done in Program.cs
// there was some explanation that got deleted