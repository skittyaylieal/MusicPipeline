Param (
    [string]$ConfigDir,
    [string]$HistoryPath,
    [string]$FirefoxPath
)

# Push old terminal content out of view
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Headless Link Auditor" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Define tracking file paths
$QueueFile = "$ConfigDir\audit_queue.json"
$HtmlPath  = "$ConfigDir\music_audit.html"
$ShortcutPath = "$env:USERPROFILE\Desktop\Review Broken Music.url"

# Detect if running in Session 0 (Headless / Task Scheduler background)
$IsHeadless = (Get-Process -Id $PID).SessionId -eq 0

# -----------------------------------------------------------------
# MODE A: UNATTENDED LOG EXTRACTION (Task Scheduler / Session 0)
# -----------------------------------------------------------------
if ($IsHeadless) {
    Write-Host "[*] Headless execution environment verified. Scanning logs..." -ForegroundColor Yellow
    
    $ErrorLogs = Get-ChildItem -LiteralPath $ConfigDir -Filter "playlist*_errors.txt"
    if (-not $ErrorLogs) { Exit 0 }

    # Load existing queue items so we don't drop items unresolved from previous runs
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
                if ($Queue -notcontains $Id) { $Queue += $Id }
            }
        }
    }

    # If nothing is broken, clean up old notifications and stop
    if ($Queue.Count -eq 0) {
        if (Test-Path -LiteralPath $ShortcutPath) { Remove-Item -LiteralPath $ShortcutPath -Force }
        Exit 0
    }

    # Save tracking data arrays natively
    $Queue | ConvertTo-Json | Out-File -LiteralPath $QueueFile -Encoding utf8

    # Create a Desktop shortcut notification wrapper pointing to our interface engine
    $TargetCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Normal -Command `"& '$PSCommandPath' -ConfigDir '$ConfigDir' -HistoryPath '$HistoryPath' -FirefoxPath '$FirefoxPath'`""
    $ShortcutContent = @"
[InternetShortcut]
URL=$HtmlPath
IconIndex=0
IconFile=$FirefoxPath
"@
    $ShortcutContent | Out-File -LiteralPath $ShortcutPath -Encoding ascii
    
    Write-Host "[+] Background extraction complete. Queue saved with $($Queue.Count) links." -ForegroundColor Green
    Exit 0
}

# -----------------------------------------------------------------
# MODE B: INTERACTIVE REVIEW PLATFORM (When run manually by you)
# -----------------------------------------------------------------
Write-Host "[*] Interactive console detected. Launching local API engine..." -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $QueueFile)) {
    Write-Host "[+] No audit data found. Queue file is missing." -ForegroundColor Green
    Exit 0
}

$Queue = Get-Content -LiteralPath $QueueFile -Raw | ConvertFrom-Json
if ($Queue.Count -eq 0) {
    Write-Host "[+] Audit queue is completely empty!" -ForegroundColor Green
    if (Test-Path -LiteralPath $ShortcutPath) { Remove-Item -LiteralPath $ShortcutPath -Force }
    Exit 0
}

# Generate the interactive HTML asset file inside the Config directory dynamically
$JsonIDs = ($Queue | ForEach-Object { "'$_'" }) -join ','
$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Music Link Auditor</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #121212; color: #E0E0E0; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background: #1E1E1E; padding: 30px; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); text-align: center; max-width: 450px; width: 100%; border: 1px solid #333; }
        h2 { color: #00ADB5; margin-top: 0; }
        .counter { font-size: 0.9em; color: #888; margin-bottom: 20px; }
        .id-box { background: #2D2D2D; padding: 12px; border-radius: 6px; font-family: monospace; font-size: 1.2em; color: #FFD369; margin-bottom: 25px; word-break: break-all; }
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
        const ids = [$JsonIDs];
        let index = 0;

        function render() {
            if (index >= ids.length) {
                document.getElementById('main-view').classList.add('hidden');
                document.getElementById('done-view').classList.remove('hidden');
                fetch('http://localhost:8080/shutdown');
                return;
            }
            document.getElementById('progress').innerText = `Item \${index + 1} of \${ids.length}`;
            document.getElementById('video-id').innerText = ids[index];
        }

        function openTrack() {
            window.open('https://www.youtube.com/watch?v=' + ids[index], '_blank');
        }

        function submitAction(actionType) {
            const currentId = ids[index];
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

# -----------------------------------------------------------------
# STEP 3: THE LIGHTWEIGHT MICRO-REST LISTENER LOOP
# -----------------------------------------------------------------
# Spins up a native .NET listener loop to intercept processing events from the browser directly
$Listener = New-Object System.Net.HttpListener
$Listener.Prefixes.Add("http://localhost:8080/")
try { $Listener.Start() } catch {
    Write-Host "[!] Port 8080 occupied. Is another instance of the deck running?" -ForegroundColor Red
    Exit 1
}

Write-Host "[+] Local database engine loop listening on port 8080." -ForegroundColor Green
Write-Host "[*] Spawning Firefox interface panel..." -ForegroundColor Yellow

Start-Process -FilePath $FirefoxPath -ArgumentList "`"$HtmlPath`""

# Loop processing interaction payloads until the browser reports work completion
$Looping = $true
while ($Looping) {
    $Context = $Listener.GetContext()
    $Request = $Context.Request
    $Response = $Context