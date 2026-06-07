Param (
    [string]$BackupDir = "C:\Users\filip\Music\YT_Music_Backup",
    [string]$MobileDir = "C:\Users\filip\Music\YT_Music_Mobile"
)

# Global variables and runtime states
$Global:IsPipelineRunning = $false
[cite_start]$Global:DiagLogFile = "C:\MusicTools\MusicPipeline\Config\web_console_stream.log" [cite: 284]
[cite_start]$Global:CacheFile = "C:\MusicTools\MusicPipeline\Config\dashboard_cache.json" [cite: 284]
[cite_start]$Global:TimingFile = "C:\MusicTools\MusicPipeline\Config\timing_history.json" [cite: 284]
[cite_start]$HtmlFile = "C:\MusicTools\MusicPipeline\Scripts\dashboard.html" [cite: 284]

[cite_start]$ScriptRepoDir = "C:\MusicTools\MusicPipeline" [cite: 284]
[cite_start]$ScriptDir = "$ScriptRepoDir\Scripts" [cite: 284]
[cite_start]$ConfigDir = "$ScriptRepoDir\Config" [cite: 284]

[cite_start]if (-not (Test-Path $ConfigDir)) { New-Item $ConfigDir -ItemType Directory -Force } [cite: 284]
if (-not (Test-Path $Global:TimingFile)) { "[]" | [cite_start]Out-File $Global:TimingFile } [cite: 284, 285]

# Shared Default Memory Container
$Global:CachedMetrics = @{
    [cite_start]masterCount  = 0; mobileCount = 0; lrcCount = 0 [cite: 285, 286]
    [cite_start]masterSize   = 0; mobileSize  = 0; alerts = @() [cite: 286]
    [cite_start]loadingState = "scanning"; tracks = @() [cite: 286]
}

# -----------------------------------------------------------------
# 1. ROBUST BACKGROUND SCANNER & AUTOMATION ENGINE
# -----------------------------------------------------------------
function Start-AsyncLibraryScanner {
    Get-Job -Name "MusicFolderScanner" -ErrorAction SilentlyContinue | [cite_start]Remove-Job -Force -ErrorAction SilentlyContinue [cite: 287, 288]

    $JobScript = {
        param($BDir, $MDir, $RDir, $CFile)
        
        [cite_start]Start-Sleep -Seconds 2 [cite: 288]
        [cite_start]while ($true) { [cite: 288]
            [cite_start]if (-not (Test-Path -LiteralPath $BDir)) { Start-Sleep -Seconds 5; continue } [cite: 288, 289]

            $MasterFiles = Get-ChildItem -LiteralPath $BDir -Recurse -File | [cite_start]Where-Object { $_.Extension -match "flac|mp3|m4a" } [cite: 289, 290]
            $MobileFiles = Get-ChildItem -LiteralPath $MDir -Recurse -File | [cite_start]Where-Object { $_.Extension -match "m4a" } [cite: 290, 291]
            [cite_start]$LrcFiles    = Get-ChildItem -LiteralPath $BDir -Recurse -Filter "*.lrc" -File [cite: 291]

            [cite_start]$MasterSize = ($MasterFiles | Measure-Object -Property Length -Sum).Sum / 1GB [cite: 291]
            [cite_start]$MobileSize = ($MobileFiles | Measure-Object -Property Length -Sum).Sum / 1GB [cite: 291]

            [cite_start]$TrackDatabase = @() [cite: 291]

            [cite_start]foreach ($File in $MasterFiles) { [cite: 291]
                [cite_start]if ($null -eq $File.FullName) { continue } [cite: 291]
                [cite_start]$RelativePath = $File.FullName.Substring($BDir.Length).TrimStart('\') [cite: 291]
                [cite_start]$PathParts = $RelativePath -split '\\' [cite: 291]
                [cite_start]$Artist = if ($PathParts.Count -ge 3) { $PathParts[0] } else { "Unknown Artist" } [cite: 291]
                [cite_start]$Album  = if ($PathParts.Count -ge 3) { $PathParts[1] } else { "Single / Unknown" } [cite: 291]
                
                [cite_start]$TrackDatabase += @{ [cite: 291]
                    [cite_start]title  = [string]$File.BaseName [cite: 291]
                    [cite_start]artist = [string]$Artist [cite: 291]
                    [cite_start]album  = [string]$Album [cite: 291]
                    [cite_start]sizeMb = [Math]::Round(($File.Length / 1MB), 2) [cite: 291, 292]
                    [cite_start]hasLrc = [bool](Test-Path -LiteralPath "$($File.DirectoryName)\$($File.BaseName).lrc" -ErrorAction SilentlyContinue) [cite: 292]
                    [cite_start]type   = [string]$File.Extension.ToUpper().Replace('.','') [cite: 292]
                }

                [cite_start]if ($TrackDatabase.Count % 150 -eq 0) { [cite: 292]
                    @{
                        [cite_start]masterCount  = $MasterFiles.Count [cite: 292]
                        [cite_start]mobileCount  = $MobileFiles.Count [cite: 292]
                        [cite_start]lrcCount     = $LrcFiles.Count [cite: 292]
                        [cite_start]masterSize   = [Math]::Round($MasterSize, 2) [cite: 292]
                        [cite_start]mobileSize   = [Math]::Round($MobileSize, 2) [cite: 292]
                        [cite_start]alerts       = @() [cite: 292]
                        [cite_start]loadingState = "scanning" [cite: 292]
                        [cite_start]tracks       = $TrackDatabase [cite: 292]
                    } | ConvertTo-Json -Depth 4 | [cite_start]Out-File -FilePath $CFile -Encoding utf8 -Force [cite: 292, 293]
                }
            }

            [cite_start]$Alerts = @() [cite: 293]
            [cite_start]if (Test-Path -LiteralPath "$RDir\.git") { [cite: 293]
                try {
                    [cite_start]$Env:GIT_TERMINAL_PROMPT = "0" [cite: 293]
                    [cite_start]$Env:GIT_SSH_COMMAND = "" [cite: 293]
                    [cite_start]Push-Location $RDir [cite: 293]
                    [cite_start][void](git -c network.timeout=5 fetch origin main 2>&1) [cite: 293]
                    [cite_start]$LocalHash  = (git rev-parse HEAD).Trim() [cite: 293]
                    [cite_start]$RemoteHash = (git rev-parse origin/main).Trim() [cite: 293]

                    [cite_start]if ($LocalHash -ne $RemoteHash) { [cite: 293]
                        [cite_start]$Alerts += @{ [cite: 293]
                            [cite_start]type      = "warning" [cite: 293]
                            [cite_start]message   = "Repository Update Available: Changes pushed from Mac are ready." [cite: 293]
                            [cite_start]fixAction = "gitpull" [cite: 294]
                        }
                    }
                    [cite_start]Pop-Location [cite: 294]
                } catch {
                    [cite_start]if ($null -ne $RDir) { Pop-Location } [cite: 294]
                }
            }

            [cite_start]if ($MasterFiles.Count -gt $MobileFiles.Count) { [cite: 294]
                [cite_start]$Alerts += @{ type = "danger"; message = "Synchronization Gap: Master backup has $(($MasterFiles.Count - $MobileFiles.Count)) more track(s) than Mobile."; fixAction = "sync" } [cite: 294, 295, 296]
            }

            @{
                [cite_start]masterCount  = $MasterFiles.Count [cite: 296]
                [cite_start]mobileCount  = $MobileFiles.Count [cite: 296]
                [cite_start]lrcCount     = $LrcFiles.Count [cite: 296]
                [cite_start]masterSize   = [Math]::Round($MasterSize, 2) [cite: 296]
                [cite_start]mobileSize   = [Math]::Round($MobileSize, 2) [cite: 296]
                [cite_start]alerts       = $Alerts [cite: 296]
                [cite_start]loadingState = "idle" [cite: 296]
                [cite_start]tracks       = $TrackDatabase [cite: 296]
            } | ConvertTo-Json -Depth 4 | [cite_start]Out-File -FilePath $CFile -Encoding utf8 -Force [cite: 296, 297]

            [cite_start]Start-Sleep -Seconds 60 [cite: 297]
        }
    }

    [cite_start]$Job = Start-Job -Name "MusicFolderScanner" -ScriptBlock $JobScript -ArgumentList $BackupDir, $MobileDir, $ScriptRepoDir, $Global:CacheFile [cite: 297]
}

function Start-AutomatedChronDaemon {
    param($RuntimePort)
    Get-Job -Name "ChronDaemon" -ErrorAction SilentlyContinue | [cite_start]Remove-Job -Force -ErrorAction SilentlyContinue [cite: 297, 298]
    
    $ChronScript = {
        param($TargetPort)
        while ($true) {
            [cite_start]Start-Sleep -Seconds 1800 [cite: 298]
            [cite_start]try { Invoke-RestMethod -Uri "http://127.0.0.1:$TargetPort/run?type=Automated" -Method Post } catch {} [cite: 298]
        }
    }
    [cite_start]$Job = Start-Job -Name "ChronDaemon" -ScriptBlock $ChronScript -ArgumentList $RuntimePort [cite: 298]
}

# -----------------------------------------------------------------
# 2. PROCESS MANAGEMENT & PERFORMANCE PARSER
# -----------------------------------------------------------------
function Invoke-PipelineExecution {
    param(
        [bool]$CleanSweep = $false,
        [cite_start][string]$TriggerType = "Manual" [cite: 298]
    )

    [cite_start]if ($Global:IsPipelineRunning) { return } [cite: 298]
    [cite_start]$Global:IsPipelineRunning = $true [cite: 298]
    
    [cite_start]if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force } [cite: 298]
    "`e[1;36m[SYSTEM] ($TriggerType Run) Initializing Master Pipeline...`e[0m" | [cite_start]Out-File -FilePath $Global:DiagLogFile -Encoding utf8 [cite: 298, 299]

    $ContextBundle = @{
        [cite_start]ScriptDir       = "C:\MusicTools\MusicPipeline\Scripts" [cite: 299]
        [cite_start]ConfigDir       = "C:\MusicTools\MusicPipeline\Config" [cite: 299]
        [cite_start]BackupDir       = $BackupDir [cite: 299]
        [cite_start]MobileDir       = $MobileDir [cite: 299]
        [cite_start]CookieFile      = "C:\MusicTools\MusicPipeline\Config\cookies.txt" [cite: 299]
        [cite_start]HistoryFile     = "C:\MusicTools\MusicPipeline\Config\downloaded_history.txt" [cite: 299]
        [cite_start]YTDLPExe        = "C:\MusicTools\yt-dlp.exe" [cite: 299]
        [cite_start]FFmpegExe       = "C:\MusicTools\ffmpeg.exe" [cite: 299]
        [cite_start]FirefoxExe      = "C:\Program Files\Mozilla Firefox\firefox.exe" [cite: 299]
        [cite_start]CheckURL        = "https://www.youtube.com/watch?v=dQw4w9WgXcQ" [cite: 299]
        Playlists       = @(
            [cite_start]"https://www.youtube.com/playlist?list=PLqcuYaDDgyacWpBG6ib-2EKOuQa6aGjZJ", [cite: 299]
            [cite_start]"https://www.youtube.com/playlist?list=PLqcuYaDDgyaeHKssVjz_Nw3qUDwfrwL09", [cite: 299]
            [cite_start]"https://www.youtube.com/playlist?list=PLqcuYaDDgyad_i19iLheoQJLLKJUtwlAr" [cite: 299]
        )
        [cite_start]CleanSweep      = $CleanSweep [cite: 299]
        [cite_start]LogFile         = $Global:DiagLogFile [cite: 299]
        [cite_start]TimingFile      = $Global:TimingFile [cite: 299]
        [cite_start]RunType         = $TriggerType [cite: 299]
    }

    $MasterPipelineJob = {
        param($EnvMap)

        [cite_start]$env:PYTHONUNBUFFERED = "1" [cite: 299]
        [cite_start]$env:YTDLP_UNBUFFERED = "1" [cite: 299]

        function Log-Progress([string]$Msg) {
            [cite_start]$Timestamp = (Get-Date).ToString("HH:mm:ss") [cite: 299]
            "`e[90m[$Timestamp]`e[0m $Msg" | [cite_start]Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 [cite: 300]
        }

        [cite_start]$OverallStopwatch = [System.Diagnostics.Stopwatch]::StartNew() [cite: 300]

        try {
            # STEP 1: Cookie Validation
            [cite_start]Log-Progress "`e[1;33m[STEP 1/5]`e[0m Running Cookie Validation..." [cite: 300]
            [cite_start]$S1Watch = [System.Diagnostics.Stopwatch]::StartNew() [cite: 300]
            [cite_start]$S1ScriptPath = Join-Path $EnvMap.ScriptDir "CookieCheck.ps1" [cite: 300]
            $S1Params = @{ CookiePath = $EnvMap.CookieFile; YTDLPPath = $EnvMap.YTDLPExe; [cite_start]TestURL = $EnvMap.CheckURL } [cite: 300, 301]
            [cite_start]$Step1Result = & $S1ScriptPath @S1Params 2>&1 [cite: 301]
            $Step1Result | [cite_start]Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 [cite: 301, 302]
            $S1Watch.Stop(); [cite_start]$S1Time = [string]::Format("{0:hh\:mm\:ss}", $S1Watch.Elapsed) [cite: 302]

            # STEP 2: Downloader Script
            [cite_start]Log-Progress "`e[1;33m[STEP 2/5]`e[0m Running Native Pipeline Downloader..." [cite: 302]
            [cite_start]$S2Watch = [System.Diagnostics.Stopwatch]::StartNew() [cite: 302]
            [cite_start]$S2ScriptPath = Join-Path $EnvMap.ScriptDir "Download.ps1" [cite: 302]
            $S2Params = @{
                [cite_start]BackupDir        = $EnvMap.BackupDir [cite: 302]
                [cite_start]YTDLPPath        = $EnvMap.YTDLPExe [cite: 302]
                [cite_start]CookiePath       = $EnvMap.CookieFile [cite: 302]
                [cite_start]HistoryPath      = $EnvMap.HistoryFile [cite: 302]
                [cite_start]PlaylistURLs     = $EnvMap.Playlists [cite: 302]
                [cite_start]ConfigDir        = $EnvMap.ConfigDir [cite: 302]
                [cite_start]SleepInterval    = 4 [cite: 302]
                [cite_start]MaxSleepInterval = 12 [cite: 302]
                [cite_start]SleepRequests    = 3 [cite: 302]
                [cite_start]CleanSweep       = $EnvMap.CleanSweep [cite: 302]
            }
            [cite_start]$Step2Result = & $S2ScriptPath @S2Params 2>&1 [cite: 302]
            $Step2Result | [cite_start]Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 [cite: 302, 303]
            $S2Watch.Stop(); [cite_start]$S2Time = [string]::Format("{0:hh\:mm\:ss}", $S2Watch.Elapsed) [cite: 303]

            # STEP 3: Error Analysis
            [cite_start]Log-Progress "`e[1;33m[STEP 3/5]`e[0m Running Error Log Analysis..." [cite: 303]
            [cite_start]$S3Watch = [System.Diagnostics.Stopwatch]::StartNew() [cite: 303]
            [cite_start]$S3ScriptPath = Join-Path $EnvMap.ScriptDir "Fix.ps1" [cite: 303]
            $S3Params = @{ ConfigDir = $EnvMap.ConfigDir; HistoryPath = $EnvMap.HistoryFile; [cite_start]FirefoxPath = $EnvMap.FirefoxExe } [cite: 303, 304]
            [cite_start]$Step3Result = & $S3ScriptPath @S3Params 2>&1 [cite: 304]
            $Step3Result | [cite_start]Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 [cite: 304, 305]
            $S3Watch.Stop(); [cite_start]$S3Time = [string]::Format("{0:hh\:mm\:ss}", $S3Watch.Elapsed) [cite: 305]

            # STEP 4: Lyrics Database Sync
            [cite_start]Log-Progress "`e[1;33m[STEP 4/5]`e[0m Syncing Local Lyrics Databases..." [cite: 305]
            [cite_start]$S4Watch = [System.Diagnostics.Stopwatch]::StartNew() [cite: 305]
            [cite_start]$S4ScriptPath = Join-Path $EnvMap.ScriptDir "Lyrics.ps1" [cite: 305]
            [cite_start]$S4Params = @{ BackupDir = $EnvMap.BackupDir } [cite: 305]
            [cite_start]$Step4Result = & $S4ScriptPath @S4Params 2>&1 [cite: 305, 306]
            $Step4Result | [cite_start]Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 [cite: 306]
            $S4Watch.Stop(); [cite_start]$S4Time = [string]::Format("{0:hh\:mm\:ss}", $S4Watch.Elapsed) [cite: 306]

            # STEP 5: Transcoding Engine
            [cite_start]Log-Progress "`e[1;33m[STEP 5/5]`e[0m Executing Lossy Mobile Deployment Transcoding..." [cite: 306]
            [cite_start]$S5Watch = [System.Diagnostics.Stopwatch]::StartNew() [cite: 306]
            [cite_start]$S5ScriptPath = Join-Path $EnvMap.ScriptDir "CompressMusic.ps1" [cite: 306]
            $S5Params = @{ BackupDir = $EnvMap.BackupDir; MobileDir = $EnvMap.MobileDir; FFmpegPath = $EnvMap.FFmpegExe; [cite_start]MaxThreads = 3 } [cite: 306, 307]
            [cite_start]$Step5Result = & $S5ScriptPath @S5Params 2>&1 [cite: 307]
            $Step5Result | [cite_start]Out-File -FilePath $EnvMap.LogFile -Append -Encoding utf8 [cite: 307, 308]
            $S5Watch.Stop(); [cite_start]$S5Time = [string]::Format("{0:hh\:mm\:ss}", $S5Watch.Elapsed) [cite: 308]

            [cite_start]$OverallStopwatch.Stop() [cite: 308]
            [cite_start]$TotalTime = [string]::Format("{0:hh\:mm\:ss}", $OverallStopwatch.Elapsed) [cite: 308]

            [cite_start]Log-Progress "`e[1;32m[SUCCESS] Master Execution Pipeline Completed Successfully!`e[0m" [cite: 308]
            
            $HistoryDB = Get-Content -LiteralPath $EnvMap.TimingFile -Raw | [cite_start]ConvertFrom-Json [cite: 308, 309]
            [cite_start]if ($null -eq $HistoryDB) { $HistoryDB = @() } [cite: 309]
            
            $NewMetricRecord = @{
                [cite_start]timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") [cite: 309]
                [cite_start]type      = $EnvMap.RunType [cite: 309]
                [cite_start]step1     = $S1Time; step2 = $S2Time; step3 = $S3Time; step4 = $S4Time; step5 = $S5Time [cite: 309, 310]
                [cite_start]total     = $TotalTime [cite: 310]
            }
            [cite_start]$HistoryDB += $NewMetricRecord [cite: 310]
            $HistoryDB | ConvertTo-Json -Depth 4 | [cite_start]Out-File -FilePath $EnvMap.TimingFile -Encoding utf8 -Force [cite: 310, 311]
        }
        catch {
            [cite_start]Log-Progress "`e[1;31m[CRITICAL ERROR] Pipeline execution collapsed: $_`e[0m" [cite: 311]
        }
    }

    [cite_start]$Job = Start-Job -Name "ActiveMusicDownloader" -ScriptBlock $MasterPipelineJob -ArgumentList $ContextBundle [cite: 311]
}

function Invoke-HotReload {
    [cite_start]if (Test-Path $Global:DiagLogFile) { Remove-Item $Global:DiagLogFile -Force } [cite: 311]
    "`e[1;35m[SYSTEM] Hot-reload triggered. Checking for remote updates...`e[0m" | [cite_start]Out-File -FilePath $Global:DiagLogFile -Encoding utf8 [cite: 311, 312]
    [cite_start]Push-Location $ScriptRepoDir [cite: 312]
    try {
        [cite_start]$Env:GIT_TERMINAL_PROMPT = "0" [cite: 312]
        [cite_start]$Env:GIT_SSH_COMMAND = "" [cite: 312]
        [cite_start]$BeforeHash = (& "git" rev-parse HEAD).Trim() [cite: 312]
        $PullOutput = & "git" pull origin main 2>&1 | [cite_start]Out-String [cite: 312, 313]
        $PullOutput | [cite_start]Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 [cite: 313]
        [cite_start]$AfterHash = (& "git" rev-parse HEAD).Trim() [cite: 313]

        [cite_start]$EngineChanged = $false [cite: 313]
        [cite_start]if ($BeforeHash -ne $AfterHash) { [cite: 313]
            [cite_start]$ChangedFiles = & "git" diff --name-only $BeforeHash $AfterHash [cite: 313]
            [cite_start]foreach ($File in $ChangedFiles) { [cite: 313]
                [cite_start]if ($File -replace '\\','/' -match "scripts/websiteengine.ps1$|^websiteengine.ps1$") { [cite: 313]
                    [cite_start]$EngineChanged = $true [cite: 313]
                    [cite_start]break [cite: 313]
                }
            }
        }

        [cite_start]if ($EngineChanged) { [cite: 313]
            " ↳ WebsiteEngine.ps1 modification detected. Respawning core process..." | [cite_start]Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 [cite: 313, 314]
            [cite_start]$ArgsList = @("-NoProfile", "-WindowStyle", "Hidden", "-File", "$PSCommandPath") [cite: 314]
            [cite_start]Start-Process -FilePath "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList $ArgsList [cite: 314]
            [cite_start]Pop-Location [cite: 314]
            [cite_start]Stop-Process -Id $PID -Force [cite: 314]
        } else {
            " ↳ Asset update only (HTML/CSS). Engine restart skipped. Core server remains live." | [cite_start]Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 [cite: 314, 315]
        }
    } catch {
        " ↳ Hot-Reload Exception: $_" | [cite_start]Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 [cite: 315, 316]
    }
    [cite_start]Pop-Location [cite: 316]
}

# -----------------------------------------------------------------
# 3. ADAPTIVE NETWORK ENGINE ROUTER ROUTINE
# -----------------------------------------------------------------
[cite_start]Write-Host "🧼 Flushing old proxy tables and cleaning session jobs..." -ForegroundColor Yellow [cite: 316]
netsh interface portproxy reset | [cite_start]Out-Null [cite: 316, 317]
Get-Job -Name "MusicFolderScanner","ChronDaemon","ActiveMusicDownloader" -ErrorAction SilentlyContinue | [cite_start]Remove-Job -Force -ErrorAction SilentlyContinue [cite: 317]

[cite_start]$TargetPort = 49152 [cite: 317]
[cite_start]while ($true) { [cite: 317]
    [cite_start]$Conflict = Get-NetTCPConnection -LocalPort $TargetPort -ErrorAction SilentlyContinue [cite: 317]
    [cite_start]if (-not $Conflict) { break } [cite: 317]
    [cite_start]$TargetPort++ [cite: 317]
}

[cite_start]Write-Host "🔗 Aligning fresh Windows port proxy map: 80 ---> $TargetPort" -ForegroundColor Cyan [cite: 317]
[cite_start]netsh interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=$TargetPort connectaddress=127.0.0.1 [cite: 317]

[cite_start]$Listener = New-Object System.Net.HttpListener [cite: 317]
[cite_start]$Listener.Prefixes.Add("http://127.0.0.1:$TargetPort/") [cite: 317]

try {
    [cite_start]$Listener.Start() [cite: 317]
    $LocalIPs = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'Wi-Fi','Ethernet' -ErrorAction SilentlyContinue | [cite_start]Select-Object -ExpandProperty IPAddress [cite: 317, 318]
    [cite_start]$PrimaryIP = if ($LocalIPs) { $LocalIPs[0] } else { "127.0.0.1" } [cite: 318]

    [cite_start]Write-Output "--------------------------------------------------" [cite: 318]
    [cite_start]Write-Output " SERVER LIVE AND ADAPTIVELY MAPPED!" [cite: 318]
    [cite_start]Write-Output " Internal Endpoint : http://127.0.0.1:$TargetPort/" [cite: 318, 319]
    [cite_start]Write-Output " Clean Browser URL : http://$PrimaryIP/" [cite: 319]
    [cite_start]Write-Output "--------------------------------------------------" [cite: 319]
    
    [cite_start]Start-AsyncLibraryScanner [cite: 319]
    [cite_start]Start-AutomatedChronDaemon -RuntimePort $TargetPort [cite: 319]
    
    trap {
        [cite_start]Write-Host "🛑 Shutting down server engine cleanly..." -ForegroundColor Red [cite: 319]
        [cite_start]if ($null -ne $Listener -and $Listener.IsListening) { $Listener.Stop() } [cite: 319]
        [cite_start]if ($null -ne $Listener) { $Listener.Close() } [cite: 319]
        netsh interface portproxy reset | [cite_start]Out-Null [cite: 319, 320]
        [cite_start]exit [cite: 320]
    }

    while ($true) {
        [cite_start]$Context = $Listener.GetContext() [cite: 320]
        [cite_start]$Request = $Context.Request [cite: 320]
        [cite_start]$Response = $Context.Response [cite: 320]
        [cite_start]$UrlPath = $Request.Url.LocalPath [cite: 320]
        [cite_start]$Method  = $Request.HttpMethod [cite: 320]

        [cite_start]$Response.KeepAlive = $false [cite: 320]
        [cite_start]$Response.Headers.Add("Connection", "close") [cite: 320]
        [cite_start]$Response.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate") [cite: 320]
        [cite_start]$Response.Headers.Add("Pragma", "no-cache") [cite: 320]
        [cite_start]$Response.Headers.Add("Expires", "0") [cite: 320]

        if ($UrlPath -eq "/" -and $Method -eq "GET") {
            [cite_start]$HtmlContent = Get-Content -LiteralPath $HtmlFile -Raw -Encoding utf8 [cite: 320]
            [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes($HtmlContent) [cite: 320]
            [cite_start]$Response.ContentType = "text/html; charset=utf-8" [cite: 320]
            [cite_start]$Response.OutputStream.Write($Buffer, 0, $Buffer.Length) [cite: 320]
        }
        # -----------------------------------------------------------------
        # ENDPOINT 1: READ BROKEN TRACKS PAYLOAD FROM THE JSON DATABASE
        # -----------------------------------------------------------------
        elseif ($UrlPath -eq "/broken-songs" -and $Method -eq "GET") {
            $BrokenDbFile = "C:\MusicTools\MusicPipeline\Config\broken_songs.json"
            $RawData = "[]"
            if (Test-Path $BrokenDbFile) { $RawData = Get-Content -LiteralPath $BrokenDbFile -Raw }
            $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData)
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        # -----------------------------------------------------------------
        # ENDPOINT 2: PROCESS THE THREE-WAY TRIAGE RULE ACTION
        # -----------------------------------------------------------------
        elseif ($UrlPath -eq "/resolve-song" -and $Method -eq "POST") {
            $BrokenDbFile = "C:\MusicTools\MusicPipeline\Config\broken_songs.json"
            $HistoryFile  = "C:\MusicTools\MusicPipeline\Config\downloaded_history.txt"
            
            $SongId   = $Request.QueryString["id"]
            $Action   = $Request.QueryString["action"] # "write_history" or "purge_only"
            $VideoID  = $Request.QueryString["videoId"]

            if ($SongId -and (Test-Path $BrokenDbFile)) {
                # Clean entry from active layout data arrays
                $CurrentList = Get-Content -LiteralPath $BrokenDbFile -Raw | ConvertFrom-Json
                $UpdatedList = $CurrentList | Where-Object { $_.id -ne $SongId }
                $UpdatedList | ConvertTo-Json -Depth 4 | Out-File -FilePath $BrokenDbFile -Encoding utf8 -Force

                # Route data handling criteria based on requested interaction buttons
                if ($Action -eq "write_history" -and -not [string]::IsNullOrWhiteSpace($VideoID)) {
                    $ArchiveLine = "youtube $VideoID"
                    [System.IO.File]::AppendAllText($HistoryFile, ($ArchiveLine + [System.Environment]::NewLine))
                }
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"success"}')
                $Response.StatusCode = 200
            } else {
                $Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Invalid request target"}')
                $Response.StatusCode = 400
            }
            $Response.ContentType = "application/json"
            $Response.OutputStream.Write($Buffer, 0, $Buffer.Length)
        }
        # -----------------------------------------------------------------
        [cite_start]elseif ($UrlPath -eq "/analytics" -and $Method -eq "GET") { [cite: 320]
            [cite_start]$RawData = "[]" [cite: 320]
            [cite_start]if (Test-Path $Global:TimingFile) { $RawData = Get-Content -LiteralPath $Global:TimingFile -Raw } [cite: 320]
            [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawData) [cite: 320]
            [cite_start]$Response.ContentType = "application/json" [cite: 320]
            [cite_start]$Response.OutputStream.Write($Buffer, 0, $Buffer.Length) [cite: 320]
        }
        [cite_start]elseif ($UrlPath -eq "/metrics" -and $Method -eq "GET") { [cite: 320, 321]
            [cite_start]if (Test-Path $Global:CacheFile) { [cite: 321]
                try {
                    [cite_start]$RawJson = Get-Content -LiteralPath $Global:CacheFile -Raw -ErrorAction SilentlyContinue [cite: 321]
                    [cite_start]if ($RawJson) { $Buffer = [System.Text.Encoding]::UTF8.GetBytes($RawJson) } [cite: 321]
                } catch {
                    $JsonPayload = $Global:CachedMetrics | [cite_start]ConvertTo-Json -Depth 4 -Compress [cite: 321, 322]
                    [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload) [cite: 322]
                }
            } else {
                $JsonPayload = $Global:CachedMetrics | [cite_start]ConvertTo-Json -Depth 4 -Compress [cite: 322, 323]
                [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload) [cite: 323]
            }
            [cite_start]$Response.ContentType = "application/json" [cite: 323]
            [cite_start]$Response.ContentLength64 = $Buffer.Length [cite: 323]
            [cite_start]$Response.OutputStream.Write($Buffer, 0, $Buffer.Length) [cite: 323]
        }
        [cite_start]elseif ($UrlPath -eq "/stream" -and $Method -eq "GET") { [cite: 323]
            [cite_start]$CurrentLogs = @() [cite: 323]
            [cite_start]if (Test-Path $Global:DiagLogFile) { $CurrentLogs = Get-Content -LiteralPath $Global:DiagLogFile -ErrorAction SilentlyContinue } [cite: 323]
            
            [cite_start]$DownloadJob = Get-Job -Name "ActiveMusicDownloader" -ErrorAction SilentlyContinue [cite: 323]
            if ($DownloadJob) {
                if ($DownloadJob.State -ne "Running") { $Global:IsPipelineRunning = $false; [cite_start]Remove-Job -Job $DownloadJob -Force } [cite: 323, 324]
            [cite_start]} else { $Global:IsPipelineRunning = $false } [cite: 324]

            $JsonPayload = @{ running = $Global:IsPipelineRunning; logs = $CurrentLogs } | [cite_start]ConvertTo-Json -Compress [cite: 324, 325]
            [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes($JsonPayload) [cite: 325]
            [cite_start]$Response.ContentType = "application/json" [cite: 325]
            [cite_start]$Response.ContentLength64 = $Buffer.Length [cite: 325]
            [cite_start]$Response.OutputStream.Write($Buffer, 0, $Buffer.Length) [cite: 325]
        }
        [cite_start]elseif ($UrlPath -eq "/clear-logs" -and $Method -eq "POST") { [cite: 325]
            try {
                [cite_start]Clear-Content -LiteralPath $Global:DiagLogFile -ErrorAction Stop [cite: 325]
                "`e[1;36m[SYSTEM] Console logs manually cleared.`e[0m" | [cite_start]Out-File -FilePath $Global:DiagLogFile -Encoding utf8 [cite: 325, 326]
                [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"cleared"}') [cite: 326]
                [cite_start]$Response.StatusCode = 200 [cite: 326]
            } catch {
                [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Failed to clear logs"}') [cite: 326]
                [cite_start]$Response.StatusCode = 500 [cite: 326]
            }
            [cite_start]$Response.ContentType = "application/json" [cite: 326]
            [cite_start]$Response.ContentLength64 = $Buffer.Length [cite: 326]
            [cite_start]$Response.OutputStream.Write($Buffer, 0, $Buffer.Length) [cite: 326]
        }
        [cite_start]elseif ($UrlPath -eq "/run" -and $Method -eq "POST") { [cite: 326]
            [cite_start]$IsSweepRequested = [bool]($Request.Url.Query -match "sweep=true") [cite: 326]
            [cite_start]$RunContext = "Manual" [cite: 326]
            [cite_start]if ($Request.Url.Query -match "type=Automated") { $RunContext = "Automated" } [cite: 326]
            [cite_start]if ($IsSweepRequested) { $RunContext = "Clean Sweep" } [cite: 326]
            [cite_start]Invoke-PipelineExecution -CleanSweep $IsSweepRequested -TriggerType $RunContext [cite: 326]
            [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"dispatched"}') [cite: 326]
            [cite_start]$Response.ContentType = "application/json" [cite: 326]
            [cite_start]$Response.ContentLength64 = $Buffer.Length [cite: 326]
            [cite_start]$Response.OutputStream.Write($Buffer, 0, $Buffer.Length) [cite: 326]
        }
        [cite_start]elseif ($UrlPath -eq "/stop" -and $Method -eq "POST") { [cite: 326]
            try {
                [cite_start]$DownloadJob = Get-Job -Name "ActiveMusicDownloader" -ErrorAction SilentlyContinue [cite: 326, 327]
                [cite_start]if ($DownloadJob) { [cite: 327]
                    [cite_start]Stop-Job -Job $DownloadJob -ErrorAction SilentlyContinue [cite: 327]
                    [cite_start]Remove-Job -Job $DownloadJob -Force -ErrorAction SilentlyContinue [cite: 327]
                }
                [cite_start]$Global:IsPipelineRunning = $false [cite: 327]
                [cite_start]$Timestamp = (Get-Date).ToString("HH:mm:ss") [cite: 327]
                "`e[1;31m[$Timestamp] [SYSTEM] Pipeline manually terminated by user.`e[0m" | [cite_start]Out-File -FilePath $Global:DiagLogFile -Append -Encoding utf8 [cite: 327, 328]
                [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"stopped"}') [cite: 328]
                [cite_start]$Response.StatusCode = 200 [cite: 328]
            } catch {
                [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"error","message":"Failed to terminate job"}') [cite: 328]
                [cite_start]$Response.StatusCode = 500 [cite: 328]
            }
            [cite_start]$Response.ContentType = "application/json" [cite: 328]
            [cite_start]$Response.ContentLength64 = $Buffer.Length [cite: 328]
            [cite_start]$Response.OutputStream.Write($Buffer, 0, $Buffer.Length) [cite: 328]
        }
        [cite_start]elseif ($UrlPath -eq "/pull" -and $Method -eq "POST") { [cite: 328]
            [cite_start]Invoke-HotReload [cite: 328]
            [cite_start]$Buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"pulling"}') [cite: 328]
            [cite_start]$Response.ContentType = "application/json" [cite: 328]
            [cite_start]$Response.ContentLength64 = $Buffer.Length [cite: 328]
            [cite_start]$Response.OutputStream.Write($Buffer, 0, $Buffer.Length) [cite: 328]
            [cite_start]$Response.OutputStream.Close() [cite: 328]
            [cite_start]Stop-Process -Id $PID -Force [cite: 328]
        }
        [cite_start]elseif ($UrlPath -eq "/favicon.ico") { $Response.StatusCode = 404 } [cite: 328]
        [cite_start]else { $Response.StatusCode = 404 } [cite: 328]
        [cite_start]try { $Response.OutputStream.Close() } catch {} [cite: 328]
    }
}  
[cite_start]catch { Write-Host "⚠️ Router Stream Exception: $_" -ForegroundColor Yellow } [cite: 328, 329]
finally { if ($null -ne $Listener) { if ($Listener.IsListening) { $Listener.Stop() }; [cite_start]$Listener.Close() } } [cite: 329]