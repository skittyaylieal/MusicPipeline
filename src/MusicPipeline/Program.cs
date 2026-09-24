// See https://aka.ms/new-console-template for more information
using System;
using MusicPipeline.Orchestrator;
// using MusicPipeline.Profiles;
// using System.Text.Json;
// using MusicPipeline.Tools.LogEngine;
// using System.Diagnostics;

var orc = new Orchestrator();
//Console.WriteLine(orc);
string machineName = Environment.MachineName;
//Console.WriteLine(machineName);
string? tempProfileFile = null;
if (!machineName.Contains("MICRO_PC")) {
	//Console.WriteLine("Finding portable profile file");
	string rootDir = Directory.GetCurrentDirectory(); // This is always the directory with the .csproj, so Repo/src/MusicPipeline
	//Console.WriteLine(rootDir);
	string? upperRoot = Directory.GetParent(rootDir)?.Parent?.FullName;
	//Console.WriteLine(upperRoot);
	//Console.WriteLine($"rootDir = {rootDir}, upperRoot = {upperRoot}, machineName = {machineName}");
	tempProfileFile = $"{upperRoot}/Config/csProfilesPortable.json";
	//Console.WriteLine(tempProfileFile);
	//await ProfileManager.SaveProfile(tempProfileFile, DefaultProfiles.DefaultProfile, true, true);// Temporary debug
}
using (var fs = File.Open(@"C:/Users/23fpybus_cheneyschoo/SublimeContained/Music/MusicPipeline/Sandbox/Config/csLogFile.log", FileMode.Open))
{
    Console.WriteLine(fs.CanRead);
    Console.WriteLine(fs.CanWrite);
}
Console.WriteLine("Starting Orchestrator");
await orc.Start(tempProfileFile ?? @"C:/MusicTools/MusicPipeline/Sandbox/Config/csProfiles.json");
/*var fields = typeof(DefaultProfiles).GetFields();
foreach (System.Reflection.FieldInfo field in fields) {
	Console.WriteLine($"name {field.Name}, declaringtype {field.DeclaringType}, Member type {field.MemberType}, FieldType {field.FieldType}");
}*/
// Working!
// Yay!