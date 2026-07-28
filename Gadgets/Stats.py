import os
import re
from datetime import datetime

LOG_PATH = r"C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Regex to strip ANSI escape color sequences
ANSI_ESCAPE = re.compile(r"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")

# Structural Log Patterns
START_PATTERN = re.compile(
    r"^\[(\d{2}:\d{2}:\d{2})\]\s*\[Track\s+(\d+)\]\s*\[\*\]\s*\[(\d+)/(\d+)\]\s*Evaluating:\s*(.*)"
)

MEM_PATTERN = re.compile(
    r"^\[(\d{2}:\d{2}:\d{2})\].*?RAM \(WS\):\s*([\d\.]+)MB\s*\|\s*Private:\s*([\d\.]+)MB\s*\|\s*Handles:\s*(\d+)"
)

END_PATTERN = re.compile(
    r"^\[(\d{2}:\d{2}:\d{2})\]\s*\[Track\s+(\d+)\]\s*-{10,}"
)


def format_duration(seconds: float) -> str:
    """Format seconds into readable H:M:S string."""
    seconds = int(seconds)
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60
    secs = seconds % 60
    if hours > 0:
        return f"{hours}h {minutes}m {secs}s"
    elif minutes > 0:
        return f"{minutes}m {secs}s"
    else:
        return f"{secs}s"


# Tracking Containers
active_tracks = {}  # { track_id: {"start_time": datetime, "name": str} }
completed_tracks = []  # [{ "id": str, "name": str, "duration": float }]
mem_samples = []  # [(timestamp, ws_mb, private_mb, handles)]

first_timestamp = None
last_timestamp = None
latest_track_idx = 0
total_queue_count = 0

print("Parsing parallel lyrics engine log stream...")

if not os.path.exists(LOG_PATH):
    print(f"Error: Log file not found at {LOG_PATH}")
    exit(1)

with open(LOG_PATH, "r", encoding="utf-8", errors="ignore") as f:
    for line in f:
        clean_line = ANSI_ESCAPE.sub("", line)

        # 1. Parse Memory Metric Checkpoints
        mem_match = MEM_PATTERN.search(clean_line)
        if mem_match:
            ts = datetime.strptime(mem_match.group(1), "%H:%M:%S")
            ws_ram = float(mem_match.group(2))
            priv_ram = float(mem_match.group(3))
            handles = int(mem_match.group(4))

            if not first_timestamp:
                first_timestamp = ts
            last_timestamp = ts

            mem_samples.append((ts, ws_ram, priv_ram, handles))
            continue

        # 2. Parse Track Start Line & Queue Position
        start_match = START_PATTERN.match(clean_line)
        if start_match:
            ts = datetime.strptime(start_match.group(1), "%H:%M:%S")
            track_id = start_match.group(2)
            curr_idx = int(start_match.group(3))
            total_count = int(start_match.group(4))
            full_path = start_match.group(5).strip()

            if curr_idx > latest_track_idx:
                latest_track_idx = curr_idx
            total_queue_count = total_count

            if not first_timestamp:
                first_timestamp = ts
            last_timestamp = ts

            active_tracks[track_id] = {
                "start_time": ts,
                "name": os.path.basename(full_path),
            }
            continue

        # 3. Parse Track End Line (Divider)
        end_match = END_PATTERN.match(clean_line)
        if end_match:
            ts = datetime.strptime(end_match.group(1), "%H:%M:%S")
            track_id = end_match.group(2)
            last_timestamp = ts

            if track_id in active_tracks:
                start_time = active_tracks[track_id]["start_time"]
                delta = (ts - start_time).total_seconds()
                if delta < 0:
                    delta += 86400  # Midnight rollover safety

                completed_tracks.append(
                    {
                        "id": track_id,
                        "name": active_tracks[track_id]["name"],
                        "duration": delta,
                    }
                )
                del active_tracks[track_id]
            continue

# --- Metrics Analysis & Report Engine ---
if completed_tracks or mem_samples:
    total_processed = len(completed_tracks)

    # Calculate Total Elapsed Log Duration (Wall-Clock)
    wall_clock_sec = 0
    if first_timestamp and last_timestamp:
        wall_clock_sec = (last_timestamp - first_timestamp).total_seconds()
        if wall_clock_sec < 0:
            wall_clock_sec += 86400

    print("\n" + "=" * 65)
    print("        LYRICS ENGINE EFFICIENCY & RESOURCE REPORT        ")
    print("=" * 65)

    # Queue Progress & Speed Calculations
    remaining_tracks = max(0, total_queue_count - latest_track_idx)

    print("📊 QUEUE PROGRESS & SPEED:")
    print(
        f"  Queue Position        : Track {latest_track_idx:,} / {total_queue_count:,}"
    )
    print(
        f"  Log Window Finished   : {total_processed:,} tracks completed in active buffer"
    )

    if wall_clock_sec > 0 and total_processed > 0:
        tracks_per_sec = total_processed / wall_clock_sec
        tracks_per_min = tracks_per_sec * 60
        tracks_per_hour = tracks_per_sec * 3600

        print(f"  Wall-Clock Duration   : {format_duration(wall_clock_sec)}")
        print(f"  Current Processing    : {tracks_per_min:.2f} tracks / minute")
        print(f"  Extrapolated Rate     : {tracks_per_hour:.0f} tracks / hour")

        if remaining_tracks > 0:
            eta_seconds = remaining_tracks / tracks_per_sec
            print(f"  Tracks Remaining      : {remaining_tracks:,}")
            print(
                f"  Estimated Time Left   : ~{format_duration(eta_seconds)} (ETA)"
            )
        else:
            print("  Status                : Pipeline queue complete!")
    else:
        print("  Processing Speed      : Gathering sufficient log history...")

    # Thread Processing Averages
    if completed_tracks:
        durations = [t["duration"] for t in completed_tracks]
        avg_track_time = sum(durations) / len(durations)
        print(
            f"  Avg Single Thread     : {avg_track_time:.2f} seconds / track"
        )

    # Resource Fluctuations & Delta Analysis
    if mem_samples:
        ws_vals = [s[1] for s in mem_samples]
        priv_vals = [s[2] for s in mem_samples]
        handle_vals = [s[3] for s in mem_samples]

        # Sequential deltas between samples
        ws_diffs = [
            ws_vals[i] - ws_vals[i - 1] for i in range(1, len(ws_vals))
        ]
        priv_diffs = [
            priv_vals[i] - priv_vals[i - 1] for i in range(1, len(priv_vals))
        ]
        handle_diffs = [
            handle_vals[i] - handle_vals[i - 1]
            for i in range(1, len(handle_vals))
        ]

        print("\n🧠 MEMORY & HANDLE DYNAMICS:")
        print(
            f"  Working Set RAM       : Current {ws_vals[-1]:.1f} MB | Avg {sum(ws_vals)/len(ws_vals):.1f} MB | Peak {max(ws_vals):.1f} MB"
        )
        print(
            f"  Private Bytes         : Current {priv_vals[-1]:.1f} MB | Avg {sum(priv_vals)/len(priv_vals):.1f} MB | Peak {max(priv_vals):.1f} MB"
        )
        print(
            f"  Process Handles       : Current {handle_vals[-1]} | Avg {int(sum(handle_vals)/len(handle_vals))} | Peak {max(handle_vals)}"
        )

        if ws_diffs:
            max_ws_spike = max(ws_diffs)
            max_ws_drop = min(ws_diffs)
            max_handle_spike = max(handle_diffs)
            max_handle_drop = min(handle_diffs)

            print("\n📈 FLUCTUATIONS & TURBULENCE (Between Checks):")
            print(
                f"  RAM Largest Spike     : +{max_ws_spike:.2f} MB"
                if max_ws_spike > 0
                else "  RAM Largest Spike     : None"
            )
            print(
                f"  RAM Largest Drop      : {max_ws_drop:.2f} MB"
                if max_ws_drop < 0
                else "  RAM Largest Drop      : None"
            )
            print(
                f"  Handle Largest Spike  : +{max_handle_spike} handles"
                if max_handle_spike > 0
                else "  Handle Largest Spike  : None"
            )
            print(
                f"  Handle Largest Drop   : {max_handle_drop} handles"
                if max_handle_drop < 0
                else "  Handle Largest Drop   : None"
            )

    # Outliers
    if completed_tracks:
        slowest_tracks = sorted(
            completed_tracks, key=lambda x: x["duration"], reverse=True
        )[:3]
        fastest_tracks = sorted(
            completed_tracks, key=lambda x: x["duration"]
        )[:3]

        print("\n⚡ FASTEST TRACK SWEEPS:")
        for i, track in enumerate(fastest_tracks, 1):
            print(
                f"  {i}. Track #{track['id']} ({track['duration']:.1f}s) -> {track['name']}"
            )

        print("\n🐢 SLOWEST BOTTLENECKS (API Delays/Retries):")
        for i, track in enumerate(slowest_tracks, 1):
            print(
                f"  {i}. Track #{track['id']} ({track['duration']:.1f}s) -> {track['name']}"
            )

    print("=" * 65)
else:
    print("\nNo track or memory markers recognized in the log file.")