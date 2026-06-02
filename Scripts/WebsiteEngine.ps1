Param (
    [string]$BackupDir = "C:\MusicTools\MusicPipeline\YT_Music_Backup",
    [string]$MobileDir = "C:\MusicTools\MusicPipeline\YT_Music_Mobile",
    [string]$BatchScript = "C:\MusicTools\MusicPipeline\sync_music.bat"
)

$Global:LogBuffer = New-Object System.Collections.Generic.List[string]
$Global:IsPipelineRunning = $false

# Establish repository working directory context dynamically
$ScriptRepoDir = [System.IO.Path]::GetDirectoryName($BatchScript)

# -----------------------------------------------------------------
# 1. HELPER FUNCTION: METRICS SCAN & INTEGRATED SYSTEM AUDITS
# -----------------------------------------------------------------
function Get-LibraryMetrics {
    if (-not (Test-Path -LiteralPath $BackupDir)) { return @{} }

    $MasterFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }
    $MobileFiles = Get-ChildItem -LiteralPath $MobileDir -Recurse -File | Where-Object { $_.Extension -match "m4a" }
    $LrcFiles    = Get-ChildItem -LiteralPath $BackupDir -Recurse -Filter "*.lrc" -File

    $MasterSize = ($MasterFiles | Measure-Object -Property Length -Sum).Sum / 1GB
    $MobileSize = ($MobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB

    $Alerts = @()

    # --- AUDIT A: AUTOMATIC SELF-UPDATE PIPELINE ---
    if (Test-Path -LiteralPath "$ScriptRepoDir\.git") {
        Push-Location $ScriptRepoDir
        try {
            $Env:GIT_TERMINAL_PROMPT = "0"
            [void](git -c network.timeout=3 fetch origin 2>&1)
            $LocalHash  = (git rev-parse HEAD).Trim()
            $RemoteHash = (git rev-parse "@{upstream}").Trim()

            if ($LocalHash -ne $RemoteHash) {
                # Update detected! Intercept normal loop to execute an immediate auto-update sequence
                $Global:LogBuffer.Add("[SYSTEM] Git remote mismatch detected! Initiating hot-reload...")
                $Global:LogBuffer.Add("[SYSTEM] Fetching latest updates from GitHub...")
                
                # Execute the pull synchronously right here so it completes before restart
                [void](git pull origin main 2>&1)
                
                $Global:LogBuffer.Add("[SYSTEM] Pull complete. Triggering Task Scheduler recycler...")
                
                # Spawn a completely detached thread task to reboot this process
                $null = Start-ThreadJob -ScriptBlock {
                    Start-Sleep -Seconds 2
                    # Use schtasks to forcefully stop and restart this exact task container cleanly
                    schtasks /end /tn "Music Pipeline Web Console"
                    Start-Sleep -Seconds 2
                    schtasks /run /tn "Music Pipeline Web Console"
                }
            }
        } catch {}
        Pop-Location
    }
    
    # --- AUDIT B: SYNCHRONIZATION GAP ---
    $CountGap = $MasterFiles.Count - $MobileFiles.Count
    if ($CountGap -gt 0) {
        $Alerts += @{
            type = "danger"
            message = "Synchronization Gap: Master backup has $CountGap more track(s) than Mobile Storage."
            fixAction = "sync"
        }
    }

    # --- AUDIT C: LYRIC COVERAGE DEFICIT ---
    if ($MasterFiles.Count -gt 0) {
        $LyricCoverage = ($LrcFiles.Count / $MasterFiles.Count) * 100
        if ($LyricCoverage -lt 75) {
            $Alerts += @{
                type = "warning"
                message = "Low Lyric Coverage: Only $([Math]::Round($LyricCoverage, 1))% of library has synced (.lrc) metadata."
                fixAction = "none"
            }
        }
    }

    $TrackDatabase = @()
    foreach ($File in $MasterFiles) {
        $RelativePath = $File.FullName.Substring($BackupDir.Length).TrimStart('\')
        $PathParts = $RelativePath -split '\\'
        $Artist = if ($PathParts.Count -ge 3) { $PathParts[0] } else { "Unknown Artist" }
        $Album  = if ($PathParts.Count -ge 3) { $PathParts[1] } else { "Single / Unknown" }
        $HasLrc = Test-Path -LiteralPath "$($File.DirectoryName)\$($File.BaseName).lrc"

        $TrackDatabase += @{
            title  = $File.BaseName
            artist = $Artist
            album  = $Album
            sizeMb = [Math]::Round(($File.Length / 1MB), 2)
            hasLrc = $HasLrc
            type   = $File.Extension.ToUpper().Replace('.','')
        }
    }

    return @{
        masterCount = $MasterFiles.Count
        mobileCount = $MobileFiles.Count
        lrcCount    = $LrcFiles.Count
        masterSize  = [Math]::Round($MasterSize, 2)
        mobileSize  = [Math]::Round($MobileSize, 2)
        alerts      = $Alerts
        tracks      = $TrackDatabase
    }
}

# -----------------------------------------------------------------
# 2. HELPER FUNCTION: ASYNC WORKER TASK ENGINE (NON-BLOCKING)
# -----------------------------------------------------------------
function Invoke-PipelineExecution {
    param([string]$Type = "sync")
    if ($Global:IsPipelineRunning) { return }
    $Global:IsPipelineRunning = $true
    $Global:LogBuffer.Clear()

    $Global:LogBuffer.Add("[SYSTEM] Dispatching background process worker: Mode ($Type)...")

    $JobScript = {
        param($ScriptPath, $RepoDir, $Mode)
        Set-Location $RepoDir
        cmd.exe /c "`"$ScriptPath`" headless" 2>&1
    }
    
    $Job = Start-Job -ScriptBlock $JobScript -ArgumentList $BatchScript, $ScriptRepoDir, $Type

    $null = Start-ThreadJob -ScriptBlock {
        while ($using:Job.State -eq "Running") {
            $Data = Receive-Job -Job $using:Job
            foreach ($Line in $Data) { 
                if ($Line) { $Global:LogBuffer.Add($Line.ToString()) } 
            }
            Start-Sleep -Seconds 1
        }
        $FinalData = Receive-Job -Job $using:Job
        foreach ($Line in $FinalData) { 
            if ($Line) { $Global:LogBuffer.Add($Line.ToString()) } 
        }
        $Global:LogBuffer.Add("[SYSTEM] Engine loop tracking complete.")
        Remove-Job -Job $using:Job
        $Global:IsPipelineRunning = $false
    }
}

# -----------------------------------------------------------------
# 3. CORE FRONTEND DASHBOARD INTERFACE ASSET (RAW LITERAL STRING)
# -----------------------------------------------------------------
$HtmlDashboard = @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Music Pipeline Master Console</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #0F0F11; color: #E2E8F0; margin: 0; padding: 25px; }
        .alert-container { margin-bottom: 20px; }
        .alert { padding: 15px 20px; border-radius: 6px; margin-bottom: 10px; font-size: 0.95em; display: flex; justify-content: space-between; align-items: center; font-weight: 500; }
        .alert-danger { background: #4C1D1D; color: #F87171; border: 1px solid #7F1D1D; }
        .alert-warning { background: #453015; color: #FBBF24; border: 1px solid #78350F; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-bottom: 25px; }
        .card { background: #18181C; padding: 20px; border-radius: 10px; border: 1px solid #27272A; text-align: center; }
        .card h3 { margin: 0; color: #A1A1AA; font-size: 0.9em; text-transform: uppercase; letter-spacing: 0.5px; }
        .card .value { font-size: 2em; font-weight: bold; margin: 10px 0; color: #00ADB5; }
        .main-layout { display: grid; grid-template-columns: 1fr 1fr; gap: 25px; height: calc(100vh - 260px); }
        .panel { background: #18181C; border-radius: 10px; border: 1px solid #27272A; padding: 20px; display: flex; flex-direction: column; }
        h2 { margin-top: 0; color: #FFF; font-size: 1.3em; border-bottom: 1px solid #27272A; padding-bottom: 10px; display: flex; justify-content: space-between; align-items: center; }
        .btn { background: #00ADB5; color: #FFF; border: none; padding: 10px 20px; border-radius: 5px; font-weight: bold; cursor: pointer; transition: opacity 0.2s; }
        .btn:hover { opacity: 0.9; }
        .btn:disabled { background: #3F3F46; cursor: not-allowed; }
        .console { background: #09090B; border-radius: 6px; padding: 15px; font-family: monospace; font-size: 0.85em; color: #39FF14; overflow-y: auto; flex-grow: 1; white-space: pre-wrap; border: 1px solid #18181B; }
        .search-box { background: #222226; border: 1px solid #3F3F46; color: #FFF; padding: 10px; border-radius: 5px; width: calc(100% - 22px); margin-bottom: 15px; font-size: 0.95em; }
        .table-wrapper { overflow-y: auto; flex-grow: 1; }
        table { width: 100%; border-collapse: collapse; font-size: 0.9em; text-align: left; }
        th { background: #222226; color: #A1A1AA; padding: 10px; font-weight: 600; position: sticky; top: 0; }
        td { padding: 10px; border-bottom: 1px solid #27272A; }
        .badge { padding: 2px 6px; border-radius: 4px; font-size: 0.75em; font-weight: bold; }
        .badge-lrc { background: #1C3D27; color: #4ADE80; }
        .badge-missing { background: #4C1D1D; color: #F87171; }
    </style>
</head>
<body>

    <div class="alert-container" id="alerts-zone"></div>

    <div class="grid">
        <div class="card"><h3>Master Tracks</h3><div class="value" id="stat-master-count">-</div></div>
        <div class="card"><h3>Mobile Storage</h3><div class="value" id="stat-mobile-count">-</div></div>
        <div class="card"><h3>Lyrics Index</h3><div class="value" id="stat-lrc-count">-</div></div>
        <div class="card"><h3>Storage Weights</h3><div class="value" id="stat-sizes">-</div></div>
    </div>

    <div class="main-layout">
        <div class="panel">
            <h2>Execution Pipeline <button class="btn" id="run-btn" onclick="triggerPipeline('sync')">Run Master Sync</button></h2>
            <div class="console" id="terminal-feed">Ready. Awaiting run commands...</div>
        </div>

        <div class="panel">
            <h2>Archive Metadata Navigator</h2>
            <input type="text" class="search-box" id="search-input" placeholder="Search archive by title, artist, or album..." onkeyup="filterDatabase()">
            <div class="table-wrapper">
                <table>
                    <thead>
                        <tr>
                            <th>Track Title</th>
                            <th>Artist</th>
                            <th>Album</th>
                            <th>Lyrics</th>
                        </tr>
                    </thead>
                    <tbody id="metadata-rows">
                        <tr><td colspan="4" style="text-align:center; color:#71717A;">Scanning file layout...</td></tr>
                    </tbody>
                </table>
            </div>
        </div>
    </div>

    <script>
        let fullTrackDb = [];

        function loadMetrics() {
            fetch('/metrics')
                .then(res => res.json())
                .then(data => {
                    document.getElementById('stat-master-count').innerText = `${data.masterCount} files`;
                    document.getElementById('stat-mobile-count').innerText = `${data.mobileCount} compressed`;
                    document.getElementById('stat-lrc-count').innerText = `${data.lrcCount} synced`;
                    document.getElementById('stat-sizes').innerText = `${data.mobileSize} GB / ${data.masterSize} GB`;
                    
                    const alertZone = document.getElementById('alerts-zone');
                    if (data.alerts && data.alerts.length > 0) {
                        alertZone.innerHTML = data.alerts.map(a => `
                            <div class="alert alert-${a.type}">
                                <span>⚠️ ${a.message}</span>
                            </div>
                        `).join('');
                    } else {
                        alertZone.innerHTML = '';
                    }

                    fullTrackDb = data.tracks || [];
                    buildTable(fullTrackDb);
                })
                .catch(() => {
                    // If network dropped due to a script restart, place visual indicator
                    document.getElementById('terminal-feed').innerText = "[SYSTEM] Server connection dropped. Web service is recycling updates...";
                });
        }

        function buildTable(tracks) {
            const tbody = document.getElementById('metadata-rows');
            if(tracks.length === 0) {
                tbody.innerHTML = `<tr><td colspan="4" style="text-align:center; color:#71717A;">No records found</td></tr>`;
                return;
            }
            tbody.innerHTML = tracks.map(t => `
                <tr>
                    <td><strong>${t.title}</strong> <span style="color:#71717A; font-size:0.8em;">(${t.type})</span></td>
                    <td>${t.artist}</td>
                    <td>${t.album}</td>
                    <td>${t.hasLrc ? '<span class="badge badge-lrc">LRC</span>' : '<span class="badge badge-missing">TXT/NONE</span>'}</td>
                </tr>
            `).join('');
        }

        function filterDatabase() {
            const query = document.getElementById('search-input').value.toLowerCase();
            const filtered = fullTrackDb.filter(t => 
                t.title.toLowerCase().includes(query) || 
                t.artist.toLowerCase().includes(query) || 
                t.album.toLowerCase().includes(query)
            );
            buildTable(filtered);
        }

        function triggerPipeline(mode) {
            document.getElementById('run-btn').disabled = true;
            fetch('/run?mode=' + mode, { method: 'POST' });
        }

        setInterval(() => {
            fetch('/stream')
                .then(res => res.json())
                .then(data => {
                    document.getElementById('run-btn').disabled = data.running;
                    if(data.logs.length > 0) {
                        const consoleBox = document.getElementById('terminal-feed');
                        consoleBox.innerText = data.logs.join('\n');
                        consoleBox.scrollTop = consoleBox.scrollHeight;
                    }
                })
                .catch(() => {
                     document.getElementById('terminal-feed').innerText = "[SYSTEM] Hot-reload triggered. Reconnecting to dashboard runtime engine...";
                });
        } , 1000);

        setInterval(loadMetrics, 5000);
        loadMetrics();
    </script>
</body>
</html>
'@

# -----------------------------------------------------------------
# 3.5 AUTOMATIC BACKGROUND TIMER (Every 30 Minutes)
# -----------------------------------------------------------------
$TimerScript = {
    param($EngineUrl)
    while ($true) {
        Start-Sleep -Seconds 1800
        try { Invoke-RestMethod -Uri "$EngineUrl`run?mode=sync" -Method Post | Out-Null } catch {}
    }
}
$null = Start-Job -ScriptBlock $TimerScript -ArgumentList "http://localhost:8080/"

# -----------------------------------------------------------------
# 4. HTTP LISTENER CORE WEB ENGINE ROUTING LOOP WITH AUTO-CLEANUP
# -----------------------------------------------------------------
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:8080/")

try {
    $Listener.Start()
    $Running = $true
    
    while ($Running) {
        try {
            $Context = $Listener.GetContext()
            $Request = $Context.Request
            $Response = $Context.Response
            $UrlPath = $Request.Url.LocalPath
            $Method  = $Request.HttpMethod

            if ($UrlPath -eq "/" -and $Method -eq "GET") {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlDashboard)
                $Response.ContentType = "text/html; charset=utf-8"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/metrics" -and $Method -eq "GET") {
                $DataMetrics = Get-LibraryMetrics
                $JsonPayload = $DataMetrics | ConvertTo-Json -Depth 4 -Compress
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/stream" -and $Method -eq "GET") {
                $StreamObj = @{
                    running = $Global:IsPipelineRunning
                    logs    = $Global:LogBuffer.ToArray()
                }
                $JsonPayload = $StreamObj | ConvertTo-Json -Compress
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/run" -and $Method -eq "POST") {
                $ExecutionMode = $Request.QueryString["mode"]
                if ([string]::IsNullOrEmpty($ExecutionMode)) { $ExecutionMode = "sync" }
                
                if (-not $Global:IsPipelineRunning) {
                    Invoke-PipelineExecution -Type $ExecutionMode
                }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}')
                $Response.ContentType = "application/json"
                $Response.ContentLength64 = $Buffer.Length
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            else { $Response.StatusCode = 404 }
            $Response.OutputStream.Close()
        } catch {}
    }
}
finally {
    if ($null -ne $Listener) {
        $Listener.Stop()
        $Listener.Close()
    }
}