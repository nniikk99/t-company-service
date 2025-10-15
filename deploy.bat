@echo off
setlocal enabledelayedexpansion

set REMOTE=%1
if "%REMOTE%"=="" set REMOTE=https://github.com/nniikk.9/t_co_service.git
set BRANCH=gh-pages
set BASEHREF=/t_co_service/

echo Running PowerShell deploy...
powershell -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" -Remote "%REMOTE%" -Branch "%BRANCH%" -BaseHref "%BASEHREF%" %*

if %ERRORLEVEL% NEQ 0 (
  echo Deployment failed with error %ERRORLEVEL%.
  exit /b %ERRORLEVEL%
)

echo Done. Your app should be available at:
echo https://nniikk.9.github.io/t_co_service/
endlocal
