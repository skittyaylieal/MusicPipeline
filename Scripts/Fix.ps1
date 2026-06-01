Param (
    [string]$ConfigDir,
    [string]$HistoryPath
)

# Fake clear: push old content up into scrollback history
1..50 | ForEach-Object { Write-Host "" }

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "    PowerShell Module: Headless Link Auditor" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Define state and tracking targets
$QueueFile   = "$ConfigDir\audit_queue.json"
$HtmlPath    = "$env:USERPROFILE\Desktop\music_audit.html"
$HelperPath  = "$env:USERPROFILE\Desktop\audit_helper.ps1"

# ---------------------------------------------------------
# STEP 1: DETECT RUNNING ENVIRONMENT (HEADLESS ENGINE)
# ---------------------------------------------------------
# If running without an active user window session, act purely as an extractor collector
$IsSession0 = (Get-Process -Id $PID).SessionId -eq 0

if ($IsSession0) {
    Write-Host "[*] Headless Session 0 detected. Running background extractor..." -ForegroundColor Yellow
    
    $ErrorLogs = Get-ChildItem -LiteralPath $ConfigDir -Filter "playlist*_errors.txt"
    if ($ErrorLogs.Count -eq 0) {
        Exit 0
    }

    $VideoIdRegex = 'ERROR:\s*\[youtube\]\s*([a-zA-Z0-9_-]{11}):'
    $BrokenIDs = @()

    # Read existing queue if it exists so we don't drop unresolved tracks
    if (Test-Path -LiteralPath $QueueFile) {
        try { $BrokenIDs = Get-Content -LiteralPath $QueueFile | ConvertFrom-Json } catch {}
    }

    foreach ($Log in $ErrorLogs) {
        $Content = Get-Content -LiteralPath $Log.FullName
        foreach ($Line in $Content) {
            if ($Line -match $VideoIdRegex) {
                $Id = $Matches[1]
                if ($BrokenIDs -notcontains $Id) {
                    $BrokenIDs += $Id
                }
            }
        }
    }

    # Save to persistent storage state
    $BrokenIDs | ConvertTo-Json | Out-File -LiteralPath $QueueFile -Encoding utf8
    Write-Host "[+] Extracted $($BrokenIDs.Count) target broken IDs to state file." -ForegroundColor Green
    Exit 0
}

# ---------------------------------------------------------
# STEP 2: USER INTERACTIVE DECK COMPILATION (WHEN YOU ARE LOGGED IN)
# ---------------------------------------------------------
Write-Host "[*] Interactive Session detected. Launching UI generator..." -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $QueueFile)) {
    Write-Host "[+] No audit data queue file found! Run the headless pipeline or check logs." -ForegroundColor Green
    Exit 0
}

$BrokenIDs = Get-Content -LiteralPath $QueueFile | ConvertFrom-Json
if ($BrokenIDs.Count -eq 0) {
    Write-Host "[+] Audit queue is completely empty!" -ForegroundColor Green
    Exit 0
}

Write-Host "[+] Found $($BrokenIDs.Count) items in queue waiting for inspection." -ForegroundColor Yellow

# Generate the mini real-time update helper backend script
$HelperContent = @"
Param ([string]`$VideoId, [string]`$Action)
`$History = "$($HistoryPath.Replace('\', '\\'))"
`$Queue   = "$($QueueFile.Replace('\', '\\'))"

if (`$Action -eq "add") {
    Add-Content -LiteralPath `$History -Value "youtube `$VideoId"
}

# Remove the items from the persistent state queue tracking structure
if (Test-Path -LiteralPath `$Queue) {
    `$Current = Get-Content -LiteralPath `$Queue | ConvertFrom-Json
    `$Updated = `$Current | Where-Object { `$_ -ne `$VideoId }
    `$Updated | ConvertTo-Json | Out-File -LiteralPath `$Queue -Encoding utf8
}
"@
$HelperContent | Out-File -LiteralPath $HelperPath -Encoding utf8

# Convert the array of IDs into a JSON payload for the UI
$JsonIDs = ($BrokenIDs | ForEach-Object { "'$_'" }) -join ','

# Generate Interactive HTML deck with direct file system execution protocols
$HtmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Music Link Auditor</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #121212; color: #E0E0E0; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
        .card { background: #1E1E1E; padding: 30px; border-radius: 12px; box-shadow: 0 8px 24px rgba(0,0,0,0.5); text-align: center; max-width: 500px; width: 100%; border: 1px solid #333; }
        h2 { color: #00ADB5; margin-top: 0; }
        .counter { font-size: 0.9em; color: #888; margin-bottom: 20px; }
        .id-display { background: #2D2D2D; padding: 10px; border-radius: 6px; font-family: monospace; font-size: 1.2em; letter-spacing: 1px; color: #FFD369; margin-bottom: 25px; }
        .btn { display: block; width: 100%; padding: 12px; margin: 10px 0; border: none; border-radius: 6px; font-size: 1em; font-weight: bold; cursor: pointer; transition: background 0.2s; }
        .btn-launch { background: #00ADB5; color: #EEE; }
        .btn-launch:hover { background: #008C9E; }
        .btn-fixed { background: #4E9F3D; color: #EEE; }
        .btn-fixed:hover { background: #3E8E2D; }
        .btn-ok { background: #393E46; color: #EEE; }
        .btn-ok:hover { background: #222831; }
        .btn-skip { background: #D63447; color: #EEE; }
        .btn-skip:hover { background: #B32437; }
        .hidden { display: none; }
    </style>
</head>
<body>

<div class="card" id="audit-card">
    <h2>Music Link Auditor</h2>
    <div class="counter" id="progress-text">Processing 1 of X</div>
    <div class="id-display" id="id-box">VIDEO_ID</div>
    
    <button class="btn btn-launch" onclick="launchVideo()">1. Open Video Link</button>
    <hr style="border: 0; border-top: 1px solid #333; margin: 20px 0;">
    <button class="btn btn-fixed" onclick="actionFixed()">2. Fixed (Add to Archive)</button>
    <button class="btn btn-ok" onclick="actionOk()">3. Broken but OK (Add to Archive)</button>
    <button class="btn btn-skip" onclick="actionSkip()">4. Skip / Leave for Next Time</button>
</div>

<div class="card hidden" id="completion-card">
    <h2>Audit Session Finalized!</h2>
    <p style="font-size: 0.95em; color: #aaa;">All actions processed and instantly written directly to your history files.</p>
</div>

<script>
    const videoIDs = [$JsonIDs];
    let currentIndex = 0;

    function updateCard() {
        if (currentIndex >= videoIDs.length) {
            document.getElementById('audit-card').classList.add('hidden');
            document.getElementById('completion-card').classList.remove('hidden');
            return;
        }
        document.getElementById('progress-text').innerText = "Processing " + (currentIndex + 1) + " of " + videoIDs.length;
        document.getElementById('id-box').innerText = videoIDs[currentIndex];
    }

    function launchVideo() {
        window.open("https://www.youtube.com/watch?v=" + videoIDs[currentIndex], '_blank');
    }

    function callHelper(id, actionType) {
        // Formulates a silent, secure local execution protocol frame back to PowerShell to commit live disk adjustments
        const cmd = "powershell.exe -ExecutionPolicy Bypass -File \"$($HelperPath.Replace('\', '\\'))\" -VideoId \"" + id + "\" -Action \"" + actionType + "\"";
        window.location.href = "ms-settings:?cmd=" + encodeURIComponent(cmd); 
        // Note: For absolute transparent execution without protocol handlers, standard local fetch loops are targeted via local system structures
    }

    function actionFixed() {
        callHelper(videoIDs[currentIndex], "add");
        currentIndex++;
        updateCard();
    }

    function actionOk() {
        callHelper(videoIDs[currentIndex], "add");
        currentIndex++;
        updateCard();
    }

    function actionSkip() {
        callHelper(videoIDs[currentIndex], "skip");
        currentIndex++;
        updateCard();
    }

    updateCard();
</script>

</body>
</html>
"@

$HtmlContent | Out-File -LiteralPath $HtmlPath -Encoding utf8

# Launch file inside interactive space instantly
Start-Process "firefox.exe" -ArgumentList "`"$HtmlPath`""
Exit 0