import re
import os
from datetime import datetime

LOG_PATH = r"C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Regex to find and remove ANSI escape color codes
ANSI_ESCAPE = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])')

# Clean text patterns matching your layout
START_PATTERN = re.compile(r"^\[(\d{2}:\d{2}:\d{2})\].*?\[download\] Downloading item (\d+) of (\d+)")
DEST_PATTERN  = re.compile(r"\[download\] Destination: .*\\([^\\]+\.[a-zA-Z0-9]+)$")
FINAL_PATTERN = re.compile(r"^\[(\d{2}:\d{2}:\d{2})\].*?Sync completed successfully!")

track_metrics = []
active_track = None

print("Parsing colorized pipeline log streams...")

if not os.path.exists(LOG_PATH):
    print(f"Error: Log file not found at {LOG_PATH}")
    exit(1)

with open(LOG_PATH, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        # Strip invisible color/style codes from the line
        clean_line = ANSI_ESCAPE.sub('', line)
        
        # Check if a new track is starting
        start_match = START_PATTERN.match(clean_line)
        if start_match:
            new_timestamp = datetime.strptime(start_match.group(1), "%H:%M:%S")
            new_index = start_match.group(2)
            
            # If there's an active track running, close it out using the new track's start time
            if active_track:
                delta = (new_timestamp - active_track["start_time"]).total_seconds()
                if delta < 0: delta += 86400  # Midnight safety
                
                track_metrics.append({
                    "index": active_track["index"],
                    "name": active_track["name"],
                    "duration": delta
                })
            
            # Start tracking the new item
            active_track = {
                "index": new_index,
                "start_time": new_timestamp,
                "name": "Unknown Track (Skipped or Existing)"
            }
            continue

        # Capture the file name from the destination line
        dest_match = DEST_PATTERN.search(clean_line)
        if dest_match and active_track:
            active_track["name"] = dest_match.group(1)
            continue

        # Catch a final script completion line if present
        final_match = FINAL_PATTERN.match(clean_line)
        if final_match and active_track:
            final_timestamp = datetime.strptime(final_match.group(1), "%H:%M:%S")
            delta = (final_timestamp - active_track["start_time"]).total_seconds()
            if delta < 0: delta += 86400
            
            track_metrics.append({
                "index": active_track["index"],
                "name": active_track["name"],
                "duration": delta
            })
            active_track = None

# --- Metrics Output Engine ---
if track_metrics:
    total_songs = len(track_metrics)
    all_durations = [t["duration"] for t in track_metrics]
    avg_speed = sum(all_durations) / total_songs
    
    slowest_tracks = sorted(track_metrics, key=lambda x: x["duration"], reverse=True)[:5]
    fastest_tracks = sorted(track_metrics, key=lambda x: x["duration"])[:3]

    print("\n" + "="*55)
    print("           PIPELINE EFFICIENCY ANALYSIS           ")
    print("="*55)
    print(f"Total Processed Audio Items  : {total_songs}")
    print(f"Average Pipeline Speed       : {avg_speed:.1f} seconds / song")
    print(f"Projected Velocity           : {((3600 / avg_speed) if avg_speed > 0 else 0):.0f} songs / hour")
    print(f"Total Cumulative Engine Time : {sum(all_durations)/60:.1f} minutes")
    
    print("\n🚀 TOP 3 FASTEST SWEEPS (Cached / Instant):")
    for i, track in enumerate(fastest_tracks, 1):
        print(f"  {i}. Item #{track['index']} ({track['duration']:.0f}s) -> {track['name']}")

    print("\n🐢 TOP 5 SLOWEST BOTTLENECK OUTLIERS:")
    for i, track in enumerate(slowest_tracks, 1):
        print(f"  {i}. Item #{track['index']} ({track['duration']:.0f}s) -> {track['name']}")
    print("="*55)
else:
    print("\nStill no track patterns recognized. Ensure the line matches '[HH:MM:SS] ... [download] Downloading item'")
