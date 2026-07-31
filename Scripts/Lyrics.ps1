Param (
    [string]$BackupDir,
    [switch]$ForceFullRefresh,
    [int]$ThrottleLimit = 4
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$env:PYTHONIOENCODING = "utf-8"
try { Clear-Host } catch {}

$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Thread-Synchronized Global State for Rate Limiting / Cooldown
$GlobalState = [hashtable]::Synchronized(@{
    CooldownUntil = [datetime]::MinValue
})

# Main Thread Logger
function Invoke-MainLogMsg([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC       = [char]27
    $Reset     = "$ESC[0m"
    $ColorPrefix   = "$ESC[34m[$Timestamp] [LyricsEngine]$Reset"
    $FormattedLine = "$ColorPrefix $Text"
    
    Write-Host $FormattedLine
    if (Test-Path -LiteralPath $GlobalLogFile) {
        try { [System.IO.File]::AppendAllText($GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine)) } catch {}
    }
}

# Top-level Native Process Handler
function Invoke-MainNativeProcess ([string]$Executable, [string[]]$ArgumentList) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName               = $Executable
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true 
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    foreach ($arg in $ArgumentList) { $psi.ArgumentList.Add($arg) }
    
    $proc = $null
    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.WaitForExit()
        return $proc.ExitCode
    } finally {
        if ($null -ne $proc) {
            $proc.Close()
            $proc.Dispose()
        }
    }
}

Invoke-MainLogMsg "============================================="
Invoke-MainLogMsg "    PowerShell Module: Max Quality Lyric Engine & Tag Embedder"
Invoke-MainLogMsg "============================================="

Invoke-MainLogMsg "[*] Verifying background Python dependencies..."
$PipExit = Invoke-MainNativeProcess "pip" @("install", "--upgrade", "syncedlyrics", "mutagen", "--quiet")
Invoke-MainLogMsg "[*] Pip verification routine complete (Exit Code: $PipExit)."

if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    Invoke-MainLogMsg "[ERROR] Target backup directory could not be found: $BackupDir"
    Exit 1
}

if ($ForceFullRefresh) {
    Invoke-MainLogMsg "🧹 [CLEAN SWEEP REFRESH] Forcing deep query over every track. Stale local .lrc files will be purged."
}

Invoke-MainLogMsg "[*] Initializing deep database scan across: $BackupDir"

try {
    $AllFiles = [System.IO.Directory]::EnumerateFiles($BackupDir, "*.*", [System.IO.SearchOption]::AllDirectories)
} catch {
    Invoke-MainLogMsg "[ERROR] Failed to initialize deep directory enumeration: $_"
    Exit 1
}

$AudioFiles = [System.Collections.Generic.List[string]]::new()
foreach ($File in $AllFiles) {
    if ($File -match '\.(flac|mp3|m4a)$') {
        $AudioFiles.Add($File)
    }
}

if ($AudioFiles.Count -eq 0) {
    Invoke-MainLogMsg "[+] No audio tracks found across the system array."
    $MetricStopwatch.Stop()
    Invoke-MainLogMsg "[METRIC] 00:00:00"
    Exit 0
}

Invoke-MainLogMsg "[+] Deep scan complete. Found $($AudioFiles.Count) total track(s) to process."
Invoke-MainLogMsg "[*] Spawning parallel worker pool (Max Threads: $ThrottleLimit)..."
Invoke-MainLogMsg "---------------------------------------------"

$TrackObjects = [System.Collections.Generic.List[PSCustomObject]]::new()
for ($i = 0; $i -lt $AudioFiles.Count; $i++) {
    $TrackObjects.Add([PSCustomObject]@{
        Index = $i + 1
        Path  = $AudioFiles[$i]
    })
}

$TotalTracks = $AudioFiles.Count

# PARALLEL WORKER ENGINE
$TrackObjects | ForEach-Object -Parallel {
    $TrackIndex       = $_.Index
    $FilePath         = $_.Path
    $TotalCount       = $using:TotalTracks
    $GlobalLogFile    = $using:GlobalLogFile
    $ForceFullRefresh = $using:ForceFullRefresh
    $GlobalState      = $using:GlobalState

    # Initialize helper functions ONCE per runspace session state to avoid scope bloat
    if (-not (Test-Path function:\Invoke-LogMsg)) {
        function Invoke-LogMsg([string]$Text, [int]$Idx) {
            if ([string]::IsNullOrWhiteSpace($Text)) { return }
            $Timestamp = (Get-Date).ToString("HH:mm:ss")
            $ESC       = [char]27
            $Reset     = "$ESC[0m"
            
            $ColorCode = switch (($Idx - 1) % 12) {
                0  { "38;5;51" }   # Cyan
                1  { "38;5;201" }  # Magenta
                2  { "33" }        # Yellow
                3  { "38;5;135" }  # Purple
                4  { "38;5;208" }  # Orange
                5  { "38;5;217" }  # Peach
                6  { "38;5;75" }   # Sky Blue
                7  { "38;5;118" }  # Bright Lime
                8  { "38;5;213" }  # Orchid Pink
                9  { "38;5;37" }   # Teal
                10 { "38;5;203" }  # Coral Red
                11 { "38;5;141" }  # Lavender
                default { "32" }   # Fallback Green
            }
            
            if ($Text -match '🛑|THREAD DEBUG ALERT|error:|ERROR:|Usage:|\[!\]|⏸️') {
                $ColorCode = "1;31"
            }

            $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [Track $Idx]$Reset"
            $FormattedLine = "$ColorPrefix $Text"
            
            Write-Host $FormattedLine
            
            if (Test-Path -LiteralPath $GlobalLogFile) {
                $RetryCount = 0
                while ($RetryCount -lt 15) {
                    try {
                        [System.IO.File]::AppendAllText($GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine))
                        break
                    } catch [System.IO.IOException] {
                        $RetryCount++
                        [System.Threading.Thread]::Sleep(50)
                    } catch { break }
                }
            }
        }

        function Test-And-WaitCooldown ([int]$Idx) {
            while ($true) {
                $Until = $GlobalState.CooldownUntil
                $Now   = [datetime]::Now
                if ($Now -lt $Until) {
                    $Remaining = [math]::Ceiling(($Until - $Now).TotalSeconds)
                    Invoke-LogMsg "    [⏸️ COOLDOWN ACTIVE] Rate-limit backoff active (${Remaining}s remaining). Thread sleeping..." $Idx
                    [System.Threading.Thread]::Sleep(5000)
                } else {
                    break
                }
            }
        }

        function Trigger-RateLimitCooldown ([string]$Reason, [string]$AudioPath, [string]$LrcPath, [string]$TxtPath, [int]$Idx) {
            $NewUntil = [datetime]::Now.AddSeconds(60)
            [System.Threading.Monitor]::Enter($GlobalState.SyncRoot)
            try {
                if ($NewUntil -gt $GlobalState.CooldownUntil) {
                    $GlobalState.CooldownUntil = $NewUntil
                    Invoke-LogMsg "    [🛑 429 / RATE LIMIT DETECTED] $Reason" $Idx
                    Invoke-LogMsg "    [⏸️ GLOBAL PAUSE] Triggering 60-second API cooldown across all worker threads..." $Idx
                }
            } finally {
                [System.Threading.Monitor]::Exit($GlobalState.SyncRoot)
            }

            if (Test-Path -LiteralPath $LrcPath) { Remove-Item -LiteralPath $LrcPath -Force -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $TxtPath) { Remove-Item -LiteralPath $TxtPath -Force -ErrorAction SilentlyContinue }

            Invoke-LogMsg "    [🧹 TAG PURGE] Wiping embedded lyrics tags from track container..." $Idx
            $WipePython = @"
import sys, mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3

file_path = sys.argv[1]
try:
    audio = mutagen.File(file_path)
    if audio is not None:
        if isinstance(audio, MP4):
            if '\xa9lyr' in audio:
                del audio['\xa9lyr']
                audio.save()
        elif isinstance(audio, FLAC):
            if 'lyrics' in audio:
                del audio['lyrics']
                audio.save()
        else:
            try:
                tags = ID3(file_path)
                tags.delall('USLT')
                tags.save(file_path)
            except Exception: pass
except Exception: pass
"@
            [void](Invoke-ThreadNativeProcess "python" @("-", $AudioPath) -InputScript $WipePython)
        }

        function Test-IsSyncedLrc ([string]$File) {
            if (-not (Test-Path -LiteralPath $File)) { return $false }
            try {
                $Lines = [System.IO.File]::ReadAllLines($File)
                $TimestampMatches = ($Lines | Where-Object { $_ -match '\[\d{1,3}:\d{2}' }).Count
                return ($TimestampMatches -ge 3)
            } catch {
                return $false
            }
        }

        function Test-IsRateLimitedFile ([string]$File) {
            if (-not (Test-Path -LiteralPath $File)) { return $false }
            try {
                $Content = [System.IO.File]::ReadAllText($File)
                if ($Content -match '(?i)429|too many requests|rate limit|throttled|retry-after') {
                    return $true
                }
            } catch {}
            return $false
        }

        # Fix 1: Properly dispose native process handle to fix the 25k handle leak
        function Get-MemorySnapshot {
            $Proc = [System.Diagnostics.Process]::GetCurrentProcess()
            try {
                $WorkingSetMB   = [math]::Round($Proc.WorkingSet64 / 1MB, 2)
                $PrivateBytesMB = [math]::Round($Proc.PrivateMemorySize64 / 1MB, 2)
                $Handles        = $Proc.HandleCount
                return "RAM (WS): ${WorkingSetMB}MB | Private: ${PrivateBytesMB}MB | Handles: $Handles"
            } finally {
                if ($null -ne $Proc) { $Proc.Dispose() }
            }
        }

        function Invoke-ThreadNativeProcess ([string]$Executable, [string[]]$ArgumentList, [string]$InputScript, [switch]$CaptureOutput) {
            $psi = [System.Diagnostics.ProcessStartInfo]::new()
            $psi.FileName               = $Executable
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError  = $true 
            $psi.RedirectStandardInput  = [bool]$InputScript
            $psi.UseShellExecute        = $false
            $psi.CreateNoWindow         = $true
            
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
            $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"

            foreach ($arg in $ArgumentList) { $psi.ArgumentList.Add($arg) }

            $proc = $null
            $stdoutBuilder = [System.Text.StringBuilder]::new()
            $isThrottled = $false
            $ThrottleRegex = '(?i)(429|too many requests|rate limit|throttled|http error 429|429 client error|retry-after)'

            try {
                $proc = [System.Diagnostics.Process]::Start($psi)

                if ($InputScript) {
                    $proc.StandardInput.Write($InputScript)
                    $proc.StandardInput.Close()
                }

                while (-not $proc.HasExited) {
                    [System.Threading.Thread]::Sleep(10)
                    while (-not $proc.StandardOutput.EndOfStream) {
                        $Line = $proc.StandardOutput.ReadLine()
                        if ($Line) { 
                            if ($Line -match $ThrottleRegex) { $isThrottled = $true }
                            if ($CaptureOutput) { [void]$stdoutBuilder.AppendLine($Line) }
                            else { Invoke-LogMsg "    [Python STDOUT] $Line" $TrackIndex }
                        }
                    }
                    while (-not $proc.StandardError.EndOfStream) {
                        $ErrLine = $proc.StandardError.ReadLine()
                        if ($ErrLine) {
                            if ($ErrLine -match $ThrottleRegex) { $isThrottled = $true }
                            if ($ErrLine -notmatch "ConnectTimeoutError|Max retries exceeded") { 
                                Invoke-LogMsg "    [Python STDERR] $ErrLine" $TrackIndex 
                            }
                        }
                    }
                }

                while (-not $proc.StandardOutput.EndOfStream) {
                    $Line = $proc.StandardOutput.ReadLine()
                    if ($Line) { 
                        if ($Line -match $ThrottleRegex) { $isThrottled = $true }
                        if ($CaptureOutput) { [void]$stdoutBuilder.AppendLine($Line) }
                        else { Invoke-LogMsg "    [Python STDOUT] $Line" $TrackIndex }
                    }
                }
                while (-not $proc.StandardError.EndOfStream) {
                    $ErrLine = $proc.StandardError.ReadLine()
                    if ($ErrLine) { 
                        if ($ErrLine -match $ThrottleRegex) { $isThrottled = $true }
                        if ($ErrLine -notmatch "ConnectTimeoutError|Max retries exceeded") { 
                            Invoke-LogMsg "    [Python STDERR] $ErrLine" $TrackIndex 
                        }
                    }
                }

                return [PSCustomObject]@{ 
                    ExitCode    = $proc.ExitCode
                    Output      = $stdoutBuilder.ToString()
                    IsThrottled = $isThrottled
                }
            } catch {
                Invoke-LogMsg "[🛑 PROCESS PANIC] Execution failure: $_" $TrackIndex
                return [PSCustomObject]@{ ExitCode = -1; Output = ""; IsThrottled = $false }
            } finally {
                if ($null -ne $stdoutBuilder) { $stdoutBuilder.Clear(); $stdoutBuilder = $null }
                if ($null -ne $proc) {
                    # Explicitly close redirected pipe streams before disposing the process
                    try { $proc.StandardInput.Close() } catch {}
                    try { $proc.StandardOutput.Close() } catch {}
                    try { $proc.StandardError.Close() } catch {}

                    try { $proc.Close() } catch {}
                    try { $proc.Dispose() } catch {}
                    $proc = $null
                }
            }
        }
    }

    try {
        # TRACK PROCESSING LOGIC
        Test-And-WaitCooldown $TrackIndex

        $FileInfo = [System.IO.FileInfo]::new($FilePath)
        
        Invoke-LogMsg "[*] [$TrackIndex/$TotalCount] Evaluating: $($FileInfo.FullName)" $TrackIndex
        Invoke-LogMsg "    🔍 [MEM CHECK] $(Get-MemorySnapshot)" $TrackIndex
        
        $DirName = $FileInfo.DirectoryName
        $LrcFile = Join-Path $DirName "$($FileInfo.BaseName).lrc"
        $TxtFile = Join-Path $DirName "$($FileInfo.BaseName).txt"
        
        if ($ForceFullRefresh) {
            if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
        }

        if (-not $ForceFullRefresh -and (Test-Path -LiteralPath $LrcFile)) {
            if (Test-IsSyncedLrc $LrcFile) {
                Invoke-LogMsg "    [-] Valid synced .lrc companion already exists on disk. Skipping." $TrackIndex
                Invoke-LogMsg "---------------------------------------------" $TrackIndex
                return
            } else {
                Invoke-LogMsg "    [!] Existing .lrc lacks timestamps or is incomplete. Staging for re-query." $TrackIndex
                Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
            }
        }

        # STEP 1: Metadata Extraction (With Multi-Tag Artist Fallbacks)
        $PreCheckPython = @"
import sys, mutagen, json
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3

file_path = sys.argv[1]
artist, title, is_inst, has_lyrics = "", "", False, False

try:
    audio = mutagen.File(file_path)
    if audio is not None:
        if isinstance(audio, MP4):
            artist = audio.get('\xa9ART', [''])[0] if '\xa9ART' in audio else (audio.get('aART', [''])[0] if 'aART' in audio else '')
            title = audio.get('\xa9nam', [''])[0] if '\xa9nam' in audio else ''
            comment = audio.get('\xa9cmt', [''])[0].lower() if '\xa9cmt' in audio else ''
            if 'instrumental' in comment: is_inst = True
            if '\xa9lyr' in audio and audio['\xa9lyr']: has_lyrics = True

        elif isinstance(audio, FLAC):
            artist = audio.get('artist', [''])[0] or audio.get('albumartist', [''])[0]
            title = audio.get('title', [''])[0]
            lang = audio.get('language', [''])[0].lower()
            comment = audio.get('comment', [''])[0].lower()
            if lang == 'zxx' or 'instrumental' in comment: is_inst = True
            if 'lyrics' in audio and audio['lyrics']: has_lyrics = True

        elif isinstance(audio, ID3) or (audio.tags and hasattr(audio.tags, 'getall')):
            if audio.tags.getall('TPE1'): artist = audio.tags.getall('TPE1')[0].text[0]
            elif audio.tags.getall('TPE2'): artist = audio.tags.getall('TPE2')[0].text[0]
            
            if audio.tags.getall('TIT2'): title = audio.tags.getall('TIT2')[0].text[0]
            if audio.tags.getall('TLAN') and audio.tags.getall('TLAN')[0].text[0].lower() == 'zxx': is_inst = True
            for comm in audio.tags.getall('COMM'):
                if 'instrumental' in comm.text.lower(): is_inst = True
            for tag in audio.tags.getall('USLT'):
                if tag.text: has_lyrics = True

    print(json.dumps({"artist": artist, "title": title, "is_inst": is_inst, "has_lyrics": has_lyrics}))
except Exception as e:
    print(json.dumps({"artist": "", "title": "", "is_inst": False, "has_lyrics": False, "error": str(e)}))
"@
        
        $MetaResult  = Invoke-ThreadNativeProcess "python" @("-", $FilePath) -InputScript $PreCheckPython -CaptureOutput
        $MetaJsonRaw = $MetaResult.Output
        $Meta        = $null
        try { $Meta = $MetaJsonRaw | ConvertFrom-Json } catch {}

        if (-not $ForceFullRefresh -and $Meta.is_inst) {
            Invoke-LogMsg "    [-] Track explicitly marked as Instrumental. Skipping API engine." $TrackIndex
            if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
            Invoke-LogMsg "---------------------------------------------" $TrackIndex
            return
        }

        $HasUnsyncedLyrics = if ($ForceFullRefresh) { $false } else { [bool]$Meta.has_lyrics }

        # STEP 2: Formulate Multi-Tier Search Queries with Path Parsing
        $ArtistTag = $Meta.artist
        $TitleTag  = $Meta.title

        # Fallback A: If Artist missing, check if Filename has "Artist - Title"
        if ([string]::IsNullOrWhiteSpace($ArtistTag) -and $FileInfo.BaseName -match '^(.+?)\s*-\s*(.+)$') {
            $PossibleArtist = $Matches[1] -replace '^\d+[\s-]*', ''
            $PossibleTitle  = $Matches[2]
            if ($PossibleArtist -and $PossibleArtist -notmatch '^\d+$') {
                $ArtistTag = $PossibleArtist.Trim()
                if ([string]::IsNullOrWhiteSpace($TitleTag)) { $TitleTag = $PossibleTitle.Trim() }
            }
        }

        # Fallback B: Infer Artist from Path Hierarchy (YT_Music_Backup/Artist/Album/Track.m4a)
        if ([string]::IsNullOrWhiteSpace($ArtistTag)) {
            $ArtistDir = if ($FileInfo.Directory.Parent) { $FileInfo.Directory.Parent.Name } else { "" }
            
            # Blacklist known roots / misdownload directories
            $IgnoredFolders = '^(uploader|playlist|YT_Music_Backup|Backup|Music|Downloads|Temp)$'
            if ($ArtistDir -and $ArtistDir -notmatch $IgnoredFolders) {
                $ArtistTag = $ArtistDir.Trim()
            }
        }

        # Fallback C: Clean Title if missing
        if ([string]::IsNullOrWhiteSpace($TitleTag)) {
            $TitleTag = ($FileInfo.BaseName -replace '^\d+[\s\.-]+', '' -replace '\s+', ' ').Trim()
        }

        $QueriesToTry = [System.Collections.Generic.List[string]]::new()

        if (-not [string]::IsNullOrWhiteSpace($ArtistTag) -and -not [string]::IsNullOrWhiteSpace($TitleTag)) {
            # Pass 1: Raw metadata query
            $RawQuery = "$ArtistTag - $TitleTag".Trim()
            $QueriesToTry.Add($RawQuery)

            # Pass 2: Cleaned normalized query
            $CleanTitle  = $TitleTag -replace '\s*[\(\[\{].*?(demo|live|remaster|pre-production|version|edit|bonus|mix|deluxe|acoustic).*?[\)\]\}]', '' -replace '\s+feat\..*', '' -replace '\s+', ' '
            $CleanArtist = $ArtistTag -replace '\s+feat\..*', ''
            $CleanQuery  = "$CleanArtist - $CleanTitle".Trim()

            if ($CleanQuery -and $CleanQuery -ne $RawQuery) {
                $QueriesToTry.Add($CleanQuery)
            }
        }

        # STRICT MULTI-TIER QUERY BUILDER
        $SafeQueries  = [System.Collections.Generic.List[string]]::new()
        $ShortQueries = [System.Collections.Generic.List[string]]::new()

        # Tier 1: Primary raw & cleaned full queries
        foreach ($q in $QueriesToTry) {
            if ($q -match '^\s*(.+?)\s+-\s+(.+?)\s*$') {
                $qArtist = $Matches[1].Trim()
                $qTitle  = $Matches[2].Trim()
                if ($qArtist.Length -ge 2 -and $qTitle.Length -ge 1 -and -not $SafeQueries.Contains($q)) {
                    $SafeQueries.Add($q)
                }
            }
        }

        # Tier 2: First-artist query (split on commas)
        foreach ($q in $QueriesToTry) {
            if ($q -match '^\s*(.+?)\s+-\s+(.+?)\s*$') {
                $qArtist = $Matches[1].Trim()
                $qTitle  = $Matches[2].Trim()
                if ($qArtist.Contains(",")) {
                    $FirstArtist = $qArtist.Substring(0, $qArtist.IndexOf(",")).Trim()
                    $SingleArtistQuery = "$FirstArtist - $qTitle"
                    if ($FirstArtist.Length -ge 2 -and -not $SafeQueries.Contains($SingleArtistQuery)) {
                        $SafeQueries.Add($SingleArtistQuery)
                    }
                }
            }
        }

        # Tier 3: Last Resort Shortener (for bloated names/uploaders like 'eminemuploader')
        foreach ($q in $QueriesToTry) {
            if ($q -match '^\s*(.+?)\s+-\s+(.+?)\s*$') {
                $qArtist = $Matches[1].Trim()
                $qTitle  = $Matches[2].Trim()
                if ($qArtist.Length -gt 9) {
                    $ShortArtist = $qArtist.Substring(0, 9).Trim()
                    $ShortQuery  = "$ShortArtist - $qTitle"
                    if ($ShortArtist.Length -ge 2 -and -not $SafeQueries.Contains($ShortQuery) -and -not $ShortQueries.Contains($ShortQuery)) {
                        $ShortQueries.Add($ShortQuery)
                    }
                }
            }
        }

        # Append shortened last-resort queries to the very end of the queue
        foreach ($sq in $ShortQueries) {
            if (-not $SafeQueries.Contains($sq)) {
                $SafeQueries.Add($sq)
            }
        }

        if ($SafeQueries.Count -eq 0) {
            Invoke-LogMsg "    [!] 🛑 SAFETY ABORT: Could not identify a reliable Artist for this track. Aborting API queries to prevent false song matches." $TrackIndex
            Invoke-LogMsg "---------------------------------------------" $TrackIndex
            return
        }

        Invoke-LogMsg "    [*] Precision queries validated: ($($SafeQueries -join ' | '))" $TrackIndex

        # STEP 3: MusicBrainz Instrumental Check
        Test-And-WaitCooldown $TrackIndex
        $MBPython = @"
import sys, urllib.request, json, urllib.parse, mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3, COMM, TLAN

query = sys.argv[1]
file_path = sys.argv[2]

def check_mb(q):
    try:
        url = "https://musicbrainz.org/ws/2/recording/?query=" + urllib.parse.quote(q) + "&fmt=json"
        req = urllib.request.Request(url, headers={'User-Agent': 'MusicPipelineLyricsEngine/1.0.0 ( filip@FILIPS_MICRO_PC )'})
        with urllib.request.urlopen(req, timeout=4) as response:
            data = json.loads(response.read().decode())
            if data.get('recordings'):
                top = data['recordings'][0]
                tags = [t.get('name', '').lower() for t in top.get('tags', [])]
                if 'instrumental' in tags: return True
                for rel in top.get('relations', []):
                    for attr in rel.get('attributes', []):
                        if attr.lower() == 'instrumental': return True
    except Exception: pass
    return False

if check_mb(query):
    audio = mutagen.File(file_path)
    if audio is not None:
        if isinstance(audio, FLAC):
            audio['language'] = 'zxx'
            audio['comment'] = 'Instrumental'
            audio.save()
        elif isinstance(audio, MP4):
            audio['\xa9cmt'] = ['Instrumental']
            audio.save()
        else:
            try: tags = ID3(file_path)
            except Exception: tags = ID3()
            tags.append(TLAN(encoding=3, text=['zxx']))
            tags.add(COMM(encoding=3, lang='eng', desc='Comment', text='Instrumental'))
            tags.save(file_path)
    sys.exit(1)
sys.exit(0)
"@

        $MBResult = Invoke-ThreadNativeProcess "python" @("-", $SafeQueries[0], $FilePath) -InputScript $MBPython

        if ($MBResult.IsThrottled) {
            Trigger-RateLimitCooldown "MusicBrainz query triggered HTTP 429 Throttle" $FilePath $LrcFile $TxtFile $TrackIndex
            Invoke-LogMsg "---------------------------------------------" $TrackIndex
            return
        }

        if ($MBResult.ExitCode -eq 1) {
            Invoke-LogMsg "    [+] Confirmed Instrumental via MusicBrainz! Tags stamped." $TrackIndex
            if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force -ErrorAction SilentlyContinue }
            if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
            Invoke-LogMsg "---------------------------------------------" $TrackIndex
            return
        }

        # STEP 4: Query Lyric APIs Across Safe Queries
        $TimedProviders = @("lrclib", "musixmatch", "netease", "megalobiz")
        $LrcFound        = $false

        foreach ($QueryTarget in $SafeQueries) {
            if ($LrcFound) { break }
            Invoke-LogMsg "    [*] Initiating provider sweep for target: '$QueryTarget'" $TrackIndex

            foreach ($Provider in $TimedProviders) {
                Test-And-WaitCooldown $TrackIndex

                Invoke-LogMsg "    [*] Querying source: [$Provider]" $TrackIndex
                $LrcArgs   = @("-m", "syncedlyrics", $QueryTarget, "-o", $LrcFile, "-p", $Provider)
                $LrcResult = Invoke-ThreadNativeProcess "python" $LrcArgs
                
                # Check for 429 rate limit or invalid throttle payload in file
                if ($LrcResult.IsThrottled -or (Test-IsRateLimitedFile $LrcFile)) {
                    Trigger-RateLimitCooldown "Provider [$Provider] returned 429 / Rate Limit" $FilePath $LrcFile $TxtFile $TrackIndex
                    $LrcFound = $false
                    Invoke-LogMsg "---------------------------------------------" $TrackIndex
                    return
                }

                if (Test-Path -LiteralPath $LrcFile) {
                    if (Test-IsSyncedLrc $LrcFile) {
                        Invoke-LogMsg "     [+] Valid timed .lrc successfully retrieved via [$Provider]!" $TrackIndex
                        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
                        $LrcFound = $true
                        break
                    } else {
                        if (-not (Test-Path -LiteralPath $TxtFile)) {
                            Invoke-LogMsg "     [!] [$Provider] returned unsynced/partial text. Staging as fallback..." $TrackIndex
                            Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
                        } else {
                            Remove-Item -LiteralPath $LrcFile -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
            }
        }
        
        if ($LrcFound) { 
            Invoke-LogMsg "---------------------------------------------" $TrackIndex
            return 
        }

        # STEP 5: Genius Fallback Scraper (Iterates Safe Queries)
        if (-not (Test-Path -LiteralPath $TxtFile) -and -not $HasUnsyncedLyrics) {
            foreach ($QueryTarget in $SafeQueries) {
                Test-And-WaitCooldown $TrackIndex

                Invoke-LogMsg "    [!] Timed matrix missing. Scraping Genius for target: '$QueryTarget'" $TrackIndex
                $FallbackArgs   = @("-m", "syncedlyrics", $QueryTarget, "-o", $LrcFile, "-p", "genius")
                $FallbackResult = Invoke-ThreadNativeProcess "python" $FallbackArgs

                if ($FallbackResult.IsThrottled -or (Test-IsRateLimitedFile $LrcFile)) {
                    Trigger-RateLimitCooldown "Genius Scraper returned 429 / Rate Limit" $FilePath $LrcFile $TxtFile $TrackIndex
                    Invoke-LogMsg "---------------------------------------------" $TrackIndex
                    return
                }

                if (Test-Path -LiteralPath $LrcFile) {
                    Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
                    break
                }
            }
        }

        # STEP 6: Untimed Tag Embedding
        if (Test-Path -LiteralPath $TxtFile) {
            Invoke-LogMsg "     [+] Plain text lyrics found. Embedding into container tags..." $TrackIndex
            
            $PythonCode = @"
import sys, os, mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3, USLT

txt_file = sys.argv[1]
file_path = sys.argv[2]

try:
    with open(txt_file, 'r', encoding='utf-8') as f:
        lyrics_text = f.read().strip()
    
    if lyrics_text:
        audio = mutagen.File(file_path)
        if audio is not None:
            if isinstance(audio, MP4):
                audio['\xa9lyr'] = [lyrics_text]
                audio.save()
            elif isinstance(audio, FLAC):
                audio['lyrics'] = lyrics_text
                audio.save()
            else:
                try: tags = ID3(file_path)
                except Exception: tags = ID3()
                tags.add(USLT(encoding=3, lang='eng', desc='Lyrics', text=lyrics_text))
                tags.save(file_path)
except Exception as e:
    sys.exit(1)
"@
            $EmbedResult = Invoke-ThreadNativeProcess "python" @("-", $TxtFile, $FilePath) -InputScript $PythonCode
        }
        
        if (Test-Path -LiteralPath $TxtFile) {
            Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue
        }

        Invoke-LogMsg "---------------------------------------------" $TrackIndex
    } finally {
        # Fix 4: Removed blocking manual GC sweeps
    }
} -ThrottleLimit $ThrottleLimit | Out-Null # Fix 2: Dump parallel pipeline output to $null to prevent RAM hoarding

# FINAL METRICS & TEARDOWN
$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Invoke-MainLogMsg "[METRIC] Total Engine Run Duration: $Elapsed"
Invoke-MainLogMsg "============================================="
Exit 0