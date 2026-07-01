<#
.SYNOPSIS
    Глобальная оптимизация Windows 11 (25H2) Pro для создания эталонного образа.
    Расположение: [Флешка]\complete_cleaner.ps1
    Кодировка: UTF-8
    Запуск: От имени Администратора из-под профиля Admin
.DESCRIPTION
    - Безопасно удаляет Win32 и UWP приложения по маскам
    - Отключает телеметрию, ИИ-компоненты (Recall/Copilot)
    - Очищает WinSxS и временные файлы
    - Подготавливает систему к Sysprep
.NOTES
    Автор: Инженерный отдел
    Версия: 2.1
    Требует: Windows 11 Pro 25H2, права Administrator
    Время выполнения: 15-45 минут
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  ГЛОБАЛЬНАЯ ОЧИСТКА И ОПТИМИЗАЦИЯ WINDOWS 11 (25H2) PRO                  " -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan

# Определение пути к скрипту и файлу масок
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$MasksFile = Join-Path $ScriptPath "apps_to_remove.txt"

if (-not (Test-Path $MasksFile)) {
    Write-Error "❌ КРИТИЧЕСКАЯ ОШИБКА: Файл '$MasksFile' не найден!"
    Write-Host "   Убедитесь, что apps_to_remove.txt лежит в той же папке." -ForegroundColor Red
    pause
    exit 1
}

Write-Host "`n[INFO] Загрузка масок из: $MasksFile" -ForegroundColor Gray
$Masks = Get-Content -Path $MasksFile | Where-Object { 
    $_.Trim() -ne "" -and -not $_.Trim().StartsWith("#") 
}

Write-Host "[OK] Загружено $($Masks.Count) масок для обработки`n" -ForegroundColor Green

# ==============================================================================
# ШАГ 1: БЕЗОПАСНОЕ УДАЛЕНИЕ WIN32 ПРИЛОЖЕНИЙ ЧЕРЕЗ РЕЕСТР
# ==============================================================================
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  ШАГ 1/5: Удаление Win32 приложений (Win32_Product НЕ используется)      " -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan

$UninstallPaths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)

$RemovedCount = 0
$FailedCount = 0

foreach ($Mask in $Masks) {
    $CleanMask = $Mask.Trim().Replace("*", "")
    if ($CleanMask -eq "") { continue }
    
    Write-Host "`n[SEARCH] Маска: '$CleanMask'" -ForegroundColor Gray
    
    $FoundApps = Get-ItemProperty $UninstallPaths -ErrorAction SilentlyContinue | 
        Where-Object { 
            $_.DisplayName -like "*$CleanMask*" -and 
            $_.UninstallString -ne $null 
        } | Select-Object DisplayName, UninstallString, QuietUninstallString -Unique
    
    foreach ($App in $FoundApps) {
        try {
            Write-Host "  → Удаление: $($App.DisplayName)" -ForegroundColor Yellow
            
            $UnCmd = $App.UninstallString
            
            # Приоритет тихой uninstall строки
            if ($App.QuietUninstallString) { 
                $UnCmd = $App.QuietUninstallString 
            }
            
            # Инъекция флагов тишины для MSI
            if ($UnCmd -match "msiexec") { 
                $UnCmd += " /qn /norestart" 
                Write-Host "    [MSI] Добавлены флаги: /qn /norestart" -ForegroundColor Gray
            }
            
            # Выполнение удаления
            Start-Process cmd.exe -ArgumentList "/c `"$UnCmd`"" -Wait -NoNewWindow -ErrorAction Stop
            
            Write-Host "    [OK] Удалено успешно" -ForegroundColor Green
            $RemovedCount++
        }
        catch {
            Write-Host "    [FAIL] Ошибка удаления: $($_.Exception.Message)" -ForegroundColor Red
            $FailedCount++
        }
    }
}

Write-Host "`n[РЕЗУЛЬТАТ] Удалено: $RemovedCount, Ошибок: $FailedCount" -ForegroundColor Cyan

# ==============================================================================
# ШАГ 2: УДАЛЕНИЕ APPX/UWP ПАКЕТОВ (ВСЕ ПОЛЬЗОВАТЕЛИ)
# ==============================================================================
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  ШАГ 2/5: Удаление AppX/UWP пакетов (AllUsers)                          " -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan

$AppXRemoved = 0
$ProvisionedRemoved = 0

foreach ($Mask in $Masks) {
    $CleanMask = $Mask.Trim()
    
    # Поиск установленных пакетов
    $AppXPackages = Get-AppxPackage -AllUsers | Where-Object { 
        ($_.Name -like "*$CleanMask*" -or $_.PackageFullName -like "*$CleanMask*") 
    } -ErrorAction SilentlyContinue
    
    foreach ($Pkg in $AppXPackages) {
        try {
            Write-Host "  → AppX: $($Pkg.Name)" -ForegroundColor Yellow
            Remove-AppxPackage -Package $Pkg.PackageFullName -AllUsers -ErrorAction Stop
            Write-Host "    [OK] Удален" -ForegroundColor Green
            $AppXRemoved++
        }
        catch {
            Write-Host "    [WARN] Не удален: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
    
    # Удаление из provisioning (будущие установки)
    $ProvPackages = Get-AppxProvisionedPackage -Online | Where-Object { 
        $_.DisplayName -like "*$CleanMask*" 
    }
    
    foreach ($Pkg in $ProvPackages) {
        try {
            Write-Host "  → Provisioned: $($Pkg.DisplayName)" -ForegroundColor Yellow
            Remove-AppxProvisionedPackage -Online -PackageName $Pkg.PackageName -ErrorAction Stop
            Write-Host "    [OK] Удален из provisioning" -ForegroundColor Green
            $ProvisionedRemoved++
        }
        catch {
            Write-Host "    [WARN] Не удален: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n[РЕЗУЛЬТАТ] AppX удалено: $AppXRemoved, Provisioned: $ProvisionedRemoved" -ForegroundColor Cyan

# ==============================================================================
# ШАГ 3: ОТКЛЮЧЕНИЕ ТЕЛЕМЕТРИИ И ИИ-КОМПОНЕНТОВ (HKLM)
# ==============================================================================
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  ШАГ 3/5: Блокировка телеметрии, Recall, Copilot, служб                 " -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan

$TweaksApplied = 0

# Создание необходимых разделов реестра
$RegPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent",
    "HKLM:\SOFTWARE\Policies\Microsoft\Dsh",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
)

foreach ($Path in $RegPaths) {
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
        Write-Host "  [CREATE] $Path" -ForegroundColor Gray
    }
}

# Применение твиков
$Tweaks = @(
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"; Name="AllowTelemetry"; Value=0; Type="DWord"; Desc="Уровень телеметрии"},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"; Name="TurnOffWindowsAIFeatures"; Value=1; Type="DWord"; Desc="Отключение ИИ"},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot"; Name="TurnOffWindowsCopilot"; Value=1; Type="DWord"; Desc="Отключение Copilot"},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"; Name="DisableWindowsConsumerFeatures"; Value=1; Type="DWord"; Desc="Блокировка потребительских функций"},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Dsh"; Name="AllowNewsAndInterests"; Value=0; Type="DWord"; Desc="Отключение новостной ленты"},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting"; Name="Disabled"; Value=1; Type="DWord"; Desc="Отключение отчетов об ошибках"},
    @{Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"; Name="DODownloadMode"; Value=0; Type="DWord"; Desc="Отключение доставки обновлений P2P"}
)

foreach ($Tweak in $Tweaks) {
    try {
        Set-ItemProperty -Path $Tweak.Path -Name $Tweak.Name -Value $Tweak.Value -Type $Tweak.Type -Force -ErrorAction Stop
        Write-Host "  [OK] $($Tweak.Desc)" -ForegroundColor Green
        $TweaksApplied++
    }
    catch {
        Write-Host "  [FAIL] $($Tweak.Desc): $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Отключение служб
$ServicesToDisable = @(
    @{Name="DiagTrack"; Desc="Connected User Experiences and Telemetry"},
    @{Name="dmwappushservice"; Desc="WAP Push Message Routing Service"},
    @{Name="SysMain"; Desc="SysMain (SuperFetch)"},
    @{Name="WMPNetworkSvc"; Desc="Windows Media Player Network Sharing Service"}
)

foreach ($Service in $ServicesToDisable) {
    if (Get-Service -Name $Service.Name -ErrorAction SilentlyContinue) {
        try {
            Stop-Service -Name $Service.Name -Force -ErrorAction Stop
            Set-Service -Name $Service.Name -StartupType Disabled -ErrorAction Stop
            Write-Host "  [OK] Отключена служба: $($Service.Desc)" -ForegroundColor Green
            $TweaksApplied++
        }
        catch {
            Write-Host "  [WARN] Не отключена $($Service.Name): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

Write-Host "`n[РЕЗУЛЬТАТ] Применено твиков: $TweaksApplied" -ForegroundColor Cyan

# ==============================================================================
# ШАГ 4: ОЧИСТКА ВРЕМЕННЫХ ФАЙЛОВ И WINsxs
# ==============================================================================
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  ШАГ 4/5: Очистка временных файлов и хранилища компонентов              " -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan

# Отключение BitLocker (если включен)
Write-Host "`n[INFO] Проверка BitLocker..." -ForegroundColor Gray
try {
    $BitLockerStatus = manage-bde -status C: 2>$null
    if ($BitLockerStatus -match "Protection Status:\s+On") {
        Write-Host "  [WARN] BitLocker включен. Начинается расшифровка (может занять 1-2 часа)..." -ForegroundColor Yellow
        manage-bde -off C:
        
        Write-Host "  [WAIT] Ожидание завершения расшифровки..." -ForegroundColor Yellow
        do {
            Start-Sleep -Seconds 10
            $Status = manage-bde -status C:
        } while ($Status -match "Percentage Encrypted:\s+[^0]")
        
        Write-Host "  [OK] BitLocker отключен" -ForegroundColor Green
    } else {
        Write-Host "  [OK] BitLocker отключен или не установлен" -ForegroundColor Green
    }
}
catch {
    Write-Host "  [WARN] Не удалось проверить BitLocker: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Очистка временных папок
$TempPaths = @(
    "C:\Windows\Temp",
    "C:\Windows\SoftwareDistribution\Download",
    "$env:USERPROFILE\AppData\Local\Temp"
)

foreach ($TPath in $TempPaths) {
    if (Test-Path $TPath) {
        try {
            $ItemCount = (Get-ChildItem -Path $TPath -Recurse -ErrorAction SilentlyContinue | Measure-Object).Count
            Write-Host "  [CLEAN] $TPath ($ItemCount объектов)" -ForegroundColor Yellow
            Remove-Item -Path "$TPath\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "    [OK] Очищено" -ForegroundColor Green
        }
        catch {
            Write-Host "    [WARN] Не очищено: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# Сжатие WinSxS
Write-Host "`n[INFO] Запуск DISM Cleanup (может занять 20-60 минут)..." -ForegroundColor Yellow
Write-Host "  [WAIT] Пожалуйста, дождитесь завершения..." -ForegroundColor Gray

try {
    $DismResult = & DISM.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [OK] WinSxS очищен и сжат" -ForegroundColor Green
    } else {
        Write-Host "  [WARN] DISM завершил с предупреждениями" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  [FAIL] Ошибка DISM: $($_.Exception.Message)" -ForegroundColor Red
}

# ==============================================================================
# ШАГ 5: ФИНАЛИЗАЦИЯ И ПОДГОТОВКА К SYSPREP
# ==============================================================================
Write-Host "`n==========================================================================" -ForegroundColor Cyan
Write-Host "  ШАГ 5/5: Финализация и подготовка к Sysprep                            " -ForegroundColor Yellow
Write-Host "==========================================================================" -ForegroundColor Cyan

# Проверка места на диске
$DiskSpace = Get-Volume -DriveLetter C | Select-Object SizeRemaining, Size
$FreeGB = [math]::Round($DiskSpace.SizeRemaining / 1GB, 2)
$TotalGB = [math]::Round($DiskSpace.Size / 1GB, 2)

Write-Host "`n[INFO] Свободно на диске C: $FreeGB GB из $TotalGB GB" -ForegroundColor Cyan

if ($FreeGB -lt 20) {
    Write-Host "  [WARN] Мало свободного места! Рекомендуется минимум 20GB" -ForegroundColor Yellow
}

# Очистка корзины
Write-Host "`n[INFO] Очистка корзины..." -ForegroundColor Gray
Clear-RecycleBin -Force -ErrorAction SilentlyContinue
Write-Host "  [OK] Корзина очищена" -ForegroundColor Green

# Дефрагментация (для HDD)
$DriveType = Get-PhysicalDisk | Where-Object {$_.DeviceId -eq "0"} | Select-Object MediaType -ExpandProperty MediaType
if ($DriveType -eq "HDD") {
    Write-Host "`n[INFO] Запуск дефрагментации (HDD обнаружен)..." -ForegroundColor Yellow
    Optimize-Volume -DriveLetter C -Defrag -Verbose
    Write-Host "  [OK] Дефрагментация завершена" -ForegroundColor Green
} else {
    Write-Host "`n[INFO] SSD обнаружен. Дефрагментация не требуется." -ForegroundColor Gray
    Optimize-Volume -DriveLetter C -Trim -Verbose
    Write-Host "  [OK] TRIM выполнен" -ForegroundColor Green
}

# ==============================================================================
# ИТОГОВЫЙ ОТЧЕТ
# ==============================================================================
Write-Host "`n==========================================================================" -ForegroundColor Green
Write-Host "  ✅ БАЗА УСПЕШНО ОЧИЩЕНА И ГОТОВА К СОЗДАНИЮ ОБРАЗА!                     " -ForegroundColor Green
Write-Host "==========================================================================" -ForegroundColor Green
Write-Host "`n[СЛЕДУЮЩИЙ ШАГ]:" -ForegroundColor Cyan
Write-Host "  1. Убедитесь, что все обновления Windows установлены" -ForegroundColor White
Write-Host "  2. Установите необходимые программы (VS Code, Docker и т.д.)" -ForegroundColor White
Write-Host "  3. Перейдите к Части 3, Этап 5 (Sysprep)" -ForegroundColor White
Write-Host "`n[ВАЖНО]:" -ForegroundColor Yellow
Write-Host "  - Не перезагружайте систему до выполнения Sysprep" -ForegroundColor White
Write-Host "  - Не создавайте новых пользователей" -ForegroundColor White
Write-Host "  - Не подключайте интернет до финальной настройки" -ForegroundColor White
Write-Host "`n" -ForegroundColor White

pause