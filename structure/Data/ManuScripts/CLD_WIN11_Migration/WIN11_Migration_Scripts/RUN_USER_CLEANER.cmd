@echo off
chcp 65001 > nul
echo Запуск clean_hkcu.ps1 в контексте текущего пользователя с правами Admin...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0clean_hkcu.ps1""' -Verb RunAs"
exit