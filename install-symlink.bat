@echo off
echo Creating Dota 2 bot script symlink...

set DOTA_BOTS="C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots"
set REPO_BOTS="C:\github-repo\dota2bot-OpenHyperAI\bots"

:: Remove existing bots folder/symlink if present
if exist %DOTA_BOTS% (
    rmdir %DOTA_BOTS%
    echo Removed existing bots folder/symlink.
)

:: Create symlink
mklink /D %DOTA_BOTS% %REPO_BOTS%

if %errorlevel%==0 (
    echo.
    echo SUCCESS! Symlink created.
    echo Dota 2 will now use: %REPO_BOTS%
) else (
    echo.
    echo FAILED. Please make sure you right-clicked and chose "Run as administrator".
)

pause
