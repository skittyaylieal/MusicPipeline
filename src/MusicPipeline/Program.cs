// See https://aka.ms/new-console-template for more information
using MusicPipeline.Orchestrator;
// using MusicPipeline.Profiles;
// using System.Text.Json;
// using MusicPipeline.Tools.LogEngine;
// using System.Diagnostics;

var orc = new Orchestrator();
await orc.Start();
/*var fields = typeof(DefaultProfiles).GetFields();
foreach (System.Reflection.FieldInfo field in fields) {
	Console.WriteLine($"name {field.Name}, declaringtype {field.DeclaringType}, Member type {field.MemberType}, FieldType {field.FieldType}");
}*/
// Working!
// Yay!