// See https://aka.ms/new-console-template for more information
using System;
using MusicPipeline.Orchestrator;
// using MusicPipeline.Profiles;
// using System.Text.Json;
// using MusicPipeline.Tools.LogEngine;
// using System.Diagnostics;

var orc = new Orchestrator();
string machineName = Environment.MachineName;
string? tempProfileFile = null;
if (machineName != "FILIPS_MICRO_PC") {
	string rootDir = Directory.GetCurrentDirectory(); // This is always the directory with the .csproj, so Repo/src/MusicPipeline
	string? upperRoot = Directory.GetParent(rootDir).Parent.FullName;
	Console.WriteLine($"rootDir = {rootDir}, upperRoot = {upperRoot}, machineName = {machineName}");
	tempProfileFile = $@"{upperRoot}\Config\csProfilesPortable.json";
	Console.WriteLine($@"{upperRoot}\Config\csProfilesPortable.json");
	//await ProfileManager.SaveProfile(tempProfileFile, DefaultProfiles.DefaultProfile, true, true);// Temporary debug
}
Console.WriteLine("Starting Orchestrator");
await orc.Start(tempProfileFile ?? @"C:\MusicTools\MusicPipeline\Sandbox\Config\csProfiles.json");
/*var fields = typeof(DefaultProfiles).GetFields();
foreach (System.Reflection.FieldInfo field in fields) {
	Console.WriteLine($"name {field.Name}, declaringtype {field.DeclaringType}, Member type {field.MemberType}, FieldType {field.FieldType}");
}*/
// Working!
// Yay!