Param (
    [string]$BackupDir = "C:\Users\filip\Music\YT_Music_Backup",
    [string]$MobileDir = "C:\Users\filip\Music\YT_Music_Mobile",
    [string]$BatchScript = "C:\MusicTools\MusicPipeline\sync_music.bat"
)

# Global variables and runtime states
$Global:IsPipelineRunning = $false
$Global:DiagLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"
$Global:CacheFile = "C:\MusicTools\MusicPipeline\Config\dashboard_cache.json"
$ScriptRepoDir = [System.IO.Path]::GetDirectoryName($BatchScript)

# Create config directory if it doesn't exist
$ConfigDir = Split-Path $Global:DiagLogFile
if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force }

# Shared Default Memory Container
$Global:CachedMetrics = @{
    masterCount = 0; mobileCount = 0; lrcCount = 0
    masterSize  = 0; mobileSize  = 0; alerts = @(); tracks = @()
}

# -----------------------------------------------------------------
# 1. ROBUST BACKGROUND SCANNER (Asynchronous Processing Layout)
# -----------------------------------------------------------------
function Start-AsyncLibraryScanner {
    Get-Job -Name "MusicFolderScanner" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

    $JobScript = {
        param($BDir, $MDir, $RDir, $CFile)
        
        Start-Sleep -Seconds 2
        while ($true) {
            if (-not (Test-Path -LiteralPath $BDir)) { Start-Sleep -Seconds 5; continue }

            $MasterFiles = Get-ChildItem -LiteralPath $BDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }
            $MobileFiles = Get-ChildItem -LiteralPath $MDir -Recurse -File | Where-Object { $_.Extension -match "m4a" }
            $LrcFiles    = Get-ChildItem -LiteralPath $BDir -Recurse -Filter "*.lrc" -File

            $MasterSize = ($MasterFiles | Measure-Object -Property Length -Sum).Sum / 1GB
            $MobileSize = ($MobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB

            $Alerts = @()
            if (Test-Path -LiteralPath "$RDir\.git") {
                try {
                    $Env:GIT_TERMINAL_PROMPT = "0"
                    $Env:GIT_SSH_COMMAND = ""
                    Push-Location $RDir
                    [void](git -c network.timeout=3 fetch origin main 2>&1)
                    if ((git rev-parse HEAD).Trim() -ne (git rev-parse "@{upstream}").Trim()) {
                        $Alerts += @{ type = "warning"; message = "Repository Update Available: Changes pushed from Mac are ready."; fixAction = "gitpull" }
                    }
                    Pop-Location
                } catch {}
            }

            if ($MasterFiles.Count -gt $MobileFiles.Count) {
                $Alerts += @{ type = "danger"; message = "Synchronization Gap: Master backup has $(($MasterFiles.Count - $MobileFiles.Count)) more track(s) than Mobile."; fixAction = "sync" }
            }

            # Build metadata lookup array layout
            $TrackDatabase = @()
            foreach ($File in $MasterFiles) {
                if ($null -eq $File.FullName) { continue }
                $RelativePath = $File.FullName.Substring($BDir.Length).TrimStart('\')
                $PathParts = $RelativePath -split '\\'
                $Artist = if ($PathParts.Count -ge 3) { $PathParts[0] } else { "Unknown Artist" }
                $Album  = if ($PathParts.Count -ge 3) { $PathParts[1] } else { "Single / Unknown" }
                
                $TrackDatabase += @{
                    title  = [string]$File.BaseName
                    artist = [string]$Artist
                    album  = [string]$Album
                    sizeMb = [Math]::Round(($File.Length / 1MB), 2)
                    hasLrc = [bool](Test-Path -LiteralPath "$($File.DirectoryName)\$($File.BaseName).lrc" -ErrorAction SilentlyContinue)
                    type   = [string]$File.Extension.ToUpper().Replace('.','')
                }
            }

            @{
                masterCount = $MasterFiles.Count
                mobileCount = $MobileFiles.Count
                lrcCount    = $LrcFiles.Count
                masterSize  = [Math]::Round($MasterSize, 2)
                mobileSize  = [Math]::Round($MobileSize, 2)
                alerts      = $Alerts
                tracks      = $TrackDatabase
            } | ConvertTo-Json -Depth 4 | Out-File -FilePath $CFile -Encoding utf8 -Force
Param (
    [string]$BackupDir = "C:\Users\filip\Music\YT_Music_Backup",
    [string]$MobileDir = "C:\Users\filip\Music\YT_Music_Mobile",
    [string]$BatchScript = "C:\MusicTools\MusicPipeline\sync_music.bat"
)

# Global variables and runtime states
$Global:IsPipelineRunning = $false
$Global:DiagLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log"
$Global:CacheFile = "C:\MusicTools\MusicPipeline\Config\dashboard_cache.json"
$ScriptRepoDir = [System.IO.Path]::GetDirectoryName($BatchScript)

# Create config directory if it doesn't exist
$ConfigDir = Split-Path $Global:DiagLogFile
if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force }

# Shared Default Memory Container
$Global:CachedMetrics = @{
    masterCount = 0; mobileCount = 0; lrcCount = 0
    masterSize  = 0; mobileSize  = 0; alerts = @(); tracks = @()
}

# -----------------------------------------------------------------
# 1. ROBUST BACKGROUND SCANNER (Asynchronous Processing Layout)
# -----------------------------------------------------------------
function Start-AsyncLibraryScanner {
    Get-Job -Name "MusicFolderScanner" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

    $JobScript = {
        param($BDir, $MDir, $RDir, $CFile)
        
        Start-Sleep -Seconds 2
        while ($true) {
            if (-not (Test-Path -LiteralPath $BDir)) { Start-Sleep -Seconds 5; continue }

            $MasterFiles = Get-ChildItem -LiteralPath $BDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }
            $MobileFiles = Get-ChildItem -LiteralPath $MDir -Recurse -File | Where-Object { $_.Extension -match "m4a" }
            $LrcFiles    = Get-ChildItem -LiteralPath $BDir -Recurse -Filter "*.lrc" -File

            $MasterSize = ($MasterFiles | Measure-Object -Property Length -Sum).Sum / 1GB
            $MobileSize = ($MobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB

            $Alerts = @()
            if (Test-Path -LiteralPath "$RDir\.git") {
                try {
                    $Env:GIT_TERMINAL_PROMPT = "0"
                    $Env:GIT_SSH_COMMAND = ""
                    Push-Location $RDir
                    [void](git -c network.timeout=3 fetch origin main 2>&1)
                    if ((git rev-parse HEAD).Trim() -ne (git rev-parse "@{upstream}").Trim()) {
                        $Alerts += @{ type = "warning"; message = "Repository Update Available: Changes pushed from Mac are ready."; fixAction = "gitpull" }
                    }
                    Pop-Location
                } catch {}
            }

            if ($MasterFiles.Count -gt $MobileFiles.Count) {
                $Alerts += @{ type = "danger"; message = "Synchronization Gap: Master backup has $(($MasterFiles.Count - $MobileFiles.Count)) more track(s) than Mobile."; fixAction = "sync" }
            }

            # Build metadata lookup array layout
            $TrackDatabase = @()
            foreach ($File in $MasterFiles) {
                if ($null -eq $File.FullName) { continue }
                $RelativePath = $File.FullName.Substring($BDir.Length).TrimStart('\')
                $PathParts = $RelativePath -split '\\'
                $Artist = if ($PathParts.Count -ge 3) { $PathParts[0] } else { "Unknown Artist" }
                $Album  = if ($PathParts.Count -ge 3) { $PathParts[1] } else { "Single / Unknown" }
                
                $TrackDatabase += @{
                    title  = [string]$File.BaseName
                    artist = [string]$Artist
                    album  = [string]$Album
                    sizeMb = [Math]::Round(($File.Length / 1MB), 2)
                    hasLrc = [bool](Test-Path -LiteralPath "$($File.DirectoryName)\$($File.BaseName).lrc" -ErrorAction SilentlyContinue)
                    type   = [string]$File.Extension.ToUpper().Replace('.','')
                }
            }

            @{
                masterCount = $MasterFiles.Count
                mobileCount = $MobileFiles.Count
                lrcCount    = $LrcFiles.Count
                masterSize  = [Math]::Round($MasterSize, 2)
                mobileSize  = [Math]::Round($MobileSize, 2)
                alerts      = $Alerts
                tracks      = $TrackDatabase
            } | ConvertTo-Json -Depth 4 | Out-File -FilePath $CFile -Encoding utf8 -Force

            Start-Sleep -Seconds 60
        }
    }

    Start-Job -Name "MusicFolderScanner" -ScriptBlock $JobScript -ArgumentList $BackupDir, $MobileDir, $ScriptRepoDir, $Global:CacheFile
}

# -----------------------------------------------------------------
# 2. PROCESS MANAGEMENT WORKERS
# -----------------------------------------------------------------
function Invoke-PipelineExecution {
    if ($Global:IsPipelineRunning) { return }
    $Global:IsPipelineRunning = $true
    
    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
    "[SYSTEM] Dispatching background process worker..." | Out-File -FilePath $Global:DiagLogFile -Encoding utf8

    $PipelineJob = {
        param($ScriptPath, $RepoDir, $OutputFile)
        Set-Location -LiteralPath $RepoDir
        & "$env:SystemRoot\System32\cmd.exe" /c "`"$ScriptPath`" headless" > $OutputFile 2>&1
    }
    
    $Job = Start-Job -ScriptBlock $PipelineJob -ArgumentList $BatchScript, $ScriptRepoDir, $Global:DiagLogFile
}

function Invoke-HotReload {
    if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force }
    "[SYSTEM] Hot-reload triggered. Executing Git Pull..." | Out-File -FilePath $Global:DiagLogFile -Encoding utf8
    Push-Location $ScriptRepoDir
    try {
        $Env:GIT_TERMINAL_PROMPT = "0"
        $Env:GIT_SSH_COMMAND = ""
        & "git" pull origin main >> $Global:DiagLogFile 2>&1
    } catch {}
    Pop-Location
}

# HTML Dashboard Asset - Optimized Polling Frequencies
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
        .btn-warn { background: #D97706; }
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
            <h2>Execution Pipeline <button class="btn" id="run-btn" onclick="triggerPipeline()">Run Master Sync</button></h2>
            <div class="console" id="terminal-feed">Ready. Awaiting run commands...</div>
        </div>
        <div class="panel">
            <h2>Archive Metadata Navigator</h2>
            <input type="text" class="search-box" id="search-input" placeholder="Search archive by title, artist, or album..." onkeyup="filterDatabase()">
            <div class="table-wrapper">
                <table>
                    <thead><tr><th>Track Title</th><th>Artist</th><th>Album</th><th>Lyrics</th></tr></thead>
                    <tbody id="metadata-rows"><tr><td colspan="4" style="text-align:center; color:#71717A;">Scanning directory layouts asynchronously...</td></tr></tbody>
                </table>
            </div>
        </div>
    </div>
    <script>
        let fullTrackDb = [];
        let isPipelineActive = false;

        function loadMetrics() {
            fetch('/metrics').then(res => res.json()).then(data => {
                document.getElementById('stat-master-count').innerText = `${data.masterCount} files`;
                document.getElementById('stat-mobile-count').innerText = `${data.mobileCount} compressed`;
                document.getElementById('stat-lrc-count').innerText = `${data.lrcCount} synced`;
                document.getElementById('stat-sizes').innerText = `${data.mobileSize} GB / ${data.masterSize} GB`;
                const alertZone = document.getElementById('alerts-zone');
                if (data.alerts && data.alerts.length > 0) {
                    alertZone.innerHTML = data.alerts.map(a => {
                        if (a.fixAction === "gitpull") return `<div class="alert alert-${a.type}"><span>⚠️ ${a.message}</span><button class="btn btn-warn" onclick="triggerPull()">Pull & Hot-Reload Script</button></div>`;
                        return `<div class="alert alert-${a.type}"><span>⚠️ ${a.message}</span></div>`;
                    }).join('');
                } else { alertZone.innerHTML = ''; }
                if(data.tracks && data.tracks.length > 0 && fullTrackDb.length !== data.tracks.length) {
                    fullTrackDb = data.tracks;
                    buildTable(fullTrackDb);
                }
            }).catch(() => {});
        }

        function buildTable(tracks) {
            const tbody = document.getElementById('metadata-rows');
            if(!tracks || tracks.length === 0) {
                tbody.innerHTML = `<tr><td colspan="4" style="text-align:center; color:#71717A;">Scanning directory layouts asynchronously...</td></tr>`;
                return;
            }
            tbody.innerHTML = tracks.map(t => `<tr><td><strong>${t.title}</strong> <span style="color:#71717A; font-size:0.8em;">(${t.type})</span></td><td>${t.artist}</td><td>${t.album}</td><td>${t.hasLrc ? '<span class="badge badge-lrc">LRC</span>' : '<span class="badge badge-missing">TXT/NONE</span>'}</td></tr>`).join('');
        }

        function filterDatabase() {
            const query = document.getElementById('search-input').value.toLowerCase();
            const filtered = fullTrackDb.filter(t => t.title.toLowerCase().includes(query) || t.artist.toLowerCase().includes(query) || t.album.toLowerCase().includes(query));
            buildTable(filtered);
        }

        function triggerPipeline() { 
            document.getElementById('run-btn').disabled = true; 
            isPipelineActive = true;
            fetch('/run', { method: 'POST' }); 
        }
        function triggerPull() { fetch('/pull', { method: 'POST' }); }

        // Adaptive polling loop: 1s during sync execution, 4s when quiet
        function runLogStreamer() {
            fetch('/stream').then(res => res.json()).then(data => {
                isPipelineActive = data.running;
                document.getElementById('run-btn').disabled = data.running;
                if(data.logs && data.logs.length > 0) {
                    const consoleBox = document.getElementById('terminal-feed');
                    consoleBox.innerText = data.logs.join('\n');
                    consoleBox.scrollTop = consoleBox.scrollHeight;
                }
                setTimeout(runLogStreamer, isPipelineActive ? 1000 : 4000);
            }).catch(() => {
                setTimeout(runLogStreamer, 4000);
            });
        }

        setInterval(loadMetrics, 8000);
        setTimeout(runLogStreamer, 1000);
        loadMetrics();
    </script>
</body>
</html>
'@

# -----------------------------------------------------------------
# 3. NETWORK ENGINE ROUTER ROUTINE
# -----------------------------------------------------------------
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:8080/")

try {
    $Listener.Start()
    Start-AsyncLibraryScanner
    
    while ($true) {
        try {
            $Context = $Listener.GetContext()
            $Request = $Context.Request
            $Response = $Context.Response
            $UrlPath = $Request.Url.LocalPath
            $Method  = $Request.HttpMethod

            $Response.KeepAlive = $false
            $Response.Headers.Add("Connection", "close")

            if ($UrlPath -eq "/" -and $Method -eq "GET") {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlDashboard)
                $Response.ContentType = "text/html; charset=utf-8"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/metrics" -and $Method -eq "GET") {
                if (Test-Path $Global:CacheFile) {
                    try {
                        $RawJson = Get-Content -LiteralPath $Global:CacheFile -Raw -ErrorAction SilentlyContinue
                        if ($RawJson) { $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawJson) }
                    } catch {
                        $JsonPayload = $Global:CachedMetrics | ConvertTo-Json -Depth 4 -Compress
                        $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                    }
                } else {
                    $JsonPayload = $Global:CachedMetrics | ConvertTo-Json -Depth 4 -Compress
                    $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                }
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/stream" -and $Method -eq "GET") {
                $CurrentLogs = @()
                if (Test-Path $Global:DiagLogFile) { $CurrentLogs = Get-Content -LiteralPath $Global:DiagLogFile -ErrorAction SilentlyContinue }
                if ($CurrentLogs -match "Execution complete|completed successfully") {
                    $Global:IsPipelineRunning = $false
                }
                $JsonPayload = @{ running = $Global:IsPipelineRunning; logs = $CurrentLogs } | ConvertTo-Json -Compress
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/run" -and $Method -eq "POST") {
                Invoke-PipelineExecution
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}')
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            elif ($UrlPath -eq "/pull" -and $Method -eq "POST") {
                Invoke-HotReload
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"pulling"}')
                $Response.ContentType = "application/json"
                $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
            }
            else { $Response.StatusCode = 404 }
            $Response.OutputStream.Close()
        } catch {}
    }
} finally {
    if ($null -ne $Listener) { $Listener.Stop(); $Listener.Close() }
}
set="UTF-8">
    <title>Music Pipeline Master Console</title>
    <style>
        body { font-family: 'Segoe UI', sans-serif; background: #0F0F11; color: #E2E8F0; margin: 0; padding: 25px; }
        .alert-container { margin-bottom: 20px; }
        .alert { padding: 15px 20px; border-radius: 6px; margin-bottom: 10px; font-size: 0.95em; display: flex; justify-content: space-between; align-items: center; font-weight: 500; }
        .alert-danger { background: #4C1D1D; color: #F87171; border: 1px solid #7F1D1D; }
        .alert-warning { background: #453015; color: #FBBF24; border: 1px solid #78350F; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 20px; margin-bottom: 25px; }
        .card { background: #18181C; padding: 20px; border-radius: 10px; border: 1px solid #27272A; text-align: center; }
        .card h3 { margin: 0; color: #A1A1AA; font-size: 0.9em; text-transform: uppercase; letter
