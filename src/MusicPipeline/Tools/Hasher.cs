using System.Text;
using HashifyNet;
using HashifyNet.Algorithms.XxHash;
namespace MusicPipeline.Tools.Hasher;

public static class Hasher
{
	public static UInt64 GetHashForSong(string Title, string Artist, string Album = "NONE")
	{
		string str = $"{Title}-{Artist}-{Album}";
		// HEAVILY MODIFIED FROM DemarcPoint on Stack Overflow to use Hashify and xxHash64
		// https://stackoverflow.com/a/35416167/22942130

		XxHash XxHash3 = HashFactory<XxHash>.Create();
		// Compute 64bit hash
		var result = xxHash3.ComputerHash(Encoding.UTF8.GetBytes(str));
		return BitConverter.ToUInt64(result.Hash, 0);
	}
}