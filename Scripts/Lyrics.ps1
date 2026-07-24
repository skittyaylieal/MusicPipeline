Param (
    [string]$BackupDir,
    [switch]$ForceFullRefresh,
    [int]$ThrottleLimit = 4
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$env:PYTHONIOENCODING = "utf-8"
try {
    Clear-Host
} catch {}

$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Main Thread Logger (used during initialization and summary)
function Invoke-MainLogMsg([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $Reset = "$ESC[0m"
    $ColorPrefix   = "$ESC[34m[$Timestamp] [LyricsEngine]$Reset"
    $FormattedLine = "$ColorPrefix $Text"
    
    Write-Host $FormattedLine
    if (Test-Path -LiteralPath $GlobalLogFile) {
        try { [System.IO.File]::AppendAllText($GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine)) } catch {}
    }
}

# Top-level Native Process Handler for dependency checks
function Invoke-MainNativeProcess ([string]$Executable, [string[]]$ArgumentList) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName               = $Executable
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true 
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    foreach ($arg in $ArgumentList) { $psi.ArgumentList.Add($arg) }
    
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.WaitForExit()
    return $proc.ExitCode
}

Invoke-MainLogMsg "============================================="
Invoke-MainLogMsg "    PowerShell Module: Headless Lyric Engine & Tag Embedder (Parallel)"
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

Invoke-MainLogMsg "[*] Initializing ultra-fast deep database scan across: $BackupDir"

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

Invoke-MainLogMsg "[+] Deep scan complete. Found $($AudioFiles.Count) total track(s) to verify."
Invoke-MainLogMsg "[*] Spawning parallel worker pool (Max Threads: $ThrottleLimit)..."
Invoke-MainLogMsg "---------------------------------------------"

# Structure tracks with sequential indices for thread color assignment
$TrackObjects = [System.Collections.Generic.List[PSCustomObject]]::new()
for ($i = 0; $i -lt $AudioFiles.Count; $i++) {
    $TrackObjects.Add([PSCustomObject]@{
        Index = $i + 1
        Path  = $AudioFiles[$i]
    })
}

$TotalTracks = $AudioFiles.Count

# =========================================================================
# PARALLEL WORKER ENGINE
# =========================================================================
$TrackObjects | ForEach-Object -Parallel {
    $TrackIndex       = $_.Index
    $FilePath         = $_.Path
    $TotalCount       = $using:TotalTracks
    $GlobalLogFile    = $using:GlobalLogFile
    $ForceFullRefresh = $using:ForceFullRefresh
    $ThreadGuid       = [System.Guid]::NewGuid().Guid

    # Thread-Safe Color-Coded Logger Matrix (12-Color Expanded Palette)
    function Invoke-LogMsg([string]$Text, [int]$Idx) {
        if ([string]::IsNullOrWhiteSpace($Text)) { return }
        $Timestamp = (Get-Date).ToString("HH:mm:ss")
        $ESC       = [char]27
        $Reset     = "$ESC[0m"
        
        # Expanded 256-Color Palette based on Download.ps1
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
        
        if ($Text -match '🛑|THREAD DEBUG ALERT|error:|ERROR:|Usage:|\[!\]') {
            $ColorCode = "1;31" # Bold Red override for errors
        }

        $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [Track $Idx]$Reset"
        $FormattedLine = "$ColorPrefix $Text"
        
        Write-Output $FormattedLine
        
        if (Test-Path -LiteralPath $using:GlobalLogFile) {
            $RetryCount = 0
            $MaxRetries = 15
            $Success    = $false
            while (-not $Success -and $RetryCount -lt $MaxRetries) {
                try {
                    [System.IO.File]::AppendAllText($using:GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine))
                    $Success = $true
                } catch [System.IO.IOException] {
                    $RetryCount++
                    [System.Threading.Thread]::Sleep(50)
                } catch {
                    break
                }
            }
        }
    }

    # Thread-isolated helper: Check .lrc synced timestamps
    function Test-IsSyncedLrc ([string]$File) {
        if (-not (Test-Path -LiteralPath $File)) { return $false }
        try {
            $Content = [System.IO.File]::ReadAllText($File)
            return ($Content -match '\[\d{1,3}:\d{2}')
        } catch {
            return $false
        }
    }

    # Thread-isolated helper: RAM & Handle Snapshot
    function Get-MemorySnapshot {
        $Proc           = [System.Diagnostics.Process]::GetCurrentProcess()
        $WorkingSetMB   = [math]::Round($Proc.WorkingSet64 / 1MB, 2)
        $PrivateBytesMB = [math]::Round($Proc.PrivateMemorySize64 / 1MB, 2)
        $Handles        = $Proc.HandleCount
        return "RAM (WS): ${WorkingSetMB}MB | Private: ${PrivateBytesMB}MB | Handles: $Handles"
    }

    # Thread-isolated process executor with unbuffered STDOUT/STDERR capture
    function Invoke-ThreadNativeProcess ([string]$Executable, [string[]]$ArgumentList, [switch]$CaptureOutput) {
        $psi = [System.Diagnostics.ProcessStartInfo]::new()
        $psi.FileName               = $Executable
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true 
        $psi.RedirectStandardInput  = $true 
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
        $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"

        foreach ($arg in $ArgumentList) { $psi.ArgumentList.Add($arg) }

        $proc = $null
        $stdoutBuilder = [System.Text.StringBuilder]::new()

        try {
            $proc = [System.Diagnostics.Process]::Start($psi)
            $proc.StandardInput.Close()

            while (-not $proc.HasExited) {
                [System.Threading.Thread]::Sleep(20)
                while (-not $proc.StandardOutput.EndOfStream) {
                    $Line = $proc.StandardOutput.ReadLine()
                    if ($Line) { 
                        if ($CaptureOutput) { [void]$stdoutBuilder.AppendLine($Line) }
                        else { Invoke-LogMsg "    [Python STDOUT] $Line" $using:TrackIndex }
                    }
                }
                while (-not $proc.StandardError.EndOfStream) {
                    $ErrLine = $proc.StandardError.ReadLine()
                    if ($ErrLine) { Invoke-LogMsg "    [Python STDERR] $ErrLine" $using:TrackIndex }
                }
            }

            while (-not $proc.StandardOutput.EndOfStream) {
                $Line = $proc.StandardOutput.ReadLine()
                if ($Line) { 
                    if ($CaptureOutput) { [void]$stdoutBuilder.AppendLine($Line) }
                    else { Invoke-LogMsg "    [Python STDOUT] $Line" $using:TrackIndex }
                }
            }
            while (-not $proc.StandardError.EndOfStream) {
                $ErrLine = $proc.StandardError.ReadLine()
                if ($ErrLine) { Invoke-LogMsg "    [Python STDERR] $ErrLine" $using:TrackIndex }
            }

            if ($CaptureOutput) {
                $OutText = $stdoutBuilder.ToString()
                $stdoutBuilder.Clear()
                return [PSCustomObject]@{ ExitCode = $proc.ExitCode; Output = $OutText }
            }
            return $proc.ExitCode
        } catch {
            Invoke-LogMsg "[🛑 PROCESS PANIC] Execution failure: $_" $using:TrackIndex
            if ($CaptureOutput) { return [PSCustomObject]@{ ExitCode = -1; Output = "" } }
            return -1
        } finally {
            if ($null -ne $proc) { $proc.Dispose() }
        }
    }

    # ---------------------------------------------------------------------
    # TRACK PROCESSING LOGIC
    # ---------------------------------------------------------------------
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
            Invoke-LogMsg "    [!] Existing .lrc lacks timestamps (unsynced text). Staging for tag embedding." $TrackIndex
            Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
        }
    }

    # STEP 1: Extract Metadata via Isolated GUID Temp Python Script
    $TmpPyCheck = Join-Path $env:TEMP "mutagen_extract_$ThreadGuid.py"
    $PreCheckPython = @"
import mutagen, sys, json
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3

artist = ""
title = ""
is_inst = False
has_lyrics = False

try:
    audio = mutagen.File(r"""$FilePath""")
    if audio is not None:
        if isinstance(audio, FLAC):
            artist = audio.get('artist', [''])[0]
            title = audio.get('title', [''])[0]
            lang = audio.get('language', [''])[0].lower()
            comment = audio.get('comment', [''])[0].lower()
            if lang == 'zxx' or 'instrumental' in comment: is_inst = True
            if 'lyrics' in audio and audio['lyrics']: has_lyrics = True

        elif isinstance(audio, MP4):
            artist = audio.get('\xa9ART', [''])[0] if '\xa9ART' in audio else ''
            title = audio.get('\xa9nam', [''])[0] if '\xa9nam' in audio else ''
            comment = audio.get('\xa9cmt', [''])[0].lower() if '\xa9cmt' in audio else ''
            if 'instrumental' in comment: is_inst = True
            if '\xa9lyr' in audio and audio['\xa9lyr']: has_lyrics = True

        elif isinstance(audio, ID3) or (audio.tags and hasattr(audio.tags, 'getall')):
            if audio.tags.getall('TPE1'): artist = audio.tags.getall('TPE1')[0].text[0]
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
    $PreCheckPython | Out-File $TmpPyCheck -Encoding utf8NoBOM
    
    $MetaResult  = Invoke-ThreadNativeProcess "python" @($TmpPyCheck) -CaptureOutput
    $MetaJsonRaw = $MetaResult.Output
    Remove-Item $TmpPyCheck -Force -ErrorAction SilentlyContinue

    $Meta = $null
    try { $Meta = $MetaJsonRaw | ConvertFrom-Json } catch {}

    if (-not $ForceFullRefresh -and $Meta.is_inst) {
        Invoke-LogMsg "    [-] Track explicitly marked as Instrumental. Skipping API engine." $TrackIndex
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
        Invoke-LogMsg "---------------------------------------------" $TrackIndex
        return
    }

    $HasUnsyncedLyrics = if ($ForceFullRefresh) { $false } else { [bool]$Meta.has_lyrics }

    # STEP 2: Construct Search Target
    $ArtistTag = $Meta.artist
    $TitleTag  = $Meta.title
    
    if (-not [string]::IsNullOrWhiteSpace($ArtistTag) -and -not [string]::IsNullOrWhiteSpace($TitleTag)) {
        $SearchQuery = "$ArtistTag - $TitleTag"
    } else {
        $SearchQuery = $FileInfo.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    }

    Invoke-LogMsg "    [*] Precision query formulated: '$SearchQuery'" $TrackIndex

    # STEP 3: MusicBrainz Instrumental Check
    Invoke-LogMsg "    [*] Querying MusicBrainz for Instrumental classification..." $TrackIndex
    $TmpPyInstCheck = Join-Path $env:TEMP "musicbrainz_check_$ThreadGuid.py"
    $MBPython = @"
import sys, urllib.request, json, urllib.parse, mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3, COMM, TLAN

def check_mb(query):
    try:
        url = "https://musicbrainz.org/ws/2/recording/?query=" + urllib.parse.quote(query) + "&fmt=json"
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

if check_mb(r"""$SearchQuery"""):
    audio = mutagen.File(r"""$FilePath""")
    if audio is not None:
        if isinstance(audio, FLAC):
            audio['language'] = 'zxx'
            audio['comment'] = 'Instrumental'
            audio.save()
        elif isinstance(audio, MP4):
            audio['\xa9cmt'] = ['Instrumental']
            audio.save()
        else:
            try: tags = ID3(r"""$FilePath""")
            except Exception: tags = ID3()
            tags.append(TLAN(encoding=3, text=['zxx']))
            tags.add(COMM(encoding=3, lang='eng', desc='Comment', text='Instrumental'))
            tags.save(r"""$FilePath""")
    sys.exit(1)
sys.exit(0)
"@
    $MBPython | Out-File $TmpPyInstCheck -Encoding utf8NoBOM
    $IsInstrumentalExit = Invoke-ThreadNativeProcess "python" @($TmpPyInstCheck)
    Remove-Item $TmpPyInstCheck -Force -ErrorAction SilentlyContinue

    if ($IsInstrumentalExit -eq 1) {
        Invoke-LogMsg "    [+] Confirmed Instrumental via MusicBrainz! Tags stamped." $TrackIndex
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
        Invoke-LogMsg "---------------------------------------------" $TrackIndex
        return
    }

    # STEP 4: Query Lyric APIs
    Invoke-LogMsg "    [*] Querying timeline sync index sequence..." $TrackIndex
    $TimedProviders = @("lrclib", "musixmatch", "netease", "megalobiz")
    $LrcFound = $false

    foreach ($Provider in $TimedProviders) {
        Invoke-LogMsg "    [*] Querying matrix source: [$Provider]" $TrackIndex
        $LrcArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "-p", $Provider)
        $LrcExitCode = Invoke-ThreadNativeProcess "python" $LrcArgs
        
        if (Test-Path -LiteralPath $LrcFile) {
            if (Test-IsSyncedLrc $LrcFile) {
                Invoke-LogMsg "     [+] Timed .lrc timeline successfully committed via [$Provider]." $TrackIndex
                if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
                $LrcFound = $true
                break
            } else {
                if (-not (Test-Path -LiteralPath $TxtFile)) {
                    Invoke-LogMsg "     [!] [$Provider] returned unsynced text. Staging as fallback..." $TrackIndex
                    Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
                } else {
                    Remove-Item -LiteralPath $LrcFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    if ($LrcFound) { 
        Invoke-LogMsg "---------------------------------------------" $TrackIndex
        return 
    }

    # STEP 5: Genius Fallback Scraper
    if (-not (Test-Path -LiteralPath $TxtFile) -and -not $HasUnsyncedLyrics) {
        Invoke-LogMsg "    [!] Timed matrix missing. Scraping Genius Engine for untimed lyrics..." $TrackIndex
        $FallbackArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "-p", "genius")
        $FallbackExitCode = Invoke-ThreadNativeProcess "python" $FallbackArgs

        if (Test-Path -LiteralPath $LrcFile) {
            Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
        }
    }

    # STEP 6: Untimed Tag Embedding
    if (Test-Path -LiteralPath $TxtFile) {
        Invoke-LogMsg "     [+] Plain text lyrics found. Embedding into container tags..." $TrackIndex
        
        $TmpPyEmbed = Join-Path $env:TEMP "mutagen_embed_$ThreadGuid.py"
        $PythonCode = @"
import os, mutagen, sys
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3, USLT
try:
    with open(r"""$TxtFile""", 'r', encoding='utf-8') as f: lyrics_text = f.read().strip()
    
    if lyrics_text:
        audio = mutagen.File(r"""$FilePath""")
        if audio is not None:
            if isinstance(audio, MP4):
                audio['\xa9lyr'] = [lyrics_text]
                audio.save()
            elif isinstance(audio, FLAC):
                audio['lyrics'] = lyrics_text
                audio.save()
            else:
                try: tags = ID3(r"""$FilePath""")
                except Exception: tags = ID3()
                tags.add(USLT(encoding=3, lang='eng', desc='Lyrics', text=lyrics_text))
                tags.save(r"""$FilePath""")
except Exception as e: 
    sys.exit(1)
"@
        $PythonCode | Out-File $TmpPyEmbed -Encoding utf8NoBOM
        $EmbedExitCode = Invoke-ThreadNativeProcess "python" @($TmpPyEmbed)
        Remove-Item $TmpPyEmbed -Force -ErrorAction SilentlyContinue
    }
    
    if (Test-Path -LiteralPath $TxtFile) {
        Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue
    }

    Invoke-LogMsg "---------------------------------------------" $TrackIndex
} -ThrottleLimit $ThrottleLimit

# =========================================================================
# FINAL METRICS & TEARDOWN
# =========================================================================
$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Invoke-MainLogMsg "[METRIC] Total Engine Run Duration: $Elapsed"
Invoke-MainLogMsg "============================================="
Exit 0