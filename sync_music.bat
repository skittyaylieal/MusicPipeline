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

:: Capture Overall Pipeline Start Time
set "START_TIME=%time%"

:: ==========================================
:: 1. DEFINE PRODUCTION WORKING PATHS
:: ==========================================
set "SCRIPT_DIR=C:\MusicTools\MusicPipeline\Scripts"
set "CONFIG_DIR=C:\MusicTools\MusicPipeline\Config"
set "BACKUP_DIR=.\YT_Music_Backup"
set "MOBILE_DIR=.YT_Music_Mobile"

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
set PROD_PLAYLISTS="https://www.youtube.com/playlist?list=PLqcuYaDDgyacWpBG6ib-2EKOuQa6aGjZJ","https://www.youtube.com/playlist?list=PLqcuYaDDgyaeHKssVjz_Nw3qUDwfrwL09","https://www.youtube.com/playlist?list=PLqcuYaDDgyad_i19iLheoQJLLKJUtwlAr"

:: ==========================================
:: 3. MODULE EXECUTION PIPELINE
:: ==========================================

echo [STEP 1/5] Launching Cookie Validation...
for /f "delims=" %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\CookieCheck.ps1" -CookiePath "%COOKIE_FILE%" -YTDLPPath "%YTDLP_EXE%" -TestURL "%CHECK_URL%"') do (
    echo %%I
    echo %%I | findstr /C:"[METRIC]" >nul && set "TIME_STEP1=%%I"
)
if %errorlevel% neq 0 exit /b

echo [STEP 2/5] Launching Playlist Download Pipeline...
for /f "delims=" %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Download.ps1" -BackupDir "%BACKUP_DIR%" -YTDLPPath "%YTDLP_EXE%" -CookiePath "%COOKIE_FILE%" -HistoryPath "%HISTORY_FILE%" -PlaylistURLs "%PROD_PLAYLISTS%" -ConfigDir "%CONFIG_DIR%" -SleepInterval 4 -MaxSleepInterval 12 -SleepRequests 3') do (
    echo %%I
    echo %%I | findstr /C:"[METRIC]" >nul && set "TIME_STEP2=%%I"
)

echo [STEP 3/5] Launching Error Parser and Repair Tool...
for /f "delims=" %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Fix.ps1" -ConfigDir "%CONFIG_DIR%" -HistoryPath "%HISTORY_FILE%" -FirefoxPath "%FIREFOX_EXE%"') do (
    echo %%I
    echo %%I | findstr /C:"[METRIC]" >nul && set "TIME_STEP3=%%I"
)
if %errorlevel% neq 0 exit /b

echo [STEP 4/5] Launching Lyric Search and Automated Embedding...
for /f "delims=" %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\Lyrics.ps1" -BackupDir "%BACKUP_DIR%"') do (
    echo %%I
    echo %%I | findstr /C:"[METRIC]" >nul && set "TIME_STEP4=%%I"
)
if %errorlevel% neq 0 exit /b

echo [STEP 5/5] Launching Production Audio Compression Engine...
for /f "delims=" %%I in ('powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%\CompressMusic.ps1" -BackupDir "%BACKUP_DIR%" -MobileDir "%MOBILE_DIR%" -FFmpegPath "%FFMPEG_EXE%" -MaxThreads 3') do (
    echo %%I
    echo %%I | findstr /C:"[METRIC]" >nul && set "TIME_STEP5=%%I"
)
if %errorlevel% neq 0 exit /b

:: Calculate total run duration
set "END_TIME=%time%"
set "options=tokens=1-4 delims=:.,"
for /f "%options%" %%a in ("%START_TIME%") do set /a "start=(((%%a*60)+1%%b-100)*60+1%%c-100)*100+1%%d-100"
for /f "%options%" %%a in ("%END_TIME%") do set /a "end=(((%%a*60)+1%%b-100)*60+1%%c-100)*100+1%%d-100"
set /a "elapsed=end-start"
if %elapsed% lss 0 set /a "elapsed+=8640000"
set /a "h=elapsed/360000, m=(elapsed%%360000)/6000, s=((elapsed%%360000)%%6000)/100, ms=(elapsed%%360000)%%100"
if %h% lss 10 set "h=0%h%"
if %m% lss 10 set "m=0%m%"
if %s% lss 10 set "s=0%s%"
if %ms% lss 10 set "ms=0%ms%"

:: Clean up metric strings for final printout
set "TIME_STEP1=%TIME_STEP1:[METRIC] =%"
set "TIME_STEP2=%TIME_STEP2:[METRIC] =%"
set "TIME_STEP3=%TIME_STEP3:[METRIC] =%"
set "TIME_STEP4=%TIME_STEP4:[METRIC] =%"
set "TIME_STEP5=%TIME_STEP5:[METRIC] =%"

echo ==============================================================
echo [SUCCESS] ENTIRE PRODUCTION Repository WORKFLOW COMPLETE
echo ==============================================================
echo                     PIPELINE PROFILE SUMMARY                  
echo --------------------------------------------------------------
echo Step 1: Cookie Check      :: %TIME_STEP1%
echo Step 2: Media Download    :: %TIME_STEP2%
echo Step 3: Error Log Parser  :: %TIME_STEP3%
echo Step 4: Lyric Embedder    :: %TIME_STEP4%
echo Step 5: Audio Compressor  :: %TIME_STEP5%
echo --------------------------------------------------------------
echo TOTAL PIPELINE TIME       :: %h%:%m%:%s%.%ms%
echo ==============================================================

if "%1" neq "headless" (
    pause
)