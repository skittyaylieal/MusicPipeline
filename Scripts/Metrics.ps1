Param (
    [Parameter(Mandatory=$true)]
    [string]$LogPath,
    [Parameter(Mandatory=$true)]
    [string]$DatabasePath,
    [string]$RunId = (Get-Date).ToString("yyyyMMdd_HHmmss")
)

# -----------------------------------------------------------------
# CORE DETERMINISTIC SHA-256 UUID GENERATOR
# -----------------------------------------------------------------
function Get-TrackUUID([string]$Artist, [string]$Album, [string]$Title) {
    # Force lowercase and trim spacing anomalies to ensure a stable hashing surface
    $RawIdentity = "$Artist-$Album-$Title".ToLower().Trim()
    
    $Hasher = [System.Security.Cryptography.SHA256]::Create()
    $HashBytes = $Hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RawIdentity))
    
    # Convert byte-array to hex string and truncate to 32 characters for standard database sizing
    $FullHash = [System.BitConverter]::ToString($HashBytes).Replace("-", "").ToLower()
    return $FullHash.Substring(0, 32)
}

# Standard regex to catch and discard visible/invisible ANSI terminal styling escapes
$AnsiRegex = '(?:\x1B[@-Z\\-_]|\x1B\[[0-?]*[ -/]*[@-~])'

# Clean state-machine signatures mapped to yt-dlp console boundaries
$StartPattern = '^\[(\d{2}:\d{2}:\d{2})\].*?\[download\] Downloading item (\d+) of (\d+)'
$DestPattern  = '\[download\] Destination: .*\\([^\\]+)\\([^\\]+)\\([^\\]+)\.[^.\\]+$'
$FinalPattern = '^\[(\d{2}:\d{2}:\d{2})\].*?Sync completed successfully!'

if (-not (Test-Path -LiteralPath $LogPath)) {
    Write-Error "Target pipeline execution stream log not discovered at: $LogPath"
    Exit 1
}

$TrackMetrics = @()
$ActiveTrack = $null

Write-Output "Executing ANSI Log Extraction Engine on: $LogPath"
$Lines = Get-Content -LiteralPath $LogPath -Encoding utf8 -ErrorAction SilentlyContinue

foreach ($Line in $Lines) {
    # Strip terminal color layout anomalies on current evaluation frame
    $CleanLine = $Line -replace $AnsiRegex, ''

    # Case A: A new track initializes execution loops
    if ($CleanLine -match $StartPattern) {
        $TimeStr = $Matches[1]
        $TrackIndex = $Matches[2]
        $NewStartTime = [DateTime]::ParseExact($TimeStr, "HH:mm:ss", $null)

        # Closure Check: Process and save previously running item metrics
        if ($null -ne $ActiveTrack) {
            $Delta = ($NewStartTime - $ActiveTrack.StartTime).TotalSeconds
            if ($Delta -lt 0) { $Delta += 86400 } # Midnight rollback safety frame

            $TrackMetrics += @{
                runId     = $RunId
                id        = $ActiveTrack.Id
                index     = [int]$ActiveTrack.Index
                name      = $ActiveTrack.Name
                duration  = [Math]::Round($Delta, 2)
                timestamp = $ActiveTrack.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }

        # Instantiating current pointer frame
        $ActiveTrack = [PSCustomObject]@{
            Index     = $TrackIndex
            StartTime = $NewStartTime
            Name      = "Unknown Track (Skipped or Processed)"
            Id        = "unknown_or_skipped_uuid"
        }
        continue
    }

    # Case B: Local storage layout assignment is hit (Extract Folder metadata identities)
    if ($CleanLine -match $DestPattern) {
        if ($null -ne $ActiveTrack) {
            $Artist = $Matches[1]
            $Album  = $Matches[2]
            $Title  = $Matches[3]

            $ActiveTrack.Name = $Title
            $ActiveTrack.Id   = Get-TrackUUID -Artist $Artist -Album $Album -Title $Title
        }
        continue
    }

    # Case C: Master execution engine gracefully finishes up
    if ($CleanLine -match $FinalPattern) {
        if ($null -ne $ActiveTrack) {
            $TimeStr = $Matches[1]
            $FinalTime = [DateTime]::ParseExact($TimeStr, "HH:mm:ss", $null)
            $Delta = ($FinalTime - $ActiveTrack.StartTime).TotalSeconds
            if ($Delta -lt 0) { $Delta += 86400 }

            $TrackMetrics += @{
                runId     = $RunId
                id        = $ActiveTrack.Id
                index     = [int]$ActiveTrack.Index
                name      = $ActiveTrack.Name
                duration  = [Math]::Round($Delta, 2)
                timestamp = $ActiveTrack.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
            $ActiveTrack = $null
        }
    }
}

# Catch any hanging unclosed processes if script output ended abruptly
if ($null -ne $ActiveTrack) {
    $TrackMetrics += @{
        runId     = $RunId
        id        = $ActiveTrack.Id
        index     = [int]$ActiveTrack.Index
        name      = $ActiveTrack.Name
        duration  = 0.0
        timestamp = $ActiveTrack.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# -----------------------------------------------------------------
# ATOMIC HISTORICAL DATA STORAGE COMPILER
# -----------------------------------------------------------------
if ($TrackMetrics.Count -gt 0) {
    $ExistingHistory = @()
    if (Test-Path -LiteralPath $DatabasePath) {
        try {
            $RawJson = Get-Content -LiteralPath $DatabasePath -Raw -ErrorAction SilentlyContinue
            if ($RawJson) { $ExistingHistory = ConvertFrom-Json $RawJson }
        } catch {
            Write-Warning "Failed parsing historical files. Rebuilding matrix container layout."
        }
    }

    # Merge arrays cleanly
    $UpdatedHistory = $ExistingHistory + $TrackMetrics

    # Execute safe atomic file swapping logic
    $TempDbFile = "$DatabasePath.tmp"
    $UpdatedHistory | ConvertTo-Json -Depth 4 | Out-File -FilePath $TempDbFile -Encoding utf8 -Force
    Move-Item -Path $TempDbFile -Destination $DatabasePath -Force
    
    Write-Output "Successfully compiled and committed $($TrackMetrics.Count) track telemetry snapshots."
} else {
    Write-Output "Analytics Run Finished: Zero metrics changes found to ingest."
}