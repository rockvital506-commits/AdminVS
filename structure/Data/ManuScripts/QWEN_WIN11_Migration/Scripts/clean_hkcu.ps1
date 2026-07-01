<#
.SYNOPSIS
    Модульный скрипт динамической зачистки личного пространства (HKCU) клиента.
    Кодировка: UTF-8.
.DESCRIPTION
    Считывает маски из внешнего файла user_junk_masks.txt, удаляет зомби-задачи
    планировщика, остатки софта и вырезает рекламу Windows 11 25H2.
.NOTES
    Запускается строго из-под учетной записи клиента на Этапе 4 от имени Администратора.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

Write-Host "==========================================================================" -ForegroundColor Yellow
Write-Host " ДИНАМИЧЕСКАЯ ЗАЧИСТКА И УСТРАНЕНИЕ ЗОМБИ-КОМПОНЕНТОВ В ПРОФИЛЕ КЛИЕНТА " -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Yellow

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$MasksFile = Join-Path $ScriptPath "user_junk_masks.txt"

if (-not (Test-Path $MasksFile)) {
    Write-Error "Критическая ошибка: Файл конфигурации пользователей '$MasksFile' не найден!"
    pause
    Exit
}

# --------------------------------------------------------------------------
# ШАГ 1: АВТОМАТИЧЕСКАЯ ОЧИСТКА МЕРТВЫХ ЗАДАЧ В ПЛАНИРОВЩИКЕ (TASK SCHEDULER)
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 1: Поиск и удаление невалидных задач планировщика..." -ForegroundColor Cyan
Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "\Microsoft*" } | ForEach-Object {
    $TaskName = $_.TaskName
    $TaskAction = $_.Actions.Execute
    if ($TaskAction -and (Test-Path $TaskAction -ErrorAction SilentlyContinue) -eq $false) {
        Write-Host " -> Удаление сиротской задачи: $TaskName (Файл '$TaskAction' не найден)" -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
}

# --------------------------------------------------------------------------
# ШАГ 2: ПАРСИНГ И ОБРАБОТКА ДИНАМИЧЕСКОГО ФАЙЛА МАСОК ПОЛЬЗОВАТЕЛЯ
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 2: Чтение файла масок и вырезание хвостов старого ПО..." -ForegroundColor Cyan
$MaskLines = Get-Content -Path $MasksFile | Where-Object { $_ -and -not $_.Trim().StartsWith("#") }

foreach ($Line in $MaskLines) {
    if (-not ($Line -match "\|")) { continue }
    $Type, $RelativePath = $Line.Split("|")
    $Type = $Type.Trim()
    $RelativePath = $RelativePath.Trim()

    if ($Type -eq "Folder") {
        $FullPath = Join-Path $env:USERPROFILE "AppData\$RelativePath"
        if (Test-Path $FullPath) {
            Write-Host " -> Уничтожение папки мусора: AppData\$RelativePath" -ForegroundColor Yellow
            # Удаляем саму папку целиком, а не только содержимое
            Remove-Item -Path $FullPath -Recurse -Force
        }
    }
    elseif ($Type -eq "Registry") {
        $FullKey = "HKCU:\Software\$RelativePath"
        if (Test-Path $FullKey) {
            Write-Host " -> Сброс аппаратных ID в реестре: HKCU:\Software\$RelativePath" -ForegroundColor Yellow
            Remove-Item -Path $FullKey -Recurse -Force
        }
    }
}

# Очистка системного Temp пользователя
$UserTemp = Join-Path $env:USERPROFILE "AppData\Local\Temp"
if (Test-Path $UserTemp) { 
    Remove-Item -Path "$UserTemp\*" -Recurse -Force
}

# --------------------------------------------------------------------------
# ШАГ 3: ФИКСАЦИЯ ИНТЕРФЕЙСА WINDOWS 11 25H2 И ОЧИСТКА КЭШЕЙ ПРОВОДНИКА
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 3: Зачистка рекламы проводника и истории эскизов..." -ForegroundColor Cyan

$ContextPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (Test-Path $ContextPath) {
    Set-ItemProperty -Path $ContextPath -Name "SystemAndSystemToastNotificationSettingsAllowed" -Value 0 -Type DWord
    Set-ItemProperty -Path $ContextPath -Name "OemPreInstalledAppsEnabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $ContextPath -Name "SubscribedContent-338387Enabled" -Value 0 -Type DWord
    Set-ItemProperty -Path $ContextPath -Name "SubscribedContent-338389Enabled" -Value 0 -Type DWord
}

$AdvPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
if (Test-Path $AdvPath) {
    Set-ItemProperty -Path $AdvPath -Name "Start_TrackProgs" -Value 0 -Type DWord
}

# Принудительное уничтожение баз эскизов. Требуется остановка Explorer!
Write-Host " -> Остановка Explorer.exe для сброса кэша эскизов..." -ForegroundColor Gray
Stop-Process -Name "explorer" -Force
Start-Sleep -Seconds 2

Remove-Item -Path "$env:LocalAppData\Microsoft\Windows\Explorer\thumbcache_*.db" -Force
Remove-Item -Path "$env:LocalAppData\Microsoft\Windows\Explorer\iconcache_*.db" -Force

Write-Host " -> Перезапуск Explorer.exe..." -ForegroundColor Gray
Start-Process "explorer.exe"

Write-Host "`n==========================================================================" -ForegroundColor Green
Write-Host " ЛИЧНОЕ ПРОСТРАНСТВО КЛИЕНТА УСПЕШНО ОЧИЩЕНО ПО ДИНАМИЧЕСКИМ МАСКАМ! " -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
pause