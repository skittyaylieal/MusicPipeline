Param (
    [Parameter(Mandatory=$true)]
    [string]$LogPath,
    [Parameter(Mandatory=$true)]
    [string]$DatabasePath,
    [string]$RunId = (Get-Date).ToString("yyyyMMdd_HHmmss")
)

function Get-TrackUUID([string]$Artist, [string]$Album, [string]$Title) {
    $RawIdentity = "$Artist-$Album-$Title".ToLower().Trim()
    $Hasher = [System.Security.Cryptography.SHA256]::Create()
    $HashBytes = $Hasher.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($RawIdentity))
    $FullHash = [System.BitConverter]::ToString($HashBytes).Replace("-", "").ToLower()
    return $FullHash.Substring(0, 32)
}

$AnsiRegex = '(?:\x1B[@-Z\\-_]|\x1B\[[0-9?]*[ -/]*[@-~])'

# Extraction Regex Patterns (\d+ on hours allows 80+ hour metrics)
$StartPattern       = '^\[(\d{2}:\d{2}:\d{2})\].*?\[download\] Downloading item (\d+) of (\d+)'
$DestPattern        = '\[download\] Destination: .*\\([^\\]+)\\([^\\]+)\\([^\\]+)\.[^.\\]+$'
$FinalPattern       = '^\[(\d{2}:\d{2}:\d{2})\].*?Sync completed successfully!'
$StageMetricPattern = '^\[(\d{2}:\d{2}:\d{2})\]\s*(?:\[(.*?)\])?\s*\[METRIC\]\s*(?:Total Engine Run Duration:\s*)?(\d+:\d{2}:\d{2})'

if (-not (Test-Path -LiteralPath $LogPath)) {
    Write-Error "Target pipeline execution stream log not discovered at: $LogPath"
    Exit 1
}

$TrackMetrics = @()
$ActiveTrack = $null

# Sequential Midnight Rollover Tracker
$CurrentBaseDate = (Get-Date).Date
$LastSeenTS      = [TimeSpan]::Zero

Write-Output "Executing ANSI Log Extraction Engine on: $LogPath"
$Lines = Get-Content -LiteralPath $LogPath -Encoding utf8 -ErrorAction SilentlyContinue

foreach ($Line in $Lines) {
    $CleanLine = $Line -replace $AnsiRegex, ''

    # Helper script to parse time while accounting for multi-day rollovers
    function Get-AbsoluteTime([string]$TimeStr) {
        $TS = [TimeSpan]::Parse($TimeStr)
        if ($TS -lt $script:LastSeenTS -and ($script:LastSeenTS - $TS).TotalHours -gt 12) {
            $script:CurrentBaseDate = $script:CurrentBaseDate.AddDays(1)
        }
        $script:LastSeenTS = $TS
        return $script:CurrentBaseDate.Add($TS)
    }

    # Case A: Downloader Track Start
    if ($CleanLine -match $StartPattern) {
        $TimeStr = $Matches[1]
        $TrackIndex = $Matches[2]
        $NewStartTime = Get-AbsoluteTime $TimeStr

        if ($null -ne $ActiveTrack) {
            $Delta = ($NewStartTime - $ActiveTrack.StartTime).TotalSeconds

            $TrackMetrics += @{
                runId     = $RunId
                id        = $ActiveTrack.Id
                index     = [int]$ActiveTrack.Index
                name      = $ActiveTrack.Name
                stage     = "download"
                duration  = [Math]::Round($Delta, 2)
                timestamp = $ActiveTrack.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
        }

        $ActiveTrack = [PSCustomObject]@{
            Index     = $TrackIndex
            StartTime = $NewStartTime
            Name      = "Unknown Track (Skipped or Processed)"
            Id        = "unknown_or_skipped_uuid"
        }
        continue
    }

    # Case B: Downloader Destination Match
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

    # Case C: Downloader Completion
    if ($CleanLine -match $FinalPattern) {
        if ($null -ne $ActiveTrack) {
            $TimeStr = $Matches[1]
            $FinalTime = Get-AbsoluteTime $TimeStr
            $Delta = ($FinalTime - $ActiveTrack.StartTime).TotalSeconds

            $TrackMetrics += @{
                runId     = $RunId
                id        = $ActiveTrack.Id
                index     = [int]$ActiveTrack.Index
                name      = $ActiveTrack.Name
                stage     = "download"
                duration  = [Math]::Round($Delta, 2)
                timestamp = $ActiveTrack.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
            }
            $ActiveTrack = $null
        }
    }

    # Case D: Stage Metric Entry (e.g., Fixer, VGM-Lore stage total)
    if ($CleanLine -match $StageMetricPattern) {
        $LogTime   = $Matches[1]
        $Tag       = if ($Matches[2]) { $Matches[2] } else { "SERVER" }
        $Duration  = $Matches[3]
        
        # Parse [TimeSpan] directly (handles arbitrary hour durations like 80:14:22)
        $TimeSpan  = [TimeSpan]::Parse($Duration)

        $TrackMetrics += @{
            runId     = $RunId
            id        = "stage_metric_$Tag".ToLower()
            index     = 0
            name      = "$Tag Stage Total"
            stage     = $Tag.ToLower()
            duration  = $TimeSpan.TotalSeconds
            timestamp = (Get-Date).ToString("yyyy-MM-dd ") + $LogTime
        }
    }
}

if ($null -ne $ActiveTrack) {
    $TrackMetrics += @{
        runId     = $RunId
        id        = $ActiveTrack.Id
        index     = [int]$ActiveTrack.Index
        name      = $ActiveTrack.Name
        stage     = "download"
        duration  = 0.0
        timestamp = $ActiveTrack.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
}

# Save Metrics to DB
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

    $UpdatedHistory = $ExistingHistory + $TrackMetrics

    $TempDbFile = "$DatabasePath.tmp"
    $UpdatedHistory | ConvertTo-Json -Depth 4 | Out-File -FilePath $TempDbFile -Encoding utf8 -Force
    Move-Item -Path $TempDbFile -Destination $DatabasePath -Force
    
    Write-Output "Successfully committed $($TrackMetrics.Count) telemetry records."
} else {
    Write-Output "Analytics Run Finished: Zero metrics changes found to ingest."
}