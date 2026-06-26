<#
.SYNOPSIS
    Перенаправление медиа-кэша браузеров с SSD на HDD через NTFS Symlink.
.DESCRIPTION
    Переносит только Cache-директории. Куки, пароли, сессии — остаются на SSD.
    ЗАПУСКАТЬ: от Администратора в профиле клиента. Браузеры должны быть закрыты.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ("=" * 74) -ForegroundColor Yellow
Write-Host "  ПЕРЕНАПРАВЛЕНИЕ КЭША БРАУЗЕРОВ НА HDD D:" -ForegroundColor Yellow
Write-Host ("=" * 74) -ForegroundColor Yellow

# Принудительное завершение процессов браузеров
Stop-Process -Name "chrome"  -Force -ErrorAction SilentlyContinue
Stop-Process -Name "browser" -Force -ErrorAction SilentlyContinue  # Яндекс.Браузер
Stop-Process -Name "msedge"  -Force -ErrorAction SilentlyContinue  # Edge (если используется)
Start-Sleep -Seconds 2

if (-not (Test-Path "D:\")) {
    Write-Warning "Диск D: не найден. Символьные ссылки не могут быть созданы. Выход."
    Exit 1
}

# Функция создания Symlink (корректное экранирование путей с пробелами)
function New-CacheSymlink {
    param(
        [string]$SourceCache,  # Оригинальный путь кэша браузера (на SSD)
        [string]$TargetDir,    # Новое расположение кэша (на HDD)
        [string]$BrowserName
    )
    Write-Host "`n[--->] Обработка $BrowserName..." -ForegroundColor Cyan
    $ProfileDir = Split-Path -Parent $SourceCache
    if (-not (Test-Path $ProfileDir)) {
        Write-Host "  -> Профиль $BrowserName не найден. Пропускаем." -ForegroundColor Gray
        return
    }
    # Удалить существующую Cache-папку
    if (Test-Path $SourceCache) {
        Remove-Item -Path $SourceCache -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Создать целевую папку на HDD
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
    # Создать NTFS junction-point (символьную ссылку уровня ФС)
    # cmd /c используется намеренно — PowerShell не имеет нативного mklink для директорий
    $result = & cmd.exe /c "mklink /j `"$SourceCache`" `"$TargetDir`""
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] Кэш $BrowserName -> $TargetDir" -ForegroundColor Green
    } else {
        Write-Warning "  Ошибка создания ссылки для $BrowserName. Результат: $result"
    }
}

# Google Chrome
New-CacheSymlink `
    -SourceCache "$env:LocalAppData\Google\Chrome\User Data\Default\Cache" `
    -TargetDir   "D:\BrowserCache\Chrome" `
    -BrowserName "Google Chrome"

# Яндекс.Браузер
New-CacheSymlink `
    -SourceCache "$env:LocalAppData\Yandex\YandexBrowser\User Data\Default\Cache" `
    -TargetDir   "D:\BrowserCache\Yandex" `
    -BrowserName "Яндекс.Браузер"

Write-Host "`n[+] ВСЕ ОПЕРАЦИИ С СИМВОЛЬНЫМИ ССЫЛКАМИ ЗАВЕРШЕНЫ." -ForegroundColor Green