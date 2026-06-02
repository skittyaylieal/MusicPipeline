Param (
    [string]$ConfigDir,
    [string]$HistoryPath,
    [string]$FirefoxPath
)

$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Headless Link Auditor" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

$QueueFile = "$ConfigDir\audit_queue.json"
$HtmlPath  = "$ConfigDir\music_audit.html"
$ShortcutPath = "$env:USERPROFILE\Desktop\Review Broken Music.url"

$IsHeadless = (Get-Process -Id $PID).SessionId -eq 0

if ($IsHeadless) {
    Write-Host "[*] Headless execution environment verified. Scanning logs..." -ForegroundColor Yellow
    
    $ErrorLogs = Get-ChildItem -LiteralPath $ConfigDir -Filter "playlist*_errors.txt"
    if (-not $ErrorLogs) { 
        $MetricStopwatch.Stop()
        Write-Host "[METRIC] 00:00:00"
        Exit 0 
    }

    $Queue = @()
    if (Test-Path -LiteralPath $QueueFile) {
        try { $Queue = Get-Content -LiteralPath $QueueFile -Raw | ConvertFrom-Json } catch { $Queue = @() }
    }

    $VideoIdRegex = 'ERROR:\s*\[youtube\]\s*([a-zA-Z0-9_-]{11}):'

    foreach ($Log in $ErrorLogs) {
        if ((Get-Item -LiteralPath $Log.FullName).Length -eq 0) { continue }
        $Content = Get-Content -LiteralPath $Log.FullName
        foreach ($Line in $Content) {
            if ($Line -match $VideoIdRegex) {
                $Id = $Matches[1]
                $AlreadyExists = $false
                foreach ($Item in $Queue) {
                    if ($Item.id -eq $Id) { $AlreadyExists = $true; break }
                }
                if (-not $AlreadyExists) {
                    $Queue += [PSCustomObject]@{
                        id    = $Id
                        error = $Line.Trim()
                    }
                }
            }
        }
    }

    if ($Queue.Count -eq 0) {
        if (Test-Path -LiteralPath $ShortcutPath) { Remove-Item -LiteralPath $ShortcutPath -Force }
        $MetricStopwatch.Stop()
        $Elapsed = [string]::Format("{0:hh\:mm\:ss}", $MetricStopwatch.Elapsed)
        Write-Host "[METRIC] $Elapsed"
        Exit 0
    }

    $Queue | ConvertTo-Json | Out-File -LiteralPath $QueueFile -Encoding utf8

    $ShortcutContent = @"
[InternetShortcut]
URL=$HtmlPath
IconIndex=0
IconFile=$FirefoxPath
"@
    $ShortcutContent | Out-File -LiteralPath $ShortcutPath -Encoding ascii
    
    Write-Host "[+] Background extraction complete. Queue saved with $($Queue.Count) links." -ForegroundColor Green
    $MetricStopwatch.Stop()
    $Elapsed = [string]::Format("{0:hh\:mm\:ss}", $MetricStopwatch.Elapsed)
    Write-Host "[METRIC] $Elapsed"
    Write-Host "=============================================" -ForegroundColor Cyan
    Exit 0
}

# MODE B: INTERACTIVE REVIEW PLATFORM (When run manually by you)
Write-Host "[*] Interactive console detected. Launching local API engine..." -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $QueueFile)) {
    Write-Host "[+] No audit data found. Queue file is missing." -ForegroundColor Green
    $MetricStopwatch.Stop()
    Write-Host "[METRIC] 00:00:00"
    Exit 0
}

$Queue = Get-Content -LiteralPath $QueueFile -Raw | ConvertFrom-Json
if ($Queue.Count -eq 0) {
    Write-Host "[+] Audit queue is completely empty!" -ForegroundColor Green
    if (Test-Path -LiteralPath $ShortcutPath) { Remove-Item -LiteralPath $ShortcutPath -Force }
    $MetricStopwatch.Stop()
    Write-Host "[METRIC] 00:00:00"
    Exit 0
}

$JsonQueueData = $Queue | ConvertTo-Json -Compress

$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Music Link Auditor</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #121212; color: #E0E0E0; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background: #1E1E1E; padding: 30px; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); text-align: center; max-width: 500px; width: 100%; border: 1px solid #333; }
        h2 { color: #00ADB5; margin-top: 0; }
        .counter { font-size: 0.9em; color: #888; margin-bottom: 20px; }
        .id-box { background: #2D2D2D; padding: 12px; border-radius: 6px; font-family: monospace; font-size: 1.2em; color: #FFD369; margin-bottom: 15px; word-break: break-all; }
        .error-log { background: #251B1B; border: 1px solid #5C2D2D; color: #FF6B6B; padding: 12px; border-radius: 6px; font-family: monospace; font-size: 0.85em; text-align: left; margin-bottom: 25px; word-break: break-word; max-height: 100px; overflow-y: auto; }
        .btn { display: block; width: 100%; padding: 12px; margin: 10px 0; border: none; border-radius: 6px; font-size: 1em; font-weight: bold; cursor: pointer; transition: opacity 0.2s; }
        .btn:hover { opacity: 0.9; }
        .btn-launch { background: #00ADB5; color: #FFF; }
        .btn-fixed { background: #4E9F3D; color: #FFF; }
        .btn-ok { background: #393E46; color: #FFF; }
        .btn-skip { background: #D63447; color: #FFF; }
        .hidden { display: none; }
    </style>
</head>
<body>
    <div class="card" id="main-view">
        <h2>Music Link Auditor</h2>
        <div class="counter" id="progress">Loading...</div>
        <div class="id-box" id="video-id">---</div>
        <div class="error-log" id="error-text">---</div>
        <button class="btn btn-launch" onclick="openTrack()">1. Open Video Link</button>
        <hr style="border:0; border-top:1px solid #333; margin:20px 0;">
        <button class="btn btn-fixed" onclick="submitAction('fixed')">2. Fixed (New Track Sourced)</button>
        <button class="btn btn-ok" onclick="submitAction('ignore')">3. Broken but OK (Ignore Future Runs)</button>
        <button class="btn btn-skip" onclick="submitAction('skip')">4. Skip / Leave for Next Time</button>
    </div>
    <div class="card hidden" id="done-view">
        <h2>Session Complete</h2>
        <p>All items evaluated. This webpage and the desktop shortcut can now be closed.</p>
    </div>
    <script>
        const queue = $JsonQueueData;
        let index = 0;
        function render() {
            if (index >= queue.length) {
                document.getElementById('main-view').classList.add('hidden');
                document.getElementById('done-view').classList.remove('hidden');
                fetch('http://localhost:8080/shutdown');
                return;
            }
            document.getElementById('progress').innerText = `Item \${index + 1} of \${queue.length}`;
            document.getElementById('video-id').innerText = queue[index].id;
            document.getElementById('error-text').innerText = queue[index].error || "No raw diagnostic log available.";
        }
        function openTrack() {
            window.open('https://www.youtube.com/watch?v=' + queue[index].id, '_blank');
        }
        function submitAction(actionType) {
            const currentId = queue[index].id;
            fetch(`http://localhost:8080/submit?id=\${currentId}&action=\${actionType}`)
                .then(() => {
                    index++;
                    render();
                })
                .catch(err => alert('Communication with local PowerShell engine dropped: ' + err));
        }
        render();
    </script>
</body>
</html>
"@
$HtmlContent | Out-File -LiteralPath $HtmlPath -Encoding utf8

$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:8080/")
try { $Listener.Start() } catch {
    Write-Host "[!] Port 8080 occupied. Is another instance of the deck running?" -ForegroundColor Red
    Exit 1
}

Write-Host "[+] Local database engine loop listening on port 8080." -ForegroundColor Green
Write-Host "[*] Spawning Firefox interface panel..." -ForegroundColor Yellow
Start-Process -FilePath $FirefoxPath -ArgumentList "`"$HtmlPath`""

$Looping = $true
while ($Looping) {
    $Context = $Listener.GetContext()
    $Request = $Context.Request
    $Response = $Context.Response
    $Url = $Request.Url.LocalPath
    $Query = $Request.QueryString

    if ($Url -eq "/submit") {
        $TargetID = $Query["id"]
        $Action   = $Query["action"]

        if ($Action -eq "fixed" -or $Action -eq "ignore") {
            "youtube $TargetID" | Out-File -LiteralPath $HistoryPath -Append -Encoding ascii
            Write-Host "[ARCHIVED] Successfully added ID: $TargetID to history." -ForegroundColor Green
        } else {
            Write-Host "[SKIPPED] Track $TargetID skipped by user choice." -ForegroundColor Yellow
        }

        $Queue = $Queue | Where-Object { $_.id -ne $TargetID }
        if ($Queue) {
            $Queue | ConvertTo-Json | Out-File -LiteralPath $QueueFile -Encoding utf8
        } else {
            if (Test-Path -LiteralPath $QueueFile) { Remove-Item -LiteralPath $QueueFile -Force }
            if (Test-Path -LiteralPath $ShortcutPath) { Remove-Item -LiteralPath $ShortcutPath -Force }
        }
        $Buffer = [System.Text.Encoding]::UTF8.GetBytes("OK")
        $Response.ContentLength64 = $Buffer.Length
        $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        $Response.OutputStream.Close()
    }
    elseif ($Url -eq "/shutdown") {
        $Buffer = [System.Text.Encoding]::UTF8.GetBytes("Goodbye")
        $Response.ContentLength64 = $Buffer.Length
        $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        $Response.OutputStream.Close()
        $Looping = $false
    }
}
$Listener.Stop()
$MetricStopwatch.Stop()
$Elapsed = [string]::Format("{0:hh\:mm\:ss}", $MetricStopwatch.Elapsed)
Write-Host "[METRIC] $Elapsed"
Write-Host "=============================================" -ForegroundColor Cyan
Exit 0