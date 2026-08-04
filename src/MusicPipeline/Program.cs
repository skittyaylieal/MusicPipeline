// See https://aka.ms/new-console-template for more information
using MusicPipeline.Orchestrator;
using MusicPipeline.Profiles;
using System.Text.Json;

// Orchestrator.Start();
var Options = new JsonSerializerOptions { WriteIndented = true };
List<Profile> TestProfiles = new List<Profile>(){DefaultProfiles.DefaultProfile, new Profile(), DefaultProfiles.ErrorProfile};
ProfileFile TestProfileFile = new ProfileFile(TestProfiles);
string TestJsonString = JsonSerializer.Serialize(TestProfileFile, Options);
string TestJsonFileName = @"C:\MusicTools\MusicPipeline\Sandbox\TestJsonFile.json";
File.WriteAllText(TestJsonFileName, TestJsonString);