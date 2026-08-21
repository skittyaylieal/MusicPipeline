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

// Hash the first string using the static method
ulong firstHash = XxHash64.Hash(firstBytes);

// Hash the second string using the static method
ulong secondHash = XxHash64.Hash(secondBytes);


//Orchestrator.Start();


// Working!