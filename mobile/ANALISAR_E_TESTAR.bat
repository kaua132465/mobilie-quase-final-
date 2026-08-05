@echo off
setlocal
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter nao foi encontrado no PATH.
  pause
  exit /b 1
)
flutter pub get || goto erro
flutter analyze || goto erro
flutter test || goto erro
echo.
echo Projeto analisado e testado com sucesso.
pause
exit /b 0
:erro
echo.
echo Foi encontrado um erro. Leia as mensagens acima.
pause
exit /b 1
