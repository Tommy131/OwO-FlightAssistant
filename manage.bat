@echo off
setlocal enabledelayedexpansion

:MENU
cls
echo ======================================================
echo           OwO! Dashboard Management Script
echo ======================================================
echo.
echo  [1] Clean ^& Get (flutter clean, pub get)
echo  [2] Generate Icons (flutter_launcher_icons)
echo  [3] Run Application (Windows) [DEFAULT - 3s]
echo  [4] Build Release (Windows)
echo  [5] Build Release (Android)
echo.
echo  [0] Exit
echo.
echo ======================================================
echo Please select an option [1,2,3,4,5,0]:
choice /C 123450 /N /T 3 /D 3 /M "Choice (Default is 3 in 3s): "

:: Choice errorlevel is based on the index in /C
if errorlevel 6 exit
if errorlevel 5 goto BUILD_ANDROID
if errorlevel 4 goto BUILD_WINDOWS
if errorlevel 3 goto RUN
if errorlevel 2 goto ICONS
if errorlevel 1 goto CLEAN

goto MENU

:CLEAN
echo.
echo === Cleaning project and getting dependencies ===
call flutter clean
call flutter pub get
echo.
echo Done.
pause
goto MENU

:ICONS
echo.
echo === Generating application icons ===
call dart run flutter_launcher_icons
echo.
echo Done.
pause
goto MENU

:RUN
echo.
echo === Running application on Windows ===
call flutter run -d windows
goto MENU

:BUILD_WINDOWS
echo.
echo === Building release for Windows ===
call flutter build windows
echo.
echo Finished build process.
pause
goto MENU

:BUILD_ANDROID
echo.
echo === Building release for Android ===
call flutter build apk
echo.
echo Finished build process.
pause
goto MENU
