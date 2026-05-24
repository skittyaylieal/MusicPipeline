@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: LOG ROTATION: Prevent log file from bloating
:: ==========================================
if exist "C:\MusicTools\MusicPipeline\Config\pipeline.log" (
    for %%A in ("C:\MusicTools\MusicPipeline\Config\pipeline.log") do (
        if %%~zA gtr 5242880 (
            echo ========================================== > "C:\MusicTools\MusicPipeline\Config\pipeline.log"
            echo [INFO] Log rotated due to size restrictions >> "C:\MusicTools\MusicPipeline\Config\pipeline.log"
            echo ========================================== >> "C:\MusicTools\MusicPipeline\Config\pipeline.log"
        )
    )
)


:: ==========================================
:: 1. DEFINE PRODUCTION WORKING PATHS
:: ==========================================
set "SCRIPT_DIR=C:\MusicTools\MusicPipeline\Scripts"
set "CONFIG_DIR=C:\MusicTools\MusicPipeline\Config"
set "BACKUP_DIR=.\YT_Music_Backup"
set "MOBILE_DIR=.YT_Music_Mobile"

:: Load private paths from the local .env file if it exists
if exist "%~dp0Config\.env" (
    for /f "usebackq delims== tokens=1,2" %%A in ("%~dp0Config\.env") do (
        set "%%A=%%B"
    )
)

set "COOKIE_FILE=%CONFIG_DIR%\cookies.txt"
set "HISTORY_FILE=%CONFIG_DIR%\downloaded_history.txt"
set "YTDLP_EXE=C:\MusicTools\yt-dlp.exe"
set "FFMPEG_EXE=C:\MusicTools\ffmpeg.exe"
set "CHECK_URL=https://www.youtube.com/watch?v=dQw4w9WgXcQ"
set "FIREFOX_EXE=C:\Program Files\Mozilla Firefox\firefox.exe"

:: ==========================================
:: 2. DEFINE PRODUCTION PLAYLISTS ARRAY
:: ==========================================
:: All three production playlists are passed as a comma-separated array string
set "PROD_PLAYLISTS="https://www.youtube.com/playlist?list=PLqcuYaDDgyacWpBG6ib-2EKOuQa6aGjZJ","https://www.youtube.com/playlist?list=PLqcuYaDDgyaeHKssVjz_Nw3qUDwfrwL09","https://www.youtube.com/playlist?list=PLqcuYaDDgyad_i19iLheoQJLLKJUtwlAr""

:: ==========================================
:: 3. MODULE EXECUTION PIPELINE
:: ==========================================

echo [STEP 1/5] Launching Cookie Validation...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\CookieCheck.ps1" ^
  -CookiePath "%COOKIE_FILE%" ^
  -YTDLPPath "%YTDLP_EXE%" ^
  -TestURL "%CHECK_URL%"

if %errorlevel% neq 0 exit /b

echo [STEP 2/5] Launching Playlist Download Pipeline...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Download.ps1" ^
  -BackupDir "%BACKUP_DIR%" ^
  -YTDLPPath "%YTDLP_EXE%" ^
  -CookiePath "%COOKIE_FILE%" ^
  -HistoryPath "%HISTORY_FILE%" ^
  -PlaylistURLs %PROD_PLAYLISTS% ^
  -ConfigDir "%CONFIG_DIR%" ^
  -SleepInterval 4 ^
  -MaxSleepInterval 12 ^
  -SleepRequests 3

if %errorlevel% neq 0 exit /b

echo [STEP 3/5] Launching Error Parser and Repair Tool...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Fix.ps1" ^
  -ConfigDir "%CONFIG_DIR%" ^
  -HistoryPath "%HISTORY_FILE%" ^
  -FirefoxPath "%FIREFOX_EXE%"

if %errorlevel% neq 0 exit /b

echo [STEP 4/5] Launching Lyric Search and Automated Embedding...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Lyrics.ps1" ^
  -BackupDir "%BACKUP_DIR%"

if %errorlevel% neq 0 exit /b


echo [STEP 5/5] Launching Production Audio Compression Engine...

powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\CompressMusic.ps1" ^
  -BackupDir "%BACKUP_DIR%" ^
  -MobileDir "%MOBILE_DIR%" ^
  -FFmpegPath "%FFMPEG_EXE%" ^
  -MaxThreads 3

if %errorlevel% neq 0 exit /b

echo ==============================================================
echo [SUCCESS] ENTIRE PRODUCTION Repository WORKFLOW COMPLETE!
echo ==============================================================



pause