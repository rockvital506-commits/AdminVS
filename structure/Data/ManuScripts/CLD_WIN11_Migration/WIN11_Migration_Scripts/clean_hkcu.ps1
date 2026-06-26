<#
.SYNOPSIS
    Модульная зачистка личного пространства клиента (HKCU + AppData).
.DESCRIPTION
    Считывает маски из user_junk_masks.txt, удаляет зомби-задачи планировщика,
    остатки VPN/антивирусов в AppData, сбрасывает аппаратные GUID в HKCU,
    вырезает рекламу Windows 11 25H2.
    ЗАПУСКАТЬ: из-под учётной записи КЛИЕНТА на Этапе 4.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

Write-Host ("=" * 74) -ForegroundColor Yellow
Write-Host "  ЗАЧИСТКА ПРОФИЛЯ КЛИЕНТА — HKCU + AppData" -ForegroundColor Yellow
Write-Host ("=" * 74) -ForegroundColor Yellow

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$MasksFile  = Join-Path $ScriptPath "user_junk_masks.txt"
if (-not (Test-Path $MasksFile)) {
    Write-Error "КРИТИЧНО: '$MasksFile' не найден!"
    Exit 1
}

# --------------------------------------------------------------------------
# ШАГ 1: УДАЛЕНИЕ ЗОМБИ-ЗАДАЧ ПЛАНИРОВЩИКА
#         (задачи, чьи .exe-файлы уже не существуют)
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 1: Поиск и удаление невалидных задач планировщика..." -ForegroundColor Cyan
Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "*\Microsoft\*" } | ForEach-Object {
    $TaskName = $_.TaskName
    try {
        $Actions = (Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop).Actions
        foreach ($Action in $Actions) {
            if ($Action.Execute -and (-not (Test-Path $Action.Execute -ErrorAction SilentlyContinue))) {
                Write-Host "  -> Удаление сиротской задачи: $TaskName" -ForegroundColor Yellow
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
                break
            }
        }
    } catch { }
}
Write-Host "[+] Шаг 1 завершён." -ForegroundColor Green

# --------------------------------------------------------------------------
# ШАГ 2: ПАРСИНГ МАСОК И УДАЛЕНИЕ ЗОМБИ-ПАПОК / КЛЮЧЕЙ РЕЕСТРА
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 2: Зачистка AppData и HKCU по маскам..." -ForegroundColor Cyan
$MaskLines = Get-Content -Path $MasksFile | Where-Object { $_ -and -not $_.StartsWith("#") }

foreach ($Line in $MaskLines) {
    if (-not ($Line -match "\|")) { continue }
    $Type, $RelativePath = $Line.Split("|", 2)
    $Type         = $Type.Trim()
    $RelativePath = $RelativePath.Trim()

    if ($Type -eq "Folder") {
        $FullPath = Join-Path $env:USERPROFILE "AppData\$RelativePath"
        if (Test-Path $FullPath) {
            Write-Host "  -> Удаление папки: AppData\$RelativePath" -ForegroundColor Yellow
            Remove-Item -Path $FullPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    } elseif ($Type -eq "Registry") {
        $FullKey = "HKCU:\Software\$RelativePath"
        if (Test-Path $FullKey) {
            Write-Host "  -> Удаление ключа: HKCU:\Software\$RelativePath" -ForegroundColor Yellow
            Remove-Item -Path $FullKey -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Очистка пользовательской Temp
$UserTemp = Join-Path $env:USERPROFILE "AppData\Local\Temp"
if (Test-Path $UserTemp) {
    Remove-Item -Path "$UserTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[+] Шаг 2 завершён." -ForegroundColor Green

# --------------------------------------------------------------------------
# ШАГ 3: ЗАЧИСТКА РЕКЛАМЫ И КЭШЕЙ ПРОВОДНИКА WINDOWS 11 (25H2)
#         ВАЖНО: перед удалением файлов кэша останавливаем Explorer
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 3: Зачистка рекламы и кэшей иконок Проводника..." -ForegroundColor Cyan

# Останавливаем Explorer, чтобы снять блокировку с файлов кэша
Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Удаляем базы эскизов и иконок (фиксит зависание панели задач после миграции)
Remove-Item "$env:LocalAppData\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LocalAppData\Microsoft\Windows\Explorer\iconcache_*.db"  -Force -ErrorAction SilentlyContinue

# Перезапускаем Explorer
Start-Process "explorer.exe"

# Отключаем телеметрию ввода и рекламные подсказки в профиле клиента
$CDM = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (-not (Test-Path $CDM)) { New-Item -Path $CDM -Force | Out-Null }
Set-ItemProperty -Path $CDM -Name "SystemAndSystemToastNotificationSettingsAllowed" -Value 0 -Type DWord
Set-ItemProperty -Path $CDM -Name "OemPreInstalledAppsEnabled"                      -Value 0 -Type DWord
Set-ItemProperty -Path $CDM -Name "SubscribedContent-338387Enabled"                 -Value 0 -Type DWord
Set-ItemProperty -Path $CDM -Name "SubscribedContent-338389Enabled"                 -Value 0 -Type DWord

Set-ItemProperty "HKCU:\Software\Microsoft\Input\TIPC" -Name "Enabled" -Value 0 -Type DWord

$PersonPath = "HKCU:\Software\Microsoft\Personalization\Settings"
if (-not (Test-Path $PersonPath)) { New-Item -Path $PersonPath -Force | Out-Null }
Set-ItemProperty -Path $PersonPath -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord

Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Start_TrackProgs" -Value 0 -Type DWord

Write-Host "[+] Шаг 3 завершён." -ForegroundColor Green
Write-Host "`n$(("=" * 74))" -ForegroundColor Green
Write-Host "  ПРОФИЛЬ КЛИЕНТА ОЧИЩЕН ПО ДИНАМИЧЕСКИМ МАСКАМ." -ForegroundColor Green
Write-Host ("=" * 74) -ForegroundColor Green