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
    masterCount = 0
    mobileCount = 0
    lrcCount    = 0
    masterSize  = 0
    mobileSize  = 0
    alerts      = @()
}

# -----------------------------------------------------------------
# 1. LIGHTWEIGHT BACKGROUND SCANNER (PowerShell 5.1 Bulletproof)
# -----------------------------------------------------------------
function Start-AsyncLibraryScanner {
    Get-Job -Name "MusicFolderScanner" -ErrorAction SilentlyContinue | Remove-Job -Force -ErrorAction SilentlyContinue

    $JobScript = {
        param($BDir, $MDir, $RDir, $CFile)
        
        Start-Sleep -Seconds 2
        while ($true) {
            if (-not (Test-Path -LiteralPath $BDir)) { Start-Sleep -Seconds 5; continue }

            $MasterCount = (Get-ChildItem -LiteralPath $BDir -Recurse -File | Where-Object { $_.Extension -match "flac|mp3|m4a" }).Count
            $MobileCount = (Get-ChildItem -LiteralPath $MDir -Recurse -File | Where-Object { $_.Extension -match "m4a" }).Count
            $LrcCount    = (Get-ChildItem -LiteralPath $BDir -Recurse -Filter "*.lrc" -File).Count

            $MasterSize = (Get-ChildItem -LiteralPath $BDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
            $MobileSize = (Get-ChildItem -LiteralPath $MDir -Recurse -File | Where-Object { $_.Extension -match "m4a" } | Measure-Object -Property Length -Sum).Sum / 1GB

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

            if ($MasterCount -gt $MobileCount) {
                $Alerts += @{ type = "danger"; message = "Synchronization Gap: Master backup has $(($MasterCount - $MobileCount)) more track(s) than Mobile."; fixAction = "sync" }
            }

            @{
                masterCount = $MasterCount
                mobileCount = $MobileCount
                lrcCount    = $LrcCount
                masterSize  = [Math]::Round($MasterSize, 2)
                mobileSize  = [Math]::Round($MobileSize, 2)
                alerts      = $Alerts
            } | ConvertTo-Json -Depth 3 | Out-File -FilePath $CFile -Encoding utf8 -Force

            Start-Sleep -Seconds 30
        }
    }

    Start-Job -Name "MusicFolderScanner" -ScriptBlock $JobScript -ArgumentList $BackupDir, $MobileDir, $ScriptRepoDir, $Global:CacheFile
}

# -----------------------------------------------------------------
# 2. RUNTIME ACTIONS & EXECUTION ENGINE
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

# HTML Dashboard Asset
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
        .main-layout { display: grid; grid-template-columns: 1fr; gap: 25px; }
        .panel { background: #18181C; border-radius: 10px; border: 1px solid #27272A; padding: 20px; display: flex; flex-direction: column; }
        h2 { margin-top: 0; color: #FFF; font-size: 1.3em; border-bottom: 1px solid #27272A; padding-bottom: 10px; display: flex; justify-content: space-between; align-items: center; }
        .btn { background: #00ADB5; color: #FFF; border: none; padding: 10px 20px; border-radius: 5px; font-weight: bold; cursor: pointer; transition: opacity 0.2s; }
        .btn-warn { background: #D97706; }
        .btn:hover { opacity: 0.9; }
        .btn:disabled { background: #3F3F46; cursor: not-allowed; }
        .console { background: #09090B; border-radius: 6px; padding: 15px; font-family: monospace; font-size: 0.85em; color: #39FF14; overflow-y: auto; flex-grow: 1; white-space: pre-wrap; border: 1px solid #18181B; min-height: 350px; max-height: 500px; }
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
    </div>
    <script>
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
                        alertZone.innerHTML = data.alerts.map(a => {
                            if (a.fixAction === "gitpull") return `<div class="alert alert-${a.type}"><span>⚠️ ${a.message}</span><button class="btn btn-warn" onclick="triggerPull()">Pull & Hot-Reload Script</button></div>`;
                            return `<div class="alert alert-${a.type}"><span>⚠️ ${a.message}</span></div>`;
                        }).join('');
                    } else { alertZone.innerHTML = ''; }
                })
                .catch(() => {});
        }
        function triggerPipeline() { document.getElementById('run-btn').disabled = true; fetch('/run', { method: 'POST' }); }
        function triggerPull() { fetch('/pull', { method: 'POST' }); }
        
        setInterval(() => {
            fetch('/stream')
                .then(res => res.json())
                .then(data => {
                    document.getElementById('run-btn').disabled = data.running;
                    if(data.logs && data.logs.length > 0) {
                        const consoleBox = document.getElementById('terminal-feed');
                        consoleBox.innerText = data.logs.join('\n');
                        consoleBox.scrollTop = consoleBox.scrollHeight;
                    }
                })
                .catch(() => {});
        }, 1000);
        
        setInterval(loadMetrics, 5000);
        loadMetrics();
    </script>
</body>
</html>
'@

# -----------------------------------------------------------------
# 3. CORE WEB ENGINE LISTENER ROUTER LOOP
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

            # FORCE CONNECTION CLOSURE TO REMOVE FIREFOX "TRANSFERRING" HANG
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
                        $JsonPayload = $Global:CachedMetrics | ConvertTo-Json -Compress
                        $Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload)
                    }
                } else {
                    $JsonPayload = $Global:CachedMetrics | ConvertTo-Json -Compress
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