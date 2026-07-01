@echo off
:: Проверка, что скрипт не запущен из системной учетной записи
if "%USERNAME%"=="Admin" (
    echo [ОШИБКА] Скрипт должен запускаться строго из-под профиля КЛИЕНТА, а не Admin!
    pause
    exit /b
)

:: Запрос прав администратора с сохранением контекста USERPROFILE
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0clean_hkcu.ps1\"' -Verb RunAs"
exit