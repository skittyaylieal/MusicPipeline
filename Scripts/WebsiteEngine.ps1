Param (
    [string]$BackupDir = "C:\Users\filip\Music\YT_Music_Backup",
    [string]$MobileDir = "C:\Users\filip\Music\YT_Music_Mobile",
    [string]$BatchScript = "C:\MusicTools\MusicPipeline\sync_music.bat"
)

# Global memory variable to hold active live log stream data
$Global:LogBuffer = New-Object System.Collections.Generic.List[string]
$Global:IsPipelineRunning = $false

# -----------------------------------------------------------------
# 1. HELPER FUNCTION: SCAN STORAGE FOOTPRINT & METADATA INDEX
# -----------------------------------------------------------------
function Get-LibraryMetrics {
    if (-not (Test-Path -LiteralPath $BackupDir)) { return @{} }

    $MasterFiles = Get-ChildItem -LiteralPath $BackupDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }
    $MobileFiles = Get-ChildItem -LiteralPath $MobileDir -Recurse -File | Where-Object { $_.Extension -match "m4a" }
    $LrcFiles    = Get-ChildItem -LiteralPath $BackupDir -Recurse -Filter "*.lrc" -File

    # Calculate Sizes safely
    $MasterSize = ($MasterFiles | Measure-Object -Property Length -Sum).Sum / 1GB
    $MobileSize = ($MobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB

    # Build searchable track metadata array
    $TrackDatabase = @()
    foreach ($File in $MasterFiles) {
        $RelativePath = $File.FullName.Substring($BackupDir.Length).TrimStart('\')
        $PathParts = $RelativePath -split '\\'
        
        # Extrapolate structured metadata from standard directory tree layout
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
        tracks      = $TrackDatabase
    }
}

# -----------------------------------------------------------------
# 2. HELPER FUNCTION: EXECUTE PIPELINE WITH OUTPUT INTERCEPTION
# -----------------------------------------------------------------
function Invoke-PipelineExecution {
    if ($Global:IsPipelineRunning) { return }
    $Global:IsPipelineRunning = $true
    $Global:LogBuffer.Clear()
    $Global:LogBuffer.Add("[SYSTEM] Initializing Master Execution Loop...")

    # Build a clean background block payload to feed into a separate thread
    $JobScript = {
        param($ScriptPath)
        
        $ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessInfo.FileName = "cmd.exe"
        $ProcessInfo.Arguments = "/c `"$ScriptPath`" headless"
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.CreateNoWindow = $true

        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessInfo
        
        [void]$Process.Start()

        # Stream output text lines back up continuously while the process is alive
        while (-not $Process.StandardOutput.EndOfStream) {
            $Line = $Process.StandardOutput.ReadLine()
            if ($Line) { $Line }
        }
        while (-not $Process.StandardError.EndOfStream) {
            $ErrLine = $Process.StandardError.ReadLine()
            if ($ErrLine) { "[ERROR] " + $ErrLine }
        }

        $Process.WaitForExit()
        return "[SYSTEM] Pipeline task finalized with code: $($Process.ExitCode)"
    }

    # Launch the execution script as an independent local background job
    $Job = Start-Job -ScriptBlock $JobScript -ArgumentList $BatchScript

    # Monitor the job's returned echo data stream asynchronously without locking up the server
    $null = Register-ObjectEvent -InputObject $Job -EventName "StateChanged" -Action {
        if ($Event.SourceEventArgs.JobStateInfo.State -eq "Completed") {
            $Results = Receive-Job -Job $Job
            foreach ($Row in $Results) {
                if ($Row) { $Global:LogBuffer.Add($Row) }
            }
            Remove-Job -Job $Job
            $Global:IsPipelineRunning = $false
            Unregister-Event -SourceIdentifier $Event.SourceIdentifier
        }
    }

    # Regularly pull incremental output updates into the console stream
    Task {
        while ($Global:IsPipelineRunning) {
            $Data = Receive-Job -Job $Job
            foreach ($Line in $Data) {
                if ($Line) { $Global:LogBuffer.Add($Line) }
            }
            Start-Sleep -Seconds 1
        }
    }
}

# -----------------------------------------------------------------
# 3. CORE FRONTEND DASHBOARD INTERFACE ASSET (HTML/CSS/JS)
# -----------------------------------------------------------------
$HtmlDashboard = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Music Pipeline Master Console</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #0F0F11; color: #E2E8F0; margin: 0; padding: 25px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-bottom: 25px; }
        .card { background: #18181C; padding: 20px; border-radius: 10px; border: 1px solid #27272A; text-align: center; }
        .card h3 { margin: 0; color: #A1A1AA; font-size: 0.9em; text-transform: uppercase; letter-spacing: 0.5px; }
        .card .value { font-size: 2em; font-weight: bold; margin: 10px 0; color: #00ADB5; }
        .main-layout { display: grid; grid-template-columns: 1fr 1fr; gap: 25px; height: calc(100vh - 180px); }
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

    <div class="grid">
        <div class="card"><h3>Master Tracks</h3><div class="value" id="stat-master-count">-</div></div>
        <div class="card"><h3>Mobile Storage</h3><div class="value" id="stat-mobile-count">-</div></div>
        <div class="card"><h3>Lyrics Index</h3><div class="value" id="stat-lrc-count">-</div></div>
        <div class="card"><h3>Storage Weights</h3><div class="value" id="stat-sizes">-</div></div>
    </div>

    <div class="main-layout">
        <div class="panel">
            <h2>Execution Pipeline <button class="btn" id="run-btn" onclick="triggerPipeline()">Run Master Sync</button></h2>
            <div class="console" id="terminal-feed">Terminal offline. Awaiting pipeline run initialization...</div>
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
                        <tr><td colspan="4" style="text-align:center; color:#71717A;">Initializing index scan...</td></tr>
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
                    document.getElementById('stat-master-count').innerText = `\${data.masterCount} files`;
                    document.getElementById('stat-mobile-count').innerText = `\${data.mobileCount} compressed`;
                    document.getElementById('stat-lrc-count').innerText = `\${data.lrcCount} synced`;
                    document.getElementById('stat-sizes').innerText = `\${data.mobileSize} GB / \${data.masterSize} GB`;
                    
                    fullTrackDb = data.tracks || [];
                    buildTable(fullTrackDb);
                });
        }

        function buildTable(tracks) {
            const tbody = document.getElementById('metadata-rows');
            if(tracks.length === 0) {
                tbody.innerHTML = `<tr><td colspan="4" style="text-align:center; color:#71717A;">No records match query bounds</td></tr>`;
                return;
            }
            tbody.innerHTML = tracks.map(t => `
                <tr>
                    <td><strong>\${t.title}</strong> <span style="color:#71717A; font-size:0.8em;">(\${t.type})</span></td>
                    <td>\${t.artist}</td>
                    <td>\${t.album}</td>
                    <td>\${t.hasLrc ? '<span class="badge badge-lrc">LRC</span>' : '<span class="badge badge-missing">TXT/NONE</span>'}</td>
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

        function triggerPipeline() {
            document.getElementById('run-btn').disabled = true;
            fetch('/run', { method: 'POST' });
        }

        // Long poll connection looping frame to handle immediate log updates
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
                });
        } , 1000);

        // Initial Load frame dispatch
        loadMetrics();
    </script>
</body>
</html>
"@





# -----------------------------------------------------------------
# 3.5 AUTOMATIC BACKGROUND TIMER (Every 30 Minutes)
# -----------------------------------------------------------------
$TimerScript = {
    param($EngineUrl)
    while ($true) {
        # Sleep for 30 minutes (1800 seconds)
        Start-Sleep -Seconds 1800
        
        # Poke the website engine to start an automated sync run
        try {
            Invoke-RestMethod -Uri "$EngineUrl`run" -Method Post | Out-Null
        } catch {
            # Webserver might be temporarily busy or recycling; ignore and wait for next loop
        }
    }
}
# Start the timer process as an independent background script job
$null = Start-Job -ScriptBlock $TimerScript -ArgumentList "http://localhost:8080/"






# -----------------------------------------------------------------
# 4. HTTP LISTENER CORE SERVER TERMINAL ROUTING LOOP
# -----------------------------------------------------------------
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:8080/")
try { $Listener.Start() } catch {
    Write-Host "[!] Port 8080 occupied. Shutdown active process tracks before spinning up console console app engine." -ForegroundColor Red
    Exit 1
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "     Master Console Server Engine Live on http://localhost:8080" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "[*] Open your browser and navigate to http://localhost:8080 to access your dashboard." -ForegroundColor Yellow

$Running = $true
while ($Running) {
    try {
        $Context = $Listener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        $UrlPath = $Request.Url.LocalPath
        $Method  = $Request.HttpMethod

        # ROUTE A: BASE ENTRYPOINT (Load Master Panel App HTML UI Frame)
        if ($UrlPath -eq "/" -and $Method -eq "GET") {
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlDashboard)
            $Response.ContentType = "text/html; charset=utf-8"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        # ROUTE B: TRACKS DATA & SYSTEM STRUCTURAL METRICS (JSON Payload)
        elif ($UrlPath -eq "/metrics" -and $Method -eq "GET") {
            $DataMetrics = Get-LibraryMetrics
            $JsonPayload = $DataMetrics | ConvertTo-Json -Depth 4 -Compress
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        # ROUTE C: INTERCEPT TERMINAL LOG STREAM BUFFER ARRAY
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
        # ROUTE D: TRIGGER LIVE PIPELINE RUN
        elif ($UrlPath -eq "/run" -and $Method -eq "POST") {
            if (-not $Global:IsPipelineRunning) {
                Invoke-PipelineExecution
            }
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}')
            $Response.ContentType = "application/json"
            $Response.ContentLength64 = $Buffer.Length
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        else {
            $Response.StatusCode = 404
        }
        $Response.OutputStream.Close()
    }
    catch {
        # Catch connection drops quietly so server process loop doesn't fail
    }
}

$Listener.Stop()