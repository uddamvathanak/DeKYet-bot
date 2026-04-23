@echo off
echo Creating Dota 2 bot script symlink to ryndrb Tinkering ABout baseline...

set DOTA_BOTS="C:\Program Files (x86)\Steam\steamapps\common\dota 2 beta\game\dota\scripts\vscripts\bots"
set REPO_BOTS="%~dp0bots"

:: Remove existing bots folder/symlink if present
if exist %DOTA_BOTS% (
    rmdir %DOTA_BOTS% 2>nul
    if exist %DOTA_BOTS% (
        echo Could not remove %DOTA_BOTS% -- it may be a real folder with files.
        echo Please move or delete it manually, then re-run this script as Administrator.
        pause
        exit /b 1
    )
    echo Removed existing bots folder/symlink.
)

:: Create symlink to this repo's bots/ folder
mklink /D %DOTA_BOTS% %REPO_BOTS%

if %errorlevel%==0 (
    echo.
    echo SUCCESS. Symlink created.
    echo Dota 2 will now load bots from: %REPO_BOTS%
    echo.
    echo Current baseline: ryndrb/dota2bot ^(Tinkering ABout^)
) else (
    echo.
    echo FAILED. Please right-click and choose "Run as administrator".
)

pause
