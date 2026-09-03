using MusicPipeline.Metrics;
using MusicPipeline.Alerts;
namespace MusicPipeline.Songs;

public class IdentifierFile 
{
	public required Metrics.Metric Metrics {get; set;}
	public required SongIdentifier[] Tracks {get; set;}
	public Alerts.Alert[]? Alerts {get; set;}
}


//SAMPLE CONTENT:

/*
$Global:CachedMetrics = @{
		masterCount  = 0; mobileCount = 0; lrcCount = 0 
		masterSize   = 0; mobileSize  = 0; alerts = @() 
		loadingState = "scanning"; tracks = @() 
}


if ($TrackDatabase.Count % 150 -eq 0) { 
		$TempFile = "$CFile.tmp"
		@{
				masterCount  = $MasterFiles.Count 
				mobileCount  = $MobileFiles.Count 
				lrcCount     = $LrcFiles.Count 
				masterSize   = [Math]::Round($MasterSize, 2) 
				mobileSize   = [Math]::Round($MobileSize, 2) 
				alerts       = @() 
				loadingState = "scanning" 
				tracks       = $TrackDatabase 
		} | ConvertTo-Json -Depth 4 | Out-File -FilePath $TempFile -Encoding utf8 -Force 
		
		Move-Item -Path $TempFile -Destination $CFile -Force
}



{
	"masterCount": 14976,
	"loadingState": "scanning",
	"mobileSize": 53.11,
	"masterSize": 162.57,
	"mobileCount": 14976,
	"tracks": [
		{
			"album": "Nina",
			"hasLrc": true,
			"title": "Nina",
			"artist": ".Feast",
			"type": "M4A",
			"isInstrumental": false,
			"id": "8dc220c4215f123926d1a30cae7d03cf",
			"sizeMb": 14.51
		},
		{
			"album": "Celeste B-Sides (Original Game Soundtrack)",
			"hasLrc": false,
			"title": "Mirror Temple (Mirror Magic Mix)",
			"artist": "2 Mello",
			"type": "M4A",
			"isInstrumental": true,
			"id": "1cf7448423b8d829fbf89740f0ca5aaa",
			"sizeMb": 12.32
		},
		……………………
		{
			"album": "So Good",
			"hasLrc": true,
			"title": "So Good (GOLDHOUSE Remix)",
			"artist": "Zara Larsson, Ty Dolla $ign",
			"type": "M4A",
			"isInstrumental": false,
			"id": "232da366ce49a7eaffe7dcc9db8a1447",
			"sizeMb": 10.47
		},
		{
			"album": "So Good",
			"hasLrc": true,
			"title": "So Good",
			"artist": "Zara Larsson, Ty Dolla $ign",
			"type": "M4A",
			"isInstrumental": false,
			"id": "691469811d599f274c347510f245ca49",
			"sizeMb": 8.06
		},
		{
			"album": "Midnight Sun： Girls Trip",
			"hasLrc": true,
			"title": "Hot & Sexy (Girls Trip)",
			"artist": "Zara Larsson, Tyla",
			"type": "M4A",
			"isInstrumental": false,
			"id": "1c1a00487295f6931a9521f91b9b07a1",
			"sizeMb": 10.51
		},
		{
			"album": "Can't Tame Her",
			"hasLrc": true,
			"title": "Can't Tame Her (VIZE Remix)",
			"artist": "Zara Larsson, VIZE",
			"type": "M4A",
			"isInstrumental": false,
			"id": "b7c2dce691fc6495ccdf8419a3c4729e",
			"sizeMb": 8.36
		},
		{
			"album": "So Good",
			"hasLrc": true,
			"title": "Sundown",
			"artist": "Zara Larsson, Wizkid",
			"type": "M4A",
			"isInstrumental": false,
			"id": "a4e42b284ba1804f90439e60790c26db",
			"sizeMb": 9.76
		},
		{
			"album": "Poster Girl",
			"hasLrc": true,
			"title": "Talk About Love",
			"artist": "Zara Larsson, Young Thug",
			"type": "M4A",
			"isInstrumental": false,
			"id": "fe395885c2cf34a5d4fd3f2659492ce9",
			"sizeMb": 10.06
		},
		{
			"album": "Talk About Love",
			"hasLrc": true,
			"title": "Talk About Love",
			"artist": "Zara Larsson, Young Thug",
			"type": "M4A",
			"isInstrumental": false,
			"id": "737699c62f9db6d9a4587ae9587b4870",
			"sizeMb": 9.93
		},
		{
			"album": "Icarus Falls",
			"hasLrc": true,
			"title": "Dusk Till Dawn (Radio Edit)",
			"artist": "ZAYN, Sia",
			"type": "M4A",
			"isInstrumental": false,
			"id": "919edc787b917743c35a27b3ded7862b",
			"sizeMb": 11.09
		}
	],
	"lrcCount": 12771,
	"alerts": [
		{
			"type": "warning",
			"fixAction": "gitpull",
			"message": "Repository Update Available: Changes pushed from Mac are ready."
		}
	]
}

*/
