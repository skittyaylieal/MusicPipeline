Param (
    [string]$BackupDir,
    [switch]$ForceFullRefresh
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$env:PYTHONIOENCODING = "utf-8"
try {
    Clear-Host
} catch {}

$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"

# Unified Thread-Safe Logger matching the Downloader Engine
function Invoke-LogMsg([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $Reset = "$ESC[0m"
    
    $ColorCode = "34" # Blue
    
    if ($Text -match '🛑|error:|ERROR:|Usage:|\[!\]') {
        $ColorCode = "1;31" # Bold Red
    } elseif ($Text -match '\[\+\]') {
        $ColorCode = "32" # Green for successful writes/finds
    }

    $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [LyricsEngine]$Reset"
    $FormattedLine = "$ColorPrefix $Text"
    
    Write-Host $FormattedLine
    
    if (Test-Path -LiteralPath $GlobalLogFile) {
        $RetryCount = 0
        $MaxRetries = 15
        $Success    = $false
        
        while (-not $Success -and $RetryCount -lt $MaxRetries) {
            try {
                [System.IO.File]::AppendAllText($GlobalLogFile, ($FormattedLine + [System.Environment]::NewLine))
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

# Helper to verify if an .lrc file contains valid synced timestamps [mm:ss]
function Test-IsSyncedLrc ([string]$FilePath) {
    if (-not (Test-Path -LiteralPath $FilePath)) { return $false }
    try {
        $Content = [System.IO.File]::ReadAllText($FilePath)
        return ($Content -match '\[\d{1,3}:\d{2}')
    } catch {
        return $false
    }
}

# Diagnostic Helper: Captures current PowerShell process RAM & OS handle usage
function Get-MemorySnapshot {
    $Proc = [System.Diagnostics.Process]::GetCurrentProcess()
    $WorkingSetMB  = [math]::Round($Proc.WorkingSet64 / 1MB, 2)
    $PrivateBytesMB = [math]::Round($Proc.PrivateMemorySize64 / 1MB, 2)
    $Handles        = $Proc.HandleCount
    return "RAM (WS): ${WorkingSetMB}MB | RAM (Private): ${PrivateBytesMB}MB | Handles: $Handles"
}

Invoke-LogMsg "============================================="
Invoke-LogMsg "    PowerShell Module: Headless Lyric Engine & Tag Embedder"
Invoke-LogMsg "============================================="

# Leak-Free Native Process Execution Handler
function Invoke-NativeProcess ([string]$Executable, [string[]]$ArgumentList, [switch]$CaptureOutput) {
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
                    else { Invoke-LogMsg "    [Python STDOUT] $Line" }
                }
            }
            while (-not $proc.StandardError.EndOfStream) {
                $ErrLine = $proc.StandardError.ReadLine()
                if ($ErrLine) { Invoke-LogMsg "    [Python STDERR] $ErrLine" }
            }
        }

        while (-not $proc.StandardOutput.EndOfStream) {
            $Line = $proc.StandardOutput.ReadLine()
            if ($Line) { 
                if ($CaptureOutput) { [void]$stdoutBuilder.AppendLine($Line) }
                else { Invoke-LogMsg "    [Python STDOUT] $Line" }
            }
        }
        while (-not $proc.StandardError.EndOfStream) {
            $ErrLine = $proc.StandardError.ReadLine()
            if ($ErrLine) { Invoke-LogMsg "    [Python STDERR] $ErrLine" }
        }

        if ($CaptureOutput) {
            $OutText = $stdoutBuilder.ToString()
            $stdoutBuilder.Clear()
            return [PSCustomObject]@{ ExitCode = $proc.ExitCode; Output = $OutText }
        }
        return $proc.ExitCode
    } catch {
        Invoke-LogMsg "[🛑 PROCESS PANIC] Failed execution framework: $_"
        if ($CaptureOutput) { return [PSCustomObject]@{ ExitCode = -1; Output = "" } }
        return -1
    } finally {
        if ($null -ne $proc) { $proc.Dispose() }
    }
}

Invoke-LogMsg "[*] Verifying background Python dependencies..."
$PipExit = Invoke-NativeProcess "pip" @("install", "--upgrade", "syncedlyrics", "mutagen", "--quiet")
Invoke-LogMsg "[*] Pip verification routine complete (Exit Code: $PipExit)."

if (-not (Test-Path -LiteralPath $BackupDir -PathType Container)) {
    Invoke-LogMsg "[ERROR] Target backup directory could not be found: $BackupDir"
    Exit 1
}

if ($ForceFullRefresh) {
    Invoke-LogMsg "🧹 [CLEAN SWEEP REFRESH] Forcing deep query over every track. Stale local .lrc files will be purged."
}

Invoke-LogMsg "[*] Initializing ultra-fast deep database scan across: $BackupDir"

try {
    $AllFiles = [System.IO.Directory]::EnumerateFiles($BackupDir, "*.*", [System.IO.SearchOption]::AllDirectories)
} catch {
    Invoke-LogMsg "[ERROR] Failed to initialize deep directory enumeration: $_"
    Exit 1
}

$AudioFiles = [System.Collections.Generic.List[string]]::new()
foreach ($File in $AllFiles) {
    if ($File -match '\.(flac|mp3|m4a)$') {
        $AudioFiles.Add($File)
    }
}

if ($AudioFiles.Count -eq 0) {
    Invoke-LogMsg "[+] No audio tracks found across the system array."
    $MetricStopwatch.Stop()
    Invoke-LogMsg "[METRIC] 00:00:00"
    Exit 0
}

Invoke-LogMsg "[+] Deep scan complete. Found $($AudioFiles.Count) total track(s) to verify."
Invoke-LogMsg "---------------------------------------------"

$ScannedCount = 0
foreach ($FilePath in $AudioFiles) {
    $ScannedCount++
    
    # Accelerated Garbage Collection Sweep (Runs every 10 tracks with memory delta reporting)
    if ($ScannedCount % 10 -eq 0) {
        $RamBefore = [math]::Round(([System.Diagnostics.Process]::GetCurrentProcess().WorkingSet64 / 1MB), 2)
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()
        [System.GC]::Collect() # Double-pass to clean lingering handles
        $RamAfter = [math]::Round(([System.Diagnostics.Process]::GetCurrentProcess().WorkingSet64 / 1MB), 2)
        $Freed    = [math]::Round($RamBefore - $RamAfter, 2)
        
        Invoke-LogMsg "🧹 [GC SWEEP] Track $ScannedCount | Before: ${RamBefore}MB -> After: ${RamAfter}MB (Freed: ${Freed}MB) | $(Get-MemorySnapshot)"
    }

    $FileInfo = [System.IO.FileInfo]::new($FilePath)
    
    Invoke-LogMsg "[*] [$ScannedCount/$($AudioFiles.Count)] Evaluating: $($FileInfo.FullName)"
    Invoke-LogMsg "    🔍 [MEM CHECK] $(Get-MemorySnapshot)"
    
    $DirName = $FileInfo.DirectoryName
    $LrcFile = Join-Path $DirName "$($FileInfo.BaseName).lrc"
    $TxtFile = Join-Path $DirName "$($FileInfo.BaseName).txt"
    
    # PURGE CHECK: If forcing a full refresh, wipe existing .lrc to guarantee clean-slate fetching
    if ($ForceFullRefresh) {
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
    }

    # EXISTING .LRC VALIDATION: Ensure existing .lrc file actually has timed timestamps
    if (-not $ForceFullRefresh -and (Test-Path -LiteralPath $LrcFile)) {
        if (Test-IsSyncedLrc $LrcFile) {
            Invoke-LogMsg "    [-] Valid synced .lrc companion already exists on disk. Skipping."
            Invoke-LogMsg "---------------------------------------------"
            continue
        } else {
            Invoke-LogMsg "    [!] Existing .lrc lacks timestamps (unsynced plain text). Staging for tag embedding."
            Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
        }
    }

    # STEP 1: Extract Artist + Title Metadata & Check Existing Instrumental/Lyric Tags
    $TmpPyCheck = Join-Path $env:TEMP "mutagen_extract.py"
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
    
    $MetaResult = Invoke-NativeProcess "python" @($TmpPyCheck) -CaptureOutput
    $MetaJsonRaw = $MetaResult.Output
    Remove-Item $TmpPyCheck -Force -ErrorAction SilentlyContinue

    $Meta = $null
    try { $Meta = $MetaJsonRaw | ConvertFrom-Json } catch {}

    if (-not $ForceFullRefresh -and $Meta.is_inst) {
        Invoke-LogMsg "    [-] Track explicitly marked as Instrumental. Skipping API engine."
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
        Invoke-LogMsg "---------------------------------------------"
        continue
    }

    $HasUnsyncedLyrics = if ($ForceFullRefresh) { $false } else { [bool]$Meta.has_lyrics }

    # STEP 2: Construct Precision Search Target (Artist + Title)
    $ArtistTag = $Meta.artist
    $TitleTag  = $Meta.title
    
    if (-not [string]::IsNullOrWhiteSpace($ArtistTag) -and -not [string]::IsNullOrWhiteSpace($TitleTag)) {
        $SearchQuery = "$ArtistTag - $TitleTag"
    } else {
        $SearchQuery = $FileInfo.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    }

    Invoke-LogMsg "    [*] Formulated precision search query: '$SearchQuery'"

    # STEP 3: Check MusicBrainz FIRST
    Invoke-LogMsg "    [*] Running MusicBrainz validation for explicit Instrumental classification..."
    $TmpPyInstCheck = Join-Path $env:TEMP "musicbrainz_check.py"
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
    $IsInstrumentalExit = Invoke-NativeProcess "python" @($TmpPyInstCheck)
    Remove-Item $TmpPyInstCheck -Force -ErrorAction SilentlyContinue

    if ($IsInstrumentalExit -eq 1) {
        Invoke-LogMsg "    [+] Confirmed Instrumental via MusicBrainz! Tags stamped."
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force -ErrorAction SilentlyContinue }
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
        Invoke-LogMsg "---------------------------------------------"
        continue
    }

    # STEP 4: Query Lyric APIs for Real Synced Timelines
    Invoke-LogMsg "    [*] Launching global timeline sync index query sequence..."
    $TimedProviders = @("lrclib", "musixmatch", "netease", "megalobiz")
    $LrcFound = $false

    foreach ($Provider in $TimedProviders) {
        Invoke-LogMsg "    [*] Querying matrix source: [$Provider]"
        $LrcArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "-p", $Provider)
        $LrcExitCode = Invoke-NativeProcess "python" $LrcArgs
        
        if (Test-Path -LiteralPath $LrcFile) {
            if (Test-IsSyncedLrc $LrcFile) {
                Invoke-LogMsg "     [+] Pristine timed timelines (.lrc) successfully committed via [$Provider]."
                # Synced lyrics win! Trash any previously staged unsynced fallback
                if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue }
                $LrcFound = $true
                break
            } else {
                # Unsynced plain text returned before Genius
                if (-not (Test-Path -LiteralPath $TxtFile)) {
                    Invoke-LogMsg "     [!] Provider [$Provider] returned unsynced text. Staging as fallback while continuing search for synced lyrics..."
                    Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
                } else {
                    Invoke-LogMsg "     [!] Provider [$Provider] returned unsynced text. Discarding (already have a staged fallback)."
                    Remove-Item -LiteralPath $LrcFile -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
    
    if ($LrcFound) { 
        Invoke-LogMsg "---------------------------------------------"
        continue 
    }

    # STEP 5: Untimed Fallback (Genius Scraper & Plain Text Embedding)
    # Only query Genius if we don't ALREADY have staged unsynced text from an earlier provider
    if (-not (Test-Path -LiteralPath $TxtFile) -and -not $HasUnsyncedLyrics) {
        Invoke-LogMsg "    [!] Timed matrix missing and no earlier fallback staged. Scraping Genius Engine for untimed lyrics..."
        $FallbackArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "-p", "genius")
        $FallbackExitCode = Invoke-NativeProcess "python" $FallbackArgs

        if (Test-Path -LiteralPath $LrcFile) {
            Move-Item -LiteralPath $LrcFile -Destination $TxtFile -Force
        }
    }

    if (Test-Path -LiteralPath $TxtFile) {
        Invoke-LogMsg "     [+] Plain text lyrics found. Embedding directly into container tags for Samsung Music..."
        
        $TmpPyEmbed = Join-Path $env:TEMP "mutagen_embed.py"
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
        $EmbedExitCode = Invoke-NativeProcess "python" @($TmpPyEmbed)
        Remove-Item $TmpPyEmbed -Force -ErrorAction SilentlyContinue
    }
    
    # GUARANTEED CLEANUP: Ensure .txt is NEVER left on disk after processing
    if (Test-Path -LiteralPath $TxtFile) {
        Remove-Item -LiteralPath $TxtFile -Force -ErrorAction SilentlyContinue
    }

    # Scope Variable Purge to Prevent PowerShell Object Retention Leaks
    $PreCheckPython = $null
    $MetaResult     = $null
    $MetaJsonRaw    = $null
    $Meta           = $null
    $MBPython       = $null
    $PythonCode     = $null

    Invoke-LogMsg "---------------------------------------------"
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Invoke-LogMsg "[METRIC] Total Engine Run Duration: $Elapsed"
Invoke-LogMsg "============================================="
Exit 0