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

# Unified Thread-Safe Logger matching the Downloader Engine (Fixed local scope tracking)
function Invoke-LogMsg([string]$Text) {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $Reset = "$ESC[0m"
    
    # Base configuration color for Lyric Engine (Cyan-Blue styling)
    $ColorCode = "34" # Blue
    
    if ($Text -match '🛑|error:|ERROR:|Usage:|\[!\]') {
        $ColorCode = "1;31" # Bold Red
    } elseif ($Text -match '\[\+\]') {
        $ColorCode = "32" # Green for successful writes/finds
    }

    $ColorPrefix   = "$ESC[${ColorCode}m[$Timestamp] [LyricsEngine]$Reset"
    $FormattedLine = "$ColorPrefix $Text"
    
    # Write-Host bypasses standard capture to prevent double-logging
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

Invoke-LogMsg "============================================="
Invoke-LogMsg "    PowerShell Module: Headless Lyric Engine & Tag Embedder"
Invoke-LogMsg "============================================="

# Real-Time Execution Handler for tracking sub-Python tasks (Fixed asynchronous stream evaluation)
function Invoke-NativeProcess ([string]$Executable, [string[]]$ArgumentList) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName                = $Executable
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true 
    $psi.RedirectStandardInput  = $true 
    $psi.UseShellExecute        = $false
    $psi.CreateNoWindow         = $true
    
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8
    
    $psi.EnvironmentVariables["PYTHONUNBUFFERED"] = "1"

    foreach ($arg in $ArgumentList) { $psi.ArgumentList.Add($arg) }

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $proc.StandardInput.Close()

        while (-not $proc.HasExited) {
            [System.Threading.Thread]::Sleep(50)
            while (-not $proc.StandardOutput.EndOfStream) {
                $Line = $proc.StandardOutput.ReadLine()
                if ($Line) { Invoke-LogMsg "    [Python STDOUT] $Line" }
            }
            while (-not $proc.StandardError.EndOfStream) {
                $ErrLine = $proc.StandardError.ReadLine()
                if ($ErrLine) { Invoke-LogMsg "    [Python STDERR] $ErrLine" }
            }
        }

        while (-not $proc.StandardOutput.EndOfStream) {
            $Line = $proc.StandardOutput.ReadLine()
            if ($Line) { Invoke-LogMsg "    [Python STDOUT] $Line" }
        }
        while (-not $proc.StandardError.EndOfStream) {
            $ErrLine = $proc.StandardError.ReadLine()
            if ($ErrLine) { Invoke-LogMsg "    [Python STDERR] $ErrLine" }
        }

        return $proc.ExitCode
    } catch {
        Invoke-LogMsg "[🛑 PROCESS PANIC] Failed execution framework: $_"
        return -1
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
    Invoke-LogMsg "🧹 [CLEAN SWEEP REFRESH] Forcing deep query over every track. Local skips will be bypassed."
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
    $FileInfo = [System.IO.FileInfo]::new($FilePath)
    
    Invoke-LogMsg "[*] [$ScannedCount/$($AudioFiles.Count)] Evaluating: $($FileInfo.FullName)"
    
    $DirName = $FileInfo.DirectoryName
    $LrcFile = Join-Path $DirName "$($FileInfo.BaseName).lrc"
    $TxtFile = Join-Path $DirName "$($FileInfo.BaseName).txt"
    
    # Modified: If ForceFullRefresh is active, skip checking for existing files on disk
    if (-not $ForceFullRefresh -and (Test-Path -LiteralPath $LrcFile)) {
         Invoke-LogMsg "    [-] Synced .lrc companion already exists on disk. Skipping API matching engine."
         Invoke-LogMsg "---------------------------------------------"
         continue
    }

    # Python Native Metadata Verification via Real-time Stream (With ID3 & Instrumental Support)
    Invoke-LogMsg "    [*] Querying embedded container tags for unsynced lyrics & instrumental flags..."
    $TmpPyCheck = Join-Path $env:TEMP "mutagen_check.py"
    # FIXED: Swapped r'$FilePath' to r"""$FilePath""" to prevent name breakout
    $PreCheckPython = @"
import mutagen, sys
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3
try:
    audio = mutagen.File(r"""$FilePath""")
    if audio is not None:
        # 1. Look for explicit automatic or manual Instrumental markings
        if isinstance(audio, FLAC):
            lang = audio.get('language', [''])[0].lower()
            comment = audio.get('comment', [''])[0].lower()
            if lang == 'zxx' or 'instrumental' in comment: sys.exit(3)
        elif isinstance(audio, MP4):
            comment = audio.get('\xa9cmt', [''])[0].lower() if '\xa9cmt' in audio else ''
            if 'instrumental' in comment: sys.exit(3)
        elif isinstance(audio, ID3) or (audio.tags and hasattr(audio.tags, 'getall')):
            if audio.tags.getall('TLAN') and audio.tags.getall('TLAN')[0].text[0].lower() == 'zxx': sys.exit(3)
            for comm in audio.tags.getall('COMM'):
                if 'instrumental' in comm.text.lower(): sys.exit(3)

        # 2. Check for existing unsynced lyrics
        if isinstance(audio, MP4) and '\xa9lyr' in audio and audio['\xa9lyr']: sys.exit(2)
        elif isinstance(audio, FLAC) and 'lyrics' in audio and audio['lyrics']: sys.exit(2)
        elif isinstance(audio, ID3) or (audio.tags and hasattr(audio.tags, 'getall')):
            for tag in audio.tags.getall('USLT'):
                if tag.text: sys.exit(2)
    sys.exit(0)
except Exception as e:
    print(f"Metadata scan failure: {e}")
    sys.exit(0)
"@
    $PreCheckPython | Out-File $TmpPyCheck -Encoding utf8NoBOM
    
    $CheckExitCode = Invoke-NativeProcess "python" @($TmpPyCheck)
    Remove-Item $TmpPyCheck -Force
    
    # Modified: If ForceFullRefresh is active, ignore pre-existing instrumental tags
    if (-not $ForceFullRefresh -and $CheckExitCode -eq 3) {
        Invoke-LogMsg "    [-] Track explicitly marked as Instrumental. Skipping API matching engine."
        Invoke-LogMsg "---------------------------------------------"
        continue
    }

    # Modified: If ForceFullRefresh is active, treat unsynced state as false to force re-fetch
    $HasUnsyncedLyrics = if ($ForceFullRefresh) { $false } else { ($CheckExitCode -eq 2) }
    Invoke-LogMsg "    [*] Internal metadata analysis complete. Unsynced state present: $HasUnsyncedLyrics"

    $SearchQuery = $FileInfo.BaseName -replace '^\d+[\s-]*', '' -replace '\s+', ' '
    Invoke-LogMsg "    [*] Formulated indexing search target string: '$SearchQuery'"
    Invoke-LogMsg "    [*] Launching global timeline sync index query sequence..."
    
    # Quality prioritized sequence definition
    $TimedProviders = @("lrclib", "musixmatch", "netease", "megalobiz")
    $LrcFound = $false

    foreach ($Provider in $TimedProviders) {
        Invoke-LogMsg "    [*] Querying matrix source: [$Provider]"
        $LrcArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "-p", $Provider)
        $LrcExitCode = Invoke-NativeProcess "python" $LrcArgs
        
        if (Test-Path -LiteralPath $LrcFile) {
            Invoke-LogMsg "     [+] Pristine timed timelines (.lrc) successfully committed via [$Provider]."
            Invoke-LogMsg "---------------------------------------------"
            if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force }
            $LrcFound = $true
            break
        }
    }
    
    if ($LrcFound) { continue }

    if ($HasUnsyncedLyrics) {
        Invoke-LogMsg "    [-] Timed tracking missing, but audio container holds embedded plain text. Aborting search array."
        Invoke-LogMsg "---------------------------------------------"
        continue
    }

    # Absolute quality fallback routine: Sync missed, drop into Genius tag compilation
    Invoke-LogMsg "    [!] Timed matrix missing. Fallback initiated: Scraping Genius Engine via Native Subprocess..."
    $FallbackArgs = @("-m", "syncedlyrics", $SearchQuery, "-o", $LrcFile, "-p", "genius")
    $FallbackExitCode = Invoke-NativeProcess "python" $FallbackArgs

    # Fix logic flow matching your rule: syncedlyrics saves genius scrapes as .txt if it's plain lyrics.
    if (Test-Path -LiteralPath $LrcFile) {
        Rename-Item -LiteralPath $LrcFile -NewName "$($FileInfo.BaseName).txt" -Force
    }

    if (Test-Path -LiteralPath $TxtFile) {
        Invoke-LogMsg "     [+] Flat text lyrics returned by fallback. Constructing Mutagen database encoder..."
        
        $TmpPyEmbed = Join-Path $env:TEMP "mutagen_embed.py"
        # FIXED: Swapped r'$TxtFile' and r'$FilePath' variables to triple double-quotes r"""..."""
        $PythonCode = @"
import os, mutagen, sys
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3, USLT
try:
    with open(r"""$TxtFile""", 'r', encoding='utf-8') as f: lyrics_text = f.read()
    
    audio = mutagen.File(r"""$FilePath""")
    if audio is not None:
        if isinstance(audio, MP4):
            audio['\xa9lyr'] = [lyrics_text]
            audio.save()
            print('    [+] Unsynced text tag written to M4A container.')
        elif isinstance(audio, FLAC):
            audio['lyrics'] = lyrics_text
            audio.save()
            print('    [+] Unsynced text tag written to FLAC container.')
        else:
            try:
                tags = ID3(r"""$FilePath""")
            except Exception:
                tags = ID3()
            tags.add(USLT(encoding=3, lang='eng', desc='Lyrics', text=lyrics_text))
            tags.save(r"""$FilePath""")
            print('    [+] Unsynced USLT tag written to MP3 container.')
            
    if os.path.exists(r"""$TxtFile"""): os.remove(r"""$TxtFile""")
except Exception as e: 
    print(f'    [!] Mutagen structural error: {e}')
    sys.exit(1)
"@
        $PythonCode | Out-File $TmpPyEmbed -Encoding utf8NoBOM
        $EmbedExitCode = Invoke-NativeProcess "python" @($TmpPyEmbed)
        Remove-Item $TmpPyEmbed -Force
        Invoke-LogMsg "    [*] Tag embed operations complete (Exit Code: $EmbedExitCode)."
    } else {
        # SAFE FALLBACK ROUTINE: Lyric engine returned nothing. Verify if it is an objective instrumental.
        Invoke-LogMsg "    [*] Track unindexed by lyric engines. Running database validation to check for explicit Instrumental classification..."
        
        $TmpPyInstrumentalCheck = Join-Path $env:TEMP "mutagen_is_instrumental.py"
        # FIXED: Swapped r"$SearchQuery" and r'$FilePath' parameters to triple double-quotes r"""..."""
        $VerifyPython = @"
import sys, os, urllib.request, json, urllib.parse, mutagen
from mutagen.mp4 import MP4
from mutagen.flac import FLAC
from mutagen.id3 import ID3, COMM

def check_musicbrainz(artist_title):
    try:
        url = "https://musicbrainz.org/ws/2/recording/?query=" + urllib.parse.quote(artist_title) + "&fmt=json"
        req = urllib.request.Request(url, headers={'User-Agent': 'MusicPipelineLyricsEngine/1.0.0 ( filip@FILIPS_MICRO_PC )'})
        with urllib.request.urlopen(req, timeout=5) as response:
            data = json.loads(response.read().decode())
            if data.get('recordings'):
                top_match = data['recordings'][0]
                tags = [t.get('name', '').lower() for t in top_match.get('tags', [])]
                if 'instrumental' in tags:
                    return True
                for rel in top_match.get('relations', []):
                    for attr in rel.get('attributes', []):
                        if attr.lower() == 'instrumental':
                            return True
    except Exception:
        pass
    return False

try:
    search_target = r"""$SearchQuery"""
    is_confirmed_instrumental = check_musicbrainz(search_target)
    
    if is_confirmed_instrumental:
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
                tags.append(mutagen.id3.TLAN(encoding=3, text=['zxx']))
                tags.add(COMM(encoding=3, lang='eng', desc='Comment', text='Instrumental'))
                tags.save(r"""$FilePath""")
            print("    [+] Verified Instrumental status via MusicBrainz database. Stamping track tags.")
    else:
        print("    [-] Track could not be verified as a definitive instrumental. Leaving tags untouched.")
except Exception as e:
    print(f"    [!] Safe check error: {e}")
    sys.exit(0)
"@
        $VerifyPython | Out-File $TmpPyInstrumentalCheck -Encoding utf8NoBOM
        $VerifyExitCode = Invoke-NativeProcess "python" @($TmpPyInstrumentalCheck)
        Remove-Item $TmpPyInstrumentalCheck -Force
        
        if (Test-Path -LiteralPath $LrcFile) { Remove-Item -LiteralPath $LrcFile -Force }
        if (Test-Path -LiteralPath $TxtFile) { Remove-Item -LiteralPath $TxtFile -Force }
    }
    Invoke-LogMsg "---------------------------------------------"
}

$MetricStopwatch.Stop()
$Elapsed = "{0:hh\:mm\:ss}" -f $MetricStopwatch.Elapsed
Invoke-LogMsg "[METRIC] Total Engine Run Duration: $Elapsed"
Invoke-LogMsg "============================================="
Exit 0