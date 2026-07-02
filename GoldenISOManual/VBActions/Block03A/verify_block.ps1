<#
.SYNOPSIS
    Верификация результатов блокировки фоновой активности
.DESCRIPTION
    Проверяет состояние всех служб, задач планировщика и ключей реестра 
    на соответствие конфигурации block_config.json
.NOTES
    Запускать от имени Администратора после apply_block.ps1
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = "block_config.json"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigPath = Join-Path $ScriptPath $ConfigFile

# Проверка конфигурации
if (-not (Test-Path $ConfigPath)) {
    Write-Host "[X] Файл конфигурации '$ConfigPath' не найден!" -ForegroundColor Red
    pause
    Exit 1
}

$Config = Get-Content $ConfigPath -Raw | ConvertFrom-Json

# Счетчики
$TotalChecks = 0
$PassedChecks = 0
$FailedChecks = 0

function Write-CheckResult {
    param([string]$Name, [bool]$Passed, [string]$Expected, [string]$Actual)
    
    $script:TotalChecks++
    
    if ($Passed) {
        $script:PassedChecks++
        Write-Host "[✓] $Name" -ForegroundColor Green
        Write-Host "    Ожидалось: $Expected | Фактически: $Actual" -ForegroundColor Gray
    } else {
        $script:FailedChecks++
        Write-Host "[✗] $Name" -ForegroundColor Red
        Write-Host "    Ожидалось: $Expected | Фактически: $Actual" -ForegroundColor Red
    }
}

# ==============================================================================
# ПРОВЕРКА СЛУЖБ
# ==============================================================================
Write-Host "`n=== ПРОВЕРКА СЛУЖБ ===" -ForegroundColor Cyan

foreach ($Category in $Config.services.PSObject.Properties) {
    Write-Host "`n--- $($Category.Value.description) ---" -ForegroundColor Yellow
    
    foreach ($Item in $Category.Value.items) {
        $Service = Get-Service -Name $Item.name -ErrorAction SilentlyContinue
        
        if (-not $Service) {
            Write-CheckResult $Item.name $false "Существует" "Не найдена"
            continue
        }
        
        # Проверка статуса (должна быть остановлена)
        $StatusOk = ($Service.Status -eq "Stopped")
        Write-CheckResult "$($Item.name) - Status" $StatusOk "Stopped" $Service.Status.ToString()
        
        # Проверка типа запуска
        if ($Item.method -eq "service") {
            $StartTypeOk = ($Service.StartType.ToString() -eq $Item.startup_type)
            Write-CheckResult "$($Item.name) - StartType" $StartTypeOk $Item.startup_type $Service.StartType.ToString()
        }
        elseif ($Item.method -eq "registry") {
            $RegValue = (Get-ItemProperty $Item.registry_path -ErrorAction SilentlyContinue).Start
            $StartOk = ($RegValue -eq $Item.registry_value)
            Write-CheckResult "$($Item.name) - Registry Start" $StartOk $Item.registry_value $RegValue
        }
    }
}

# ==============================================================================
# ПРОВЕРКА КЛЮЧЕЙ РЕЕСТРА
# ==============================================================================
Write-Host "`n=== ПРОВЕРКА КЛЮЧЕЙ РЕЕСТРА ===" -ForegroundColor Cyan

foreach ($Category in $Config.registry_keys.PSObject.Properties) {
    Write-Host "`n--- $($Category.Value.description) ---" -ForegroundColor Yellow
    
    $RegPath = $Category.Value.path
    
    if (-not (Test-Path $RegPath)) {
        Write-CheckResult $RegPath $false "Существует" "Не найден"
        continue
    }
    
    foreach ($Item in $Category.Value.items) {
        $ActualValue = (Get-ItemProperty $RegPath -ErrorAction SilentlyContinue).$($Item.name)
        $ValueOk = ($ActualValue -eq $Item.value)
        Write-CheckResult "$($Item.name)" $ValueOk $Item.value $ActualValue
    }
}

# ==============================================================================
# ПРОВЕРКА ЗАДАЧ ПЛАНИРОВЩИКА
# ==============================================================================
Write-Host "`n=== ПРОВЕРКА ЗАДАЧ ПЛАНИРОВЩИКА ===" -ForegroundColor Cyan

foreach ($Category in $Config.scheduled_tasks.PSObject.Properties) {
    Write-Host "`n--- $($Category.Value.description) ---" -ForegroundColor Yellow
    
    foreach ($Path in $Category.Value.paths) {
        $Tasks = Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue
        
        if ($Tasks.Count -eq 0) {
            Write-CheckResult $Path $true "Нет задач или все отключены" "Задач не найдено"
            continue
        }
        
        $AllDisabled = $true
        foreach ($Task in $Tasks) {
            if ($Task.State -ne "Disabled") {
                $AllDisabled = $false
                Write-CheckResult "$($Task.TaskName)" $false "Disabled" $Task.State.ToString()
            }
        }
        
        if ($AllDisabled) {
            Write-CheckResult "$($Category.Value.description) - все задачи" $true "Все Disabled" "OK"
        }
    }
}

# ==============================================================================
# ИТОГОВЫЙ ОТЧЕТ
# ==============================================================================
Write-Host "`n=== ИТОГОВЫЙ ОТЧЕТ ===" -ForegroundColor Cyan
Write-Host "Всего проверок: $TotalChecks" -ForegroundColor White
Write-Host "Пройдено: $PassedChecks" -ForegroundColor Green
Write-Host "Провалено: $FailedChecks" -ForegroundColor $(if ($FailedChecks -gt 0) { "Red" } else { "Green" })

if ($FailedChecks -eq 0) {
    Write-Host "`n[✓] ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ! Система готова к следующему блоку." -ForegroundColor Green
} else {
    Write-Host "`n[!] ОБНАРУЖЕНЫ ОШИБКИ! Запустите apply_block.ps1 повторно или проверьте вручную." -ForegroundColor Yellow
}

pause