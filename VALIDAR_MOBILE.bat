@echo off
cd /d "%~dp0mobile"
call flutter pub get
if errorlevel 1 exit /b %errorlevel%
call flutter analyze
if errorlevel 1 exit /b %errorlevel%
call flutter test
