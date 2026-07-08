$script = @'
<#
.SYNOPSIS
    Применение блокировок фоновой активности из block_config.json
.NOTES
    Запускать от имени Администратора в Audit Mode
    ВАЖНО: Файл должен быть сохранён в UTF-8 с BOM
#>

[CmdletBinding()]
param(
    [switch]$SkipBackup,
    [string]$ConfigFile = "block_config.json"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

if ($MyInvocation.MyCommand.Definition) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $ScriptPath = $PWD.Path
}

$ConfigPath = Join-Path $ScriptPath $ConfigFile
$LogFile = Join-Path $ScriptPath "block_log.txt"
$BackupFile = Join-Path $ScriptPath "block_backup.json"

Write-Host "[INFO] Script path: ${ScriptPath}" -ForegroundColor Gray
Write-Host "[INFO] Config path: ${ConfigPath}" -ForegroundColor Gray

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[X] КРИТИЧНО: Запустите скрипт от имени Администратора!" -ForegroundColor Red
    pause
    Exit 1
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "[X] КРИТИЧНО: Файл конфигурации '${ConfigPath}' не найден!" -ForegroundColor Red
    pause
    Exit 1
}

try {
    $Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[+] Конфигурация загружена: ${ConfigPath}" -ForegroundColor Green
}
catch {
    Write-Host "[X] Ошибка чтения конфигурации: $($_.Exception.Message)" -ForegroundColor Red
    pause
    Exit 1
}

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[${timestamp}] ${Message}"
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    Write-Host $logEntry -ForegroundColor $Color
}

# ==============================================================================
# ШАГ 0: ВРЕМЕННОЕ ОТКЛЮЧЕНИЕ WINDOWS DEFENDER (УСИЛЕННОЕ)
# ==============================================================================
Write-Log "=== ОТКЛЮЧЕНИЕ WINDOWS DEFENDER ===" "Yellow"

# Метод 1: Через Set-MpPreference
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction Stop
    Set-MpPreference -DisableIOAVProtection $true -ErrorAction Stop
    Write-Log "[+] Defender: Set-MpPreference выполнен" "Green"
}
catch {
    Write-Log "[!] Defender: Set-MpPreference не сработал - $($_.Exception.Message)" "Yellow"
}

# Метод 2: Отключение Tamper Protection через реестр
try {
    $TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
    if (Test-Path $TamperPath) {
        Set-ItemProperty -Path $TamperPath -Name "TamperProtection" -Value 0 -Type DWord -Force -ErrorAction Stop
        Write-Log "[+] Defender: TamperProtection отключен через реестр" "Green"
    }
}
catch {
    Write-Log "[!] Defender: TamperProtection - $($_.Exception.Message)" "Yellow"
}

# Метод 3: Group Policy для полного отключения
try {
    $PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $PolicyPath)) {
        New-Item -Path $PolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $PolicyPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction Stop
    
    $RealtimePath = "$PolicyPath\Real-Time Protection"
    if (-not (Test-Path $RealtimePath)) {
        New-Item -Path $RealtimePath -Force | Out-Null
    }
    Set-ItemProperty -Path $RealtimePath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force -ErrorAction Stop
    
    Write-Log "[+] Defender: Group Policy отключен" "Green"
}
catch {
    Write-Log "[!] Defender: Group Policy - $($_.Exception.Message)" "Yellow"
}

# ==============================================================================
# СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ
# ==============================================================================
if (-not $SkipBackup) {
    Write-Log "Создание резервной копии..." "Cyan"
    
    $Backup = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        services = @()
        registry = @()
        tasks = @()
        defender = @{}
    }
    
    foreach ($Category in $Config.services.PSObject.Properties) {
        foreach ($Item in $Category.Value.items) {
            $Service = Get-Service -Name $Item.name -ErrorAction SilentlyContinue
            if ($Service) {
                $Backup.services += @{
                    name = $Item.name
                    method = $Item.method
                    registry_path = if ($Item.registry_path) { $Item.registry_path } else { $null }
                    original_start = $Service.StartType.ToString()
                    original_status = $Service.Status.ToString()
                }
            }
        }
    }
    
    foreach ($Category in $Config.registry_keys.PSObject.Properties) {
        $RegPath = $Category.Value.path
        if (Test-Path $RegPath) {
            $RegValues = @()
            foreach ($Item in $Category.Value.items) {
                $CurrentValue = (Get-ItemProperty $RegPath -ErrorAction SilentlyContinue).$($Item.name)
                $RegValues += @{
                    name = $Item.name
                    value = $CurrentValue
                    type = $Item.type
                }
            }
            $Backup.registry += @{
                path = $RegPath
                values = $RegValues
            }
        }
    }
    
    foreach ($Category in $Config.scheduled_tasks.PSObject.Properties) {
        foreach ($Path in $Category.Value.paths) {
            $Tasks = Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue
            foreach ($Task in $Tasks) {
                $Backup.tasks += @{
                    name = $Task.TaskName
                    path = $Task.TaskPath
                    state = $Task.State.ToString()
                }
            }
        }
    }
    
    $MpPref = Get-MpPreference -ErrorAction SilentlyContinue
    if ($MpPref) {
        $Backup.defender = @{
            DisableRealtimeMonitoring = $MpPref.DisableRealtimeMonitoring
            DisableBehaviorMonitoring = $MpPref.DisableBehaviorMonitoring
            DisableIOAVProtection = $MpPref.DisableIOAVProtection
        }
    }
    
    $Backup | ConvertTo-Json -Depth 10 | Out-File $BackupFile -Encoding UTF8
    Write-Log "[+] Резервная копия создана: ${BackupFile}" "Green"
}

# ==============================================================================
# БЛОКИРОВКА СЛУЖБ С АВТОМАТИЧЕСКИМ FALLBACK
# ==============================================================================
Write-Log "=== НАЧАЛО БЛОКИРОВКИ СЛУЖБ ===" "Yellow"

foreach ($Category in $Config.services.PSObject.Properties) {
    Write-Log "--- $($Category.Value.description) ---" "Cyan"
    
    foreach ($Item in $Category.Value.items) {
        Write-Log "Обработка: $($Item.name)" "Gray"
        
        try {
            Stop-Service -Name $Item.name -Force -ErrorAction SilentlyContinue
            
            if ($Item.method -eq "service") {
                Set-Service -Name $Item.name -StartupType $Item.startup_type -ErrorAction Stop
                Write-Log "[+] $($Item.name) -> $($Item.startup_type) (Set-Service)" "Green"
            }
            elseif ($Item.method -eq "registry") {
                if (Test-Path $Item.registry_path) {
                    Set-ItemProperty -Path $Item.registry_path -Name "Start" -Value $Item.registry_value -Type DWord -Force -ErrorAction Stop
                    Write-Log "[+] $($Item.name) -> Start=$($Item.registry_value) (Registry)" "Green"
                }
                else {
                    Write-Log "[!] $($Item.name): путь реестра не найден" "Yellow"
                }
            }
        }
        catch {
            Write-Log "[X] $($Item.name): ошибка - $($_.Exception.Message)" "Red"
            
            if ($Item.method -eq "service") {
                Write-Log "    Попытка fallback через реестр..." "Yellow"
                $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Item.name)"
                if (Test-Path $RegPath) {
                    $StartValue = if ($Item.startup_type -eq "Disabled") { 4 } elseif ($Item.startup_type -eq "Manual") { 3 } else { 2 }
                    Set-ItemProperty -Path $RegPath -Name "Start" -Value $StartValue -Type DWord -Force -ErrorAction SilentlyContinue
                    Write-Log "[+] $($Item.name) -> Start=${StartValue} (Registry fallback)" "Green"
                }
            }
        }
    }
}

# ==============================================================================
# БЛОКИРОВКА КЛЮЧЕЙ РЕЕСТРА
# ==============================================================================
Write-Log "=== БЛОКИРОВКА КЛЮЧЕЙ РЕЕСТРА ===" "Yellow"

foreach ($Category in $Config.registry_keys.PSObject.Properties) {
    Write-Log "--- $($Category.Value.description) ---" "Cyan"
    
    $RegPath = $Category.Value.path
    
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
        Write-Log "[+] Создан раздел: ${RegPath}" "Green"
    }
    
    foreach ($Item in $Category.Value.items) {
        try {
            Set-ItemProperty -Path $RegPath -Name $Item.name -Value $Item.value -Type $Item.type -Force -ErrorAction Stop
            Write-Log "[+] $($Item.name) = $($Item.value)" "Green"
        }
        catch {
            Write-Log "[X] $($Item.name): ошибка - $($_.Exception.Message)" "Red"
        }
    }
}

# ==============================================================================
# БЛОКИРОВКА ЗАДАЧ ПЛАНИРОВЩИКА
# ==============================================================================
Write-Log "=== БЛОКИРОВКА ЗАДАЧ ПЛАНИРОВЩИКА ===" "Yellow"

foreach ($Category in $Config.scheduled_tasks.PSObject.Properties) {
    Write-Log "--- $($Category.Value.description) ---" "Cyan"
    
    foreach ($Path in $Category.Value.paths) {
        try {
            $Tasks = Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue
            
            if ($null -eq $Tasks -or $Tasks.Count -eq 0) {
                Write-Log "[~] Задачи не найдены: ${Path}" "Gray"
            }
            else {
                foreach ($Task in $Tasks) {
                    try {
                        Disable-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop | Out-Null
                        Write-Log "[+] Отключена: $($Task.TaskName)" "Green"
                    }
                    catch {
                        Write-Log "[!] $($Task.TaskName): Access Denied (защищено TrustedInstaller, не критично)" "Yellow"
                    }
                }
            }
        }
        catch {
            Write-Log "[X] Ошибка пути ${Path}: $($_.Exception.Message)" "Red"
        }
    }
}

# ==============================================================================
# ИТОГ
# ==============================================================================
Write-Log "=== БЛОКИРОВКА ЗАВЕРШЕНА ===" "Green"
Write-Host "`n[!] Запустите verify_block.ps1 для проверки результатов" -ForegroundColor Yellow

pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\apply_block.ps1", $script, $utf8Bom)

Write-Host "[+] Файл apply_block.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green