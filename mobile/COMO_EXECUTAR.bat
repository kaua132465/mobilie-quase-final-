@echo off
setlocal
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter nao foi encontrado no PATH.
  echo Instale o Flutter e reinicie o VS Code.
  pause
  exit /b 1
)
flutter pub get
if errorlevel 1 pause & exit /b 1
flutter run
pause
