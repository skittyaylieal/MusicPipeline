Param (
    [string]$BackupDir = "C:\Users\filip\Music\YT_Music_Backup",
    [string]$ConfigDir = "C:\MusicTools\MusicPipeline\Config",
    [string]$OllamaUrl = "http://localhost:11434/api/generate",
    [string]$ModelName = "gemma2:9b",
    [int]$CooldownDays = 14,
    [string]$GlobalLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log",
    [bool]$ForceRefresh = $false,
    [bool]$CleanSweep = $false
)

# Start Total Stage Timer
$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# CORE DETERMINISTIC SHA-256 UUID GENERATOR
function Get-TrackUUID([string]$Artist, [string]$Album, [string]$Title) {
    $RawIdentity = "$Artist-$Album-$Title".ToLower().Trim()
    $Hasher = [System.Security.Cryptography.SHA256]::Create()
    $HashBytes = $Hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RawIdentity))
    $FullHash = [System.BitConverter]::ToString($HashBytes).Replace("-", "").ToLower()
    return $FullHash.Substring(0, 32)
}

# ANSI Logging Engine
function Invoke-LogMsg([string]$Text, [string]$AnsiColor = "38;5;135") {
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $ESC = [char]27
    $Reset = "$ESC[0m"

    $ColorPrefix   = "$ESC[${AnsiColor}m[$Timestamp] [VGM-Lore]$Reset"
    $FormattedLine = "$ColorPrefix $Text"

    Write-Host $FormattedLine

    if ($GlobalLogFile -and (Test-Path -LiteralPath $GlobalLogFile)) {
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

# Web Search Snippet Extractor via DuckDuckGo
function Get-DuckDuckGoContext([string]$Title, [string]$Artist) {
    $Query = "`"$Title`" `"$Artist`" video game soundtrack lore"
    $SearchUrl = "https://html.duckduckgo.com/html/"
    $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    try {
        $Response = Invoke-WebRequest -Uri $SearchUrl -Method Post -Body @{ q = $Query } -UserAgent $UserAgent -TimeoutSec 10 -ErrorAction Stop
        $Html = $Response.Content

        $RegexMatches = [regex]::Matches($Html, '<a class="result__snippet"[^>]*>(.*?)</a>', [System.Text.RegularExpressions.RegexOptions]::Singleline)

        if ($RegexMatches.Count -eq 0) {
            return "No real-time web context found."
        }

        $Snippets = @()
        $Count = [Math]::Min(4, $RegexMatches.Count)
        for ($i = 0; $i -lt $Count; $i++) {
            $CleanText = $RegexMatches[$i].Groups[1].Value -replace '<[^>]+>', ''
            $CleanText = [System.Net.WebUtility]::HtmlDecode($CleanText).Trim()
            if (-not [string]::IsNullOrWhiteSpace($CleanText)) {
                $Snippets += $CleanText
            }
        }

        if ($Snippets.Count -gt 0) {
            return ($Snippets -join "`n")
        }
        return "No real-time web context found."
    } catch {
        return "No real-time web context available (Search request failed)."
    }
}

# Mutagen Helpers
function Get-M4aTags([string]$FilePath) {
    $PyCode = @"
import sys, json
from mutagen.mp4 import MP4
try:
    audio = MP4(sys.argv[1])
    title = audio.get('\xa9nam', [''])[0]
    artist = audio.get('\xa9ART', [''])[0]
    album = audio.get('\xa9alb', [''])[0]
    lyrics = audio.get('\xa9lyr', [''])[0]
    print(json.dumps({'title': title, 'artist': artist, 'album': album, 'has_lyrics': bool(lyrics), 'existing_lyrics': lyrics}))
except Exception as e:
    print(json.dumps({'error': str(e)}))
"@
    $Res = & python -c $PyCode "$FilePath" 2>$null
    if ($Res) {
        try { return ($Res | ConvertFrom-Json) } catch { return $null }
    }
    return $null
}

function Set-M4aLyrics([string]$FilePath, [string]$LoreText) {
    $PyCode = @"
import sys
from mutagen.mp4 import MP4
audio = MP4(sys.argv[1])
audio['\xa9lyr'] = [sys.argv[2]]
audio.save()
"@
    & python -c $PyCode "$FilePath" $LoreText 2>$null
}

# --- INITIALIZATION & CACHE LOADING ---
Invoke-LogMsg "============================================="
Invoke-LogMsg "    PowerShell Module: VGM Lore Evaluator"
if ($CleanSweep) {
    Invoke-LogMsg "    [MODE] Clean Sweep Active (Re-evaluating existing lore)" "33"
}
Invoke-LogMsg "============================================="

$CachePath = Join-Path $ConfigDir "vgm_cache.json"
$InstrumentalsDbPath = Join-Path $ConfigDir "instrumentals.json"

$VgmCache = @{}
if (Test-Path -LiteralPath $CachePath) {
    try {
        $RawJson = Get-Content -LiteralPath $CachePath -Raw -ErrorAction SilentlyContinue
        if ($RawJson) {
            $JsonObj = $RawJson | ConvertFrom-Json
            foreach ($Prop in $JsonObj.psobject.Properties) {
                $VgmCache[$Prop.Name] = $Prop.Value
            }
        }
    } catch {
        Invoke-LogMsg "⚠️ Failed parsing vgm_cache.json. Rebuilding cache store." "31"
    }
}

$TargetFiles = @()
if (Test-Path -LiteralPath $BackupDir) {
    $AllM4A = Get-ChildItem -Path $BackupDir -Filter "*.m4a" -Recurse -File
    
    if (Test-Path -LiteralPath $InstrumentalsDbPath) {
        try {
            $InstDb = Get-Content -LiteralPath $InstrumentalsDbPath -Raw | ConvertFrom-Json
            $InstIds = $InstDb | ForEach-Object { $_.id }
            foreach ($File in $AllM4A) {
                $Tags = Get-M4aTags -FilePath $File.FullName
                if ($Tags -and $Tags.title) {
                    $TrackId = Get-TrackUUID -Artist $Tags.artist -Album $Tags.album -Title $Tags.title
                    if ($InstIds -contains $TrackId) { $TargetFiles += $File }
                }
            }
        } catch {
            $TargetFiles = $AllM4A
        }
    } else {
        $TargetFiles = $AllM4A
    }
}

Invoke-LogMsg "[+] Located $($TargetFiles.Count) candidate instrumental track(s) for VGM lore evaluation." "32"

$SuccessCount = 0
$FlaggedCount = 0
$SkippedCount = 0
$TrackIndex = 0

foreach ($File in $TargetFiles) {
    $TrackIndex++
    $FilePath = $File.FullName
    $FileName = $File.Name

    $Tags = Get-M4aTags -FilePath $FilePath
    if (-not $Tags -or -not $Tags.title -or -not $Tags.artist) {
        Invoke-LogMsg "[-] Skipping $FileName (Missing Title/Artist metadata tags)" "90"
        continue
    }

    $TrackId = Get-TrackUUID -Artist $Tags.artist -Album $Tags.album -Title $Tags.title

    # 14-Day Cooldown Check (Bypassed in Clean Sweep or Force Refresh mode)
    if ($VgmCache.ContainsKey($TrackId) -and -not $ForceRefresh -and -not $CleanSweep) {
        $Entry = $VgmCache[$TrackId]
        if ($Entry.status -eq "NOT_VGM" -and $Entry.last_checked) {
            $LastChecked = [DateTime]::Parse($Entry.last_checked)
            if ((Get-Date) -lt $LastChecked.AddDays($CooldownDays)) {
                $NextCheck = $LastChecked.AddDays($CooldownDays).ToString("yyyy-MM-dd")
                Invoke-LogMsg "[~] Skipping [$TrackIndex/$($TargetFiles.Count)]: '$($Tags.title)' (Flagged NOT_VGM | Cooldown active until $NextCheck)" "38;5;244"
                $SkippedCount++
                continue
            }
        }
    }

    $HasExistingLore = -not [string]::IsNullOrWhiteSpace($Tags.existing_lyrics)
    $ExistingLoreText = if ($HasExistingLore) { $Tags.existing_lyrics } else { "No prior lore embedded." }

    if ($CleanSweep -and $HasExistingLore) {
        Invoke-LogMsg "[*] [Sweep Review] Inspecting existing lore for [$TrackIndex/$($TargetFiles.Count)]: '$($Tags.title)' - $($Tags.artist)" "36"
    } else {
        Invoke-LogMsg "[*] Evaluating Track [$TrackIndex/$($TargetFiles.Count)]: '$($Tags.title)' - $($Tags.artist)" "36"
    }
    
    $WebContext = Get-DuckDuckGoContext -Title $Tags.title -Artist $Tags.artist

    $Prompt = @"
You are an expert video game music historian and metadata validator. 
Analyze this track:
Track Title: $($Tags.title)
Artist/Composer: $($Tags.artist)

PREVIOUS / EXISTING EMBEDDED LORE (FOR CONTEXT & REVIEW):
$ExistingLoreText

LIVE WEB SEARCH CONTEXT FOR THIS TRACK:
$WebContext

CRITICAL VALIDATION STEP:
Evaluate if this track is a verified piece of video game music (VGM). 
If the track is NOT from a video game, or if it is a generic non-gaming instrumental track (e.g. standalone jazz, classical, or background pop), respond with EXACTLY ONE WORD: NOT_VGM
Do not include any other text, explanations, spaces, or punctuation if it fails validation.

IF IT PASSES VALIDATION:
Review the PREVIOUS / EXISTING EMBEDDED LORE alongside the LIVE WEB SEARCH CONTEXT.
- If the existing lore is inaccurate, outdated, missing key details, or can be substantially improved, synthesize an updated and refined version.
- If the existing lore is already accurate and thorough, format and re-affirm the complete text according to the required rules below.

Format the output as clean plain text for a mobile display screen. 
Use ALL CAPS for section headers. Do NOT use markdown (no asterisks, no hashes, no bullet points).
Include these exact sections:
1. GAME ORIGIN (The game title and release year)
2. COMPOSER BIO (2 sentences on the artist)
3. GAMEPLAY CONTEXT (Where/when it plays in-game)
4. NARRATIVE SIGNIFICANCE (The emotional context or meaning)
5. MUSICAL MOTIFS (Themes, patterns, or instruments used)
"@

    $Payload = @{
        model   = $ModelName
        prompt  = $Prompt
        stream  = $false
        options = @{ temperature = 0.1 }
    } | ConvertTo-Json -Depth 5

    try {
        $OllamaRes = Invoke-RestMethod -Uri $OllamaUrl -Method Post -Body $Payload -ContentType "application/json" -TimeoutSec 60
        $LoreOutput = $OllamaRes.response.Trim()
    } catch {
        Invoke-LogMsg "[-] Ollama connection failed or timed out: $_" "31"
        $LoreOutput = "NOT_VGM"
    }

    if ($LoreOutput -eq "NOT_VGM" -or $LoreOutput.StartsWith("NOT_VGM")) {
        Invoke-LogMsg "  [!] Flagged as NOT_VGM by $ModelName. Cooldown activated." "33"
        
        $VgmCache[$TrackId] = [PSCustomObject]@{
            title        = $Tags.title
            artist       = $Tags.artist
            status       = "NOT_VGM"
            last_checked = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        }
        $FlaggedCount++
    } else {
        Set-M4aLyrics -FilePath $FilePath -LoreText $LoreOutput
        if ($CleanSweep -and $HasExistingLore) {
            Invoke-LogMsg "  [✓] Successfully reviewed and updated VGM lore tag!" "32"
        } else {
            Invoke-LogMsg "  [✓] Successfully embedded VGM lore into M4A lyrics tag!" "32"
        }

        $VgmCache[$TrackId] = [PSCustomObject]@{
            title        = $Tags.title
            artist       = $Tags.artist
            status       = "VGM_EMBEDDED"
            last_checked = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        }
        $SuccessCount++
    }

    # Atomic Cache Write
    $TempCache = "$CachePath.tmp"
    $VgmCache | ConvertTo-Json -Depth 5 | Out-File -FilePath $TempCache -Encoding utf8 -Force
    Move-Item -Path $TempCache -Destination $CachePath -Force
}

# STOP TOTAL STAGE TIMER & LOG METRIC
$MetricStopwatch.Stop()
$TotalHours = [math]::Floor($MetricStopwatch.Elapsed.TotalHours)
$Elapsed = "{0:00}:{1:mm\:ss}" -f $TotalHours, $MetricStopwatch.Elapsed

Invoke-LogMsg "============================================="
Invoke-LogMsg "VGM Lore Stage Finished: $SuccessCount Processed | $FlaggedCount Non-VGM Flagged | $SkippedCount Cooldown Skipped" "1;32"
Invoke-LogMsg "[METRIC] $Elapsed"
Invoke-LogMsg "============================================="
Exit 0