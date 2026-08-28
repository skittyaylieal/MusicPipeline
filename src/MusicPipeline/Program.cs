// See https://aka.ms/new-console-template for more information
//using MusicPipeline.Orchestrator;
// using MusicPipeline.Profiles;
// using System.Text.Json;
// using MusicPipeline.Tools.LogEngine;
// using System.Diagnostics;

//var orc = new Orchestrator();
//await orc.Start();

using MusicPipeline.Pipeline.Helpers.Parser;
var par = new Parser();
par.ParseYTDLPConfigFile(@"C:\MusicTools\MusicPipeline\Sandbox\Config\csProfiles.json");

// Working!
// Yay!