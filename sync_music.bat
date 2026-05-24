@echo off
setlocal enabledelayedexpansion

:: ==========================================
:: 1. DEFINE PRODUCTION WORKING PATHS
:: ==========================================
set "SCRIPT_DIR=C:\MusicTools\Scripts"
set "CONFIG_DIR=C:\MusicTools\Config"
set "BACKUP_DIR=C:\Users\filip\Music\YT_Music_Backup"
set "MOBILE_DIR=C:\Users\filip\Music\YT_Music_Mobile"

set "COOKIE_FILE=%CONFIG_DIR%\cookies.txt"
set "HISTORY_FILE=%BACKUP_DIR%\downloaded_history.txt"
set "YTDLP_EXE=C:\MusicTools\yt-dlp.exe"
set "CHECK_URL=https://www.youtube.com/watch?v=dQw4w9WgXcQ"
set "FIREFOX_EXE=C:\Program Files\Mozilla Firefox\firefox.exe"
set "FB2K_EXE=C:\Program Files\foobar2000\foobar2000.exe"

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
  -BackupDir "%BACKUP_DIR%" ^
  -FoobarPath "%FB2K_EXE%"

if %errorlevel% neq 0 exit /b

pause