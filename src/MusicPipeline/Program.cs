// See https://aka.ms/new-console-template for more information
using MusicPipeline.Orchestrator;
// using MusicPipeline.Profiles;
// using System.Text.Json;
using System.IO.Hashing;
using System.Text;

string firstString = "Hello, World!";
string secondString = "Another string!";

// Convert strings to byte arrays
byte[] firstBytes = Encoding.UTF8.GetBytes(firstString);
byte[] secondBytes = Encoding.UTF8.GetBytes(secondString);

// Create XxHash64 instance
XxHash64 xxHash = new XxHash64();

// Hash the first string
ulong firstHash = xxHash.Hash(firstBytes);

// Hash the second string
ulong secondHash = xxHash.Hash(secondBytes);


//Orchestrator.Start();


// Working!