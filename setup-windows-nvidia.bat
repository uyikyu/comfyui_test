@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows-nvidia.ps1" %*
set "setup_exit=%ERRORLEVEL%"
if not "%setup_exit%"=="0" echo Setup exited with code %setup_exit%.
pause
exit /b %setup_exit%
