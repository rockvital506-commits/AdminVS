@echo off
chcp 65001 > nul
echo Запуск complete_cleaner.ps1 от имени Администратора...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0complete_cleaner.ps1"
pause