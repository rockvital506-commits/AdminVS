$script = @'
<#
.SYNOPSIS
    Движок применения блокировок Блока 03A.
.DESCRIPTION
    Загружает Config.psd1, проверяет Tamper Protection, создает бэкап и применяет настройки.
.NOTES
    Требует: Запуск от имени Администратора.
    Кодировка: UTF-8 с BOM (гарантирована при создании).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "SilentlyContinue"
$ScriptPath = $PSScriptRoot
$ConfigFile = Join-Path $ScriptPath "Config.psd1"
$BackupFile = Join-Path $ScriptPath "State_Backup.json"

# 1. ПРОВЕРКА ПРАВ АДМИНИСТРАТОРА
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[X] КРИТИЧНО: Запустите PowerShell от имени Администратора!" -ForegroundColor Red
    pause; Exit 1
}

# 2. ЗАГРУЗКА КОНФИГУРАЦИИ
if (-not (Test-Path $ConfigFile)) {
    Write-Host "[X] Файл Config.psd1 не найден в папке: $ScriptPath" -ForegroundColor Red
    pause; Exit 1
}
$Config = Import-PowerShellDataFile -Path $ConfigFile
Write-Host "[+] Конфигурация загружена." -ForegroundColor Green

# 3. PRE-FLIGHT CHECK: TAMPER PROTECTION
$TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
$TamperValue = (Get-ItemProperty $TamperPath -ErrorAction SilentlyContinue).TamperProtection
if ($TamperValue -ne 0) {
    Write-Host "`n[X] КРИТИЧНО: Tamper Protection включен (Значение: $TamperValue)!" -ForegroundColor Red
    Write-Host "    ДЕЙСТВИЕ:" -ForegroundColor Yellow
    Write-Host "    1. Пуск -> 'Безопасность Windows' -> 'Защита от вирусов и угроз'" -ForegroundColor Yellow
    Write-Host "    2. 'Управление настройками' -> Выключите 'Защита от несанкционированного доступа'" -ForegroundColor Yellow
    Write-Host "    3. Перезагрузите ВМ и запустите скрипт снова" -ForegroundColor Yellow
    pause; Exit 1
}
Write-Host "[+] Tamper Protection: OK (Отключен)." -ForegroundColor Green

# 4. СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ (SNAPSHOT)
Write-Host "`n[INFO] Создание снапшота текущего состояния..." -ForegroundColor Cyan
$Snapshot = @{ Services = @(); Registry = @(); Tasks = @() }

foreach ($Block in $Config.Values) {
    if ($Block.Enabled -and $Block.Services) {
        foreach ($Svc in $Block.Services) {
            $ServiceObj = Get-Service -Name $Svc.Name -ErrorAction SilentlyContinue
            if ($ServiceObj) {
                $Snapshot.Services += @{
                    Name = $Svc.Name
                    OriginalStartType = $ServiceObj.StartType.ToString()
                    OriginalStatus = $ServiceObj.Status.ToString()
                    Method = $Svc.Method
                }
            }
        }
    }
}

if ($Config.RegistryPolicies.Enabled) {
    foreach ($Key in $Config.RegistryPolicies.Keys) {
        $CurrentVal = (Get-ItemProperty -Path $Key.Path -ErrorAction SilentlyContinue).$($Key.Name)
        $Snapshot.Registry += @{
            Path = $Key.Path; Name = $Key.Name; OriginalValue = $CurrentVal; Type = $Key.Type
        }
    }
}

$Snapshot | ConvertTo-Json -Depth 10 | Out-File $BackupFile -Encoding UTF8
Write-Host "[+] Снапшот сохранен: $BackupFile" -ForegroundColor Green

# 5. ПРИМЕНЕНИЕ БЛОКИРОВОК
Write-Host "`n[INFO] Применение блокировок..." -ForegroundColor Cyan

foreach ($BlockName in $Config.Keys) {
    $Block = $Config.$BlockName
    if (-not $Block.Enabled) { continue }

    Write-Host "`n--- Обработка блока: $BlockName ---" -ForegroundColor Yellow

    if ($Block.Services) {
        foreach ($Svc in $Block.Services) {
            Write-Host "  -> $($Svc.Name) (Метод: $($Svc.Method))" -ForegroundColor Gray
            
            Stop-Service -Name $Svc.Name -Force -ErrorAction SilentlyContinue
            
            if ($Svc.Method -eq 'Service') {
                try {
                    Set-Service -Name $Svc.Name -StartupType $Svc.State -ErrorAction Stop
                    Write-Host "     [OK] Set-Service -> $($Svc.State)" -ForegroundColor Green
                } catch {
                    # Fallback на реестр
                    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Svc.Name)"
                    $StartVal = if ($Svc.State -eq 'Disabled') { 4 } elseif ($Svc.State -eq 'Manual') { 3 } else { 2 }
                    Set-ItemProperty -Path $RegPath -Name "Start" -Value $StartVal -Type DWord -Force
                    Write-Host "     [OK] Registry Fallback -> Start=$StartVal" -ForegroundColor Green
                }
            } elseif ($Svc.Method -eq 'Registry') {
                $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Svc.Name)"
                $StartVal = if ($Svc.State -eq 'Disabled') { 4 } else { 3 }
                Set-ItemProperty -Path $RegPath -Name "Start" -Value $StartVal -Type DWord -Force
                Write-Host "     [OK] Registry Direct -> Start=$StartVal" -ForegroundColor Green
            }
        }
    }

    if ($Block.Keys) {
        foreach ($Key in $Block.Keys) {
            if (-not (Test-Path $Key.Path)) { New-Item -Path $Key.Path -Force | Out-Null }
            Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.Value -Type $Key.Type -Force
            Write-Host "  -> Reg: $($Key.Name) = $($Key.Value)" -ForegroundColor Green
        }
    }

    if ($Block.Paths) {
        foreach ($Path in $Block.Paths) {
            $Tasks = Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue
            foreach ($Task in $Tasks) {
                try {
                    Disable-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop | Out-Null
                    Write-Host "  -> Task Disabled: $($Task.TaskName)" -ForegroundColor Green
                } catch {
                    Write-Host "  -> Task Skipped (Access Denied): $($Task.TaskName)" -ForegroundColor DarkYellow
                }
            }
        }
    }
}

Write-Host "`n[+] БЛОК 03A УСПЕШНО ПРИМЕНЕН." -ForegroundColor Green
Write-Host "[!] Запустите Verify.ps1 для проверки результата." -ForegroundColor Yellow
pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\Apply.ps1", $script, $utf8Bom)

Write-Host "[+] Файл Apply.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green