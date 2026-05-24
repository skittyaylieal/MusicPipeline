@echo off
setlocal enabledelayedexpansion

:: 1. Define Standard Working Paths
set "SCRIPT_DIR=C:\MusicTools\Scripts"
set "CONFIG_DIR=C:\MusicTools\Config"
set "BACKUP_DIR=C:\MusicTools\Sandbox_Backup"

set "COOKIE_FILE=%CONFIG_DIR%\cookies.txt"
set "HISTORY_FILE=%BACKUP_DIR%\downloaded_history.txt"
set "YTDLP_EXE=C:\MusicTools\yt-dlp.exe"
set "CHECK_URL=https://www.youtube.com/watch?v=dQw4w9WgXcQ"

:: 2. Define Test Playlists Array (Comma-Separated inside one string)
set "TEST_PLAYLISTS="https://www.youtube.com/playlist?list=PLQcuYaDDgyad1-o1HTVnTiZKoluY5enwk""

:: 3. Call Cookie Check Module
echo Launching Sandbox Cookie Validation...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\CookieCheck.ps1" ^
  -CookiePath "%COOKIE_FILE%" ^
  -YTDLPPath "%YTDLP_EXE%" ^
  -TestURL "%CHECK_URL%"

if %errorlevel% neq 0 exit /b

:: 4. Call Download Module (Now handles its own looping!)
echo Launching Sandbox Playlist Download Pipeline...
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

:: 5. Call Fix Error Sweep Module (Added Execution Hook)
echo Launching Sandbox Error Parser and Repair Tool...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Fix.ps1" ^
  -ConfigDir "%CONFIG_DIR%" ^
  -HistoryPath "%HISTORY_FILE%" ^
  -FirefoxPath "%FIREFOX_EXE%"


:: 6. Define foobar2000 Executable and Trigger Lyric Engine Module
set "FB2K_EXE=C:\Program Files\foobar2000\foobar2000.exe"

echo Launching Sandbox Lyric Search and Automated Embedding...
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Lyrics.ps1" ^
  -BackupDir "%BACKUP_DIR%" ^
  -FoobarPath "%FB2K_EXE%"

if %errorlevel% neq 0 exit /b

pause