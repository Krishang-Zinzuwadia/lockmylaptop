@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0show-pairing-code.ps1" %*
endlocal