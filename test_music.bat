@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: 1. DEFINE SANDBOX WORKING PATHS
:: ==========================================
set "SCRIPT_DIR=C:\MusicTools\MusicPipeline\Scripts"
set "CONFIG_DIR=C:\MusicTools\MusicPipeline\Config"
set "SANDBOX_DIR"=C:\MusicTools\MusicPipeline\Sandbox"
set "BACKUP_DIR=%SANDBOX_DIR%\Sandbox_Backup"
set "MOBILE_DIR=%SANDBOX_DIR%\Sandbox_Mobile"

set "COOKIE_FILE=%CONFIG_DIR%\cookies.txt"
set "HISTORY_FILE=%BACKUP_DIR%\downloaded_history.txt"
set "YTDLP_EXE=C:\MusicTools\yt-dlp.exe"
set "CHECK_URL=https://www.youtube.com/watch?v=dQw4w9WgXcQ"
set "FIREFOX_EXE=C:\Program Files\Mozilla Firefox\firefox.exe"



:: --- PRE-RUN CLEANUP ---
echo [*] Initializing Sandbox Environment...
if exist "%SANDBOX_DIR%" (
    echo [*] Wiping previous sandbox audio and metadata assets...
    del /q /f /s "%SANDBOX_DIR%\*.*" >nul 2>&1
) else (
    echo [*] Creating fresh isolated sandbox directory...
    mkdir "%SANDBOX_DIR%"
)


:: ==========================================
:: 2. DEFINE SANDBOX PLAYLISTS ARRAY
:: ==========================================
set "TEST_PLAYLISTS="https://www.youtube.com/playlist?list=PLqcuYaDDgyad1-o1HTVnTiZKoluY5enwk""

:: ==========================================
:: 3. MODULE EXECUTION PIPELINE
:: ==========================================

echo [STEP 1/5] Launching Sandbox Cookie Validation...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\CookieCheck.ps1" ^
  -CookiePath "%COOKIE_FILE%" ^
  -YTDLPPath "%YTDLP_EXE%" ^
  -TestURL "%CHECK_URL%"

if %errorlevel% neq 0 exit /b

echo [STEP 2/5] Launching Sandbox Playlist Download Pipeline...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Download.ps1" ^
  -BackupDir "%BACKUP_DIR%" ^
  -YTDLPPath "%YTDLP_EXE%" ^
  -CookiePath "%COOKIE_FILE%" ^
  -HistoryPath "%HISTORY_FILE%" ^
  -PlaylistURLs %TEST_PLAYLISTS% ^
  -ConfigDir "%CONFIG_DIR%" ^
  -SleepInterval 4 ^
  -MaxSleepInterval 12 ^
  -SleepRequests 3

if %errorlevel% neq 0 exit /b

echo [STEP 3/5] Launching Sandbox Error Parser and Repair Tool...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Fix.ps1" ^
  -ConfigDir "%CONFIG_DIR%" ^
  -HistoryPath "%HISTORY_FILE%" ^
  -FirefoxPath "%FIREFOX_EXE%"

if %errorlevel% neq 0 exit /b

echo [STEP 4/5] Launching Sandbox Lyric Search and Automated Embedding...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Lyrics.ps1" ^
  -BackupDir "%BACKUP_DIR%" 


if %errorlevel% neq 0 exit /b

echo [STEP 5/5] Launching Sandbox Parallel Audio Compression Engine...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\CompressMusic.ps1" ^
  -BackupDir "%BACKUP_DIR%" ^
  -MobileDir "%MOBILE_DIR%" ^
  -FFmpegPath "%FFMPEG_EXE%" ^
  -MaxThreads 3

if %errorlevel% neq 0 exit /b

echo ==============================================================
echo [SUCCESS] SANDBOX WORKFLOW COMPLETED WITHOUT ISSUES!
echo ==============================================================
pause