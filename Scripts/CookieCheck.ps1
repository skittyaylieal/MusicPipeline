Param (
    [string]$ProfilesFile
)

function Log-Engine([string]$Message, [string]$AnsiStyle = "1;32") {
    $Timestamp = (Get-Date).ToString("HH:mm:ss")
    $Payload = "`e[${AnsiStyle}m[$Timestamp] [SERVER] $Message`e[0m"
    
    # 1. Attempt to append to the log file safely
    try {
        $Payload | Out-File -FilePath $Global:OutputLogFile -Append -Encoding utf8 -ErrorAction Stop
    } catch {
        # Fallback silently to terminal if the file is transiently locked or busy
        Write-Host "`e[1;31m[LOG LOCK] Could not write to web stream log file: $_`e[0m"
    }
    
    # 2. Mirror it to your running terminal session so you see it live
    Write-Host $Payload
}

# profile loader
function Load-ProfileContext {
    try {
        $Global:ProfileData = Get-Content -LiteralPath $ProfilesFile -Raw | ConvertFrom-Json
        $Active = $Global:ProfileData.ActiveProfile
        foreach ($Config in $Global:ProfileData.Profiles) {
            if ($Config.Name -eq $Active) {
                $Global:ActiveConfig = $Config
            }
        }

        $Global:OutputLogFile             = $Global:ActiveConfig.DiagLogFile
        $Global:CookiePath              = $Global:ActiveConfig.CookieFile
        $Global:YTDLPPath                = $Global:ActiveConfig.YTDLPExe
        $Global:TestURL                = $Global:ActiveConfig.CheckURL

        $Global:Profile                 = $Global:ActiveConfig

        Log-Engine "Loaded configuration profile: [$Active]" "32"
    }
    catch {
        Log-Engine "🛑 Critical breakdown loading profiles json architecture context: $_" "1;31"
        Exit 1
    }
}
Load-ProfileContext


$MetricStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
try {
    Clear-Host
} catch {}

Log-Engine "============================================="
Log-Engine "    PowerShell Module: Cookie Validator"
Log-Engine "============================================="

if (-not (Test-Path -LiteralPath $Global:CookiePath -PathType Leaf)) {
    Log-Engine "[ERROR] Target cookie file couldn't be found"
    Exit 1
}

if (-not (Test-Path -LiteralPath $Global:YTDLPPath -PathType Leaf)) {
    Log-Engine "[ERROR] yt-dlp executable couldn't be found"
    Exit 1
}

Log-Engine "[+] Cookie and yt-dlp files located successfully"
Log-Engine "[*] Testing YouTube cookie status"

& $YTDLPPath --cookies "$Global:CookiePath" --simulate --quiet $Global:TestURL 2>$null

if ($LastExitCode -ne 0) {
    Log-Engine "============================================="
    Log-Engine "[ERROR] YouTube authentication failed!"
    Log-Engine "The cookies.txt has expired or is invalid."
    Log-Engine "============================================="
    Exit 1
}

Log-Engine "[+] Cookies authenticated successfully."
$MetricStopwatch.Stop()
$TotalHours = [math]::Floor($MetricStopwatch.Elapsed.TotalHours)
$Elapsed = "{0:00}:{1:mm\:ss}" -f $TotalHours, $MetricStopwatch.Elapsed
Log-Engine "[METRIC] Total Engine Run Duration: $Elapsed"
Log-Engine "============================================="
Exit 0