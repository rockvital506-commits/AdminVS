<#
.SYNOPSIS
    Глобальная оптимизация Windows 11 (25H2) Pro — очистка базы HKLM.
.DESCRIPTION
    Безопасно удаляет Win32-программы через реестр (без Win32_Product),
    вырезает AppX/UWP пакеты, отключает телеметрию, ИИ-модули (Recall/Copilot),
    расшифровывает BitLocker, сжимает WinSxS.
    ЗАПУСКАТЬ: из-под учётной записи Admin на Этапе 3 в ВМ.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

Write-Host ("=" * 74) -ForegroundColor Yellow
Write-Host "  КОМПЛЕКСНАЯ ОПТИМИЗАЦИЯ И ОЧИСТКА БАЗЫ (WIN 25H2)" -ForegroundColor Yellow
Write-Host ("=" * 74) -ForegroundColor Yellow

# --- Загрузка файла масок ---
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$MasksFile  = Join-Path $ScriptPath "apps_to_remove.txt"
if (-not (Test-Path $MasksFile)) {
    Write-Error "КРИТИЧНО: '$MasksFile' не найден! Поместите файл рядом со скриптом."
    Exit 1
}
$Masks = Get-Content -Path $MasksFile | Where-Object { $_ -and -not $_.StartsWith("#") }

# --------------------------------------------------------------------------
# ШАГ 1: БЕЗОПАСНОЕ УДАЛЕНИЕ Win32-ПРОГРАММ ЧЕРЕЗ РЕЕСТР ДЕИНСТАЛЛЯЦИИ
#         (Замена опасного и медленного класса Win32_Product)
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 1: Поиск и удаление Win32-программ по маскам..." -ForegroundColor Cyan

$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

foreach ($Mask in $Masks) {
    $CleanMask = $Mask.Trim().Replace("*", "")
    if ($CleanMask -eq "") { continue }

    Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like "*$CleanMask*" -and $_.UninstallString } |
    ForEach-Object {
        Write-Host "  -> Удаление: $($_.DisplayName)" -ForegroundColor Yellow
        # Берём тихую строку деинсталляции или строку по умолчанию
        $UnCmd = if ($_.QuietUninstallString) { $_.QuietUninstallString } else { $_.UninstallString }

        if ($UnCmd -match "msiexec") {
            # MSI: добавляем флаги тихого удаления без перезагрузки
            $ProductCode = [regex]::Match($UnCmd, '\{[A-F0-9-]+\}').Value
            if ($ProductCode) {
                Start-Process "msiexec.exe" -ArgumentList "/x `"$ProductCode`" /qn /norestart" -Wait
            }
        } else {
            # EXE: запускаем как есть через Start-Process для корректной обработки пробелов
            try {
                $Parts = [System.Management.Automation.PSParser]::Tokenize($UnCmd, [ref]$null)
                $Exe  = $Parts[0].Content
                $Args = ($Parts | Select-Object -Skip 1).Content -join " "
                Start-Process -FilePath $Exe -ArgumentList $Args -Wait -ErrorAction Stop
            } catch {
                Write-Warning "  Не удалось запустить деинсталлятор: $UnCmd"
            }
        }
    }
}
Write-Host "[+] Шаг 1 завершён." -ForegroundColor Green

# --------------------------------------------------------------------------
# ШАГ 2: УДАЛЕНИЕ AppX / UWP ПАКЕТОВ ДЛЯ ВСЕХ ПОЛЬЗОВАТЕЛЕЙ
#         (Устраняет причины сбоев Sysprep)
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 2: Вырезание встроенных AppX/UWP пакетов..." -ForegroundColor Cyan
foreach ($Mask in $Masks) {
    $CleanMask = $Mask.Trim()
    Get-AppxPackage -AllUsers -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like $CleanMask -or $_.PackageFullName -like $CleanMask } |
    ForEach-Object {
        Write-Host "  -> Удаление AppX: $($_.Name)" -ForegroundColor Yellow
        Remove-AppxPackage -Package $_.PackageFullName -AllUsers -ErrorAction SilentlyContinue
        Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -eq $_.Name } |
            Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
    }
}
Write-Host "[+] Шаг 2 завершён." -ForegroundColor Green

# --------------------------------------------------------------------------
# ШАГ 3: ГЛОБАЛЬНЫЕ ТВИКИ РЕЕСТРА HKLM
#         Телеметрия, Recall, Copilot, CEIP, WER, Delivery Optimization
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 3: Применение твиков конфиденциальности (HKLM)..." -ForegroundColor Cyan

$PolicyPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot",
    "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent",
    "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"
)
foreach ($Path in $PolicyPaths) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
}

Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"     -Name "AllowTelemetry"                 -Value 0 -Type DWord -Force
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"          -Name "TurnOffWindowsAIFeatures"       -Value 1 -Type DWord -Force
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"     -Name "TurnOffWindowsCopilot"          -Value 1 -Type DWord -Force
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows"          -Name "CEIPEnable"                     -Value 0 -Type DWord -Force
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting" -Name "Disabled"                  -Value 1 -Type DWord -Force
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization" -Name "DODownloadMode"               -Value 0 -Type DWord -Force
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"       -Name "DisableWindowsConsumerFeatures" -Value 1 -Type DWord -Force
Set-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Dsh"                        -Name "AllowNewsAndInterests"          -Value 0 -Type DWord -Force

# Отключаем только проблемные службы телеметрии.
# ВАЖНО: wuauserv (Windows Update) и sppsvc (активация) НЕ ТРОГАЕМ.
$ServicesToDisable = @(
    "DiagTrack",        # Телеметрия Connected User Experiences
    "dmwappushservice", # WAP Push Message Routing
    "StateRepository",  # Хранилище состояний приложений (телеметрия)
    "WMPNetworkSvc",    # Windows Media Player Network Sharing
    "msdtc"             # Distributed Transaction Coordinator (не нужен на раб. станции)
)
foreach ($Svc in $ServicesToDisable) {
    $s = Get-Service -Name $Svc -ErrorAction SilentlyContinue
    if ($s) {
        Stop-Service  -Name $Svc -Force -ErrorAction SilentlyContinue
        Set-Service   -Name $Svc -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Host "  -> Служба '$Svc' остановлена и отключена." -ForegroundColor Yellow
    }
}
Write-Host "[+] Шаг 3 завершён." -ForegroundColor Green

# --------------------------------------------------------------------------
# ШАГ 4: РАСШИФРОВКА BitLocker + СЖАТИЕ WinSxS + ФИКСАЦИЯ REARM
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 4: Расшифровка BitLocker и сжатие хранилища WinSxS..." -ForegroundColor Cyan

# Проверяем и отключаем BitLocker на C: (если активен)
$BdeStatus = & manage-bde -status C: 2>&1
if ($BdeStatus -match "Protection Status:\s+On") {
    Write-Host "  -> BitLocker активен. Запускаем расшифровку C:..." -ForegroundColor Yellow
    & manage-bde -off C: | Out-Null
    # Ждём завершения расшифровки
    do {
        Start-Sleep -Seconds 10
        $Status = (& manage-bde -status C: 2>&1) -join ""
    } while ($Status -match "Percentage Encrypted:\s+[1-9]")
    Write-Host "  -> BitLocker выключен." -ForegroundColor Green
} else {
    Write-Host "  -> BitLocker не активен. Пропускаем." -ForegroundColor Gray
}

# Очистка временных файлов перед сжатием WinSxS
$TempPaths = @(
    "C:\Windows\SoftwareDistribution\Download",
    "C:\Windows\Temp",
    "$env:USERPROFILE\AppData\Local\Temp"
)
foreach ($TPath in $TempPaths) {
    if (Test-Path $TPath) { Remove-Item -Path "$TPath\*" -Recurse -Force -ErrorAction SilentlyContinue }
}

# Жёсткое сжатие WinSxS (уменьшает размер итогового .pmf образа)
Write-Host "  -> Сжатие WinSxS (DISM /StartComponentCleanup /ResetBase)..." -ForegroundColor Yellow
& DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null

# Разрешение многократного сброса счётчика Rearm для Sysprep
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform" `
    -Name "SkipRearm" -Value 1 -Type DWord -Force

Write-Host "`n$(("=" * 74))" -ForegroundColor Green
Write-Host "  БАЗА ОЧИЩЕНА И ГОТОВА К SYSPREP." -ForegroundColor Green
Write-Host ("=" * 74) -ForegroundColor Green