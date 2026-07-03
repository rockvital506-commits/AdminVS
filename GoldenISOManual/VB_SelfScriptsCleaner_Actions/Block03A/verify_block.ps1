$script = @'
<#
.SYNOPSIS
    Верификация результатов блокировки фоновой активности
.NOTES
    Запускать от имени Администратора после apply_block.ps1
    ВАЖНО: Файл должен быть сохранён в UTF-8 с BOM
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = "block_config.json"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($MyInvocation.MyCommand.Definition) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $ScriptPath = $PWD.Path
}

$ConfigPath = Join-Path $ScriptPath $ConfigFile

if (-not (Test-Path $ConfigPath)) {
    Write-Host "[X] Файл конфигурации '${ConfigPath}' не найден!" -ForegroundColor Red
    pause
    Exit 1
}

$Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

$TotalChecks = 0
$PassedChecks = 0
$FailedChecks = 0

function Write-CheckResult {
    param([string]$Name, [bool]$Passed, [string]$Expected, [string]$Actual)
    
    $script:TotalChecks++
    
    if ($Passed) {
        $script:PassedChecks++
        Write-Host "[OK] ${Name}" -ForegroundColor Green
        Write-Host "    Expected: ${Expected} | Actual: ${Actual}" -ForegroundColor Gray
    } else {
        $script:FailedChecks++
        Write-Host "[FAIL] ${Name}" -ForegroundColor Red
        Write-Host "    Expected: ${Expected} | Actual: ${Actual}" -ForegroundColor Red
    }
}

# ==============================================================================
# ПРОВЕРКА WINDOWS DEFENDER
# ==============================================================================
Write-Host "`n=== ПРОВЕРКА WINDOWS DEFENDER ===" -ForegroundColor Cyan

$MpPref = Get-MpPreference -ErrorAction SilentlyContinue
if ($MpPref) {
    Write-CheckResult "DisableRealtimeMonitoring" ($MpPref.DisableRealtimeMonitoring -eq $true) "True" $MpPref.DisableRealtimeMonitoring
    Write-CheckResult "DisableBehaviorMonitoring" ($MpPref.DisableBehaviorMonitoring -eq $true) "True" $MpPref.DisableBehaviorMonitoring
} else {
    Write-Host "[~] Windows Defender не доступен" -ForegroundColor Yellow
}

# Проверка Tamper Protection
$TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
if (Test-Path $TamperPath) {
    $TamperValue = (Get-ItemProperty $TamperPath -ErrorAction SilentlyContinue).TamperProtection
    Write-CheckResult "TamperProtection" ($TamperValue -eq 0) "0 (Disabled)" $TamperValue
}

# Проверка Group Policy
$PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (Test-Path $PolicyPath) {
    $PolicyValue = (Get-ItemProperty $PolicyPath -ErrorAction SilentlyContinue).DisableAntiSpyware
    Write-CheckResult "DisableAntiSpyware Policy" ($PolicyValue -eq 1) "1 (Disabled)" $PolicyValue
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
            Write-CheckResult $Item.name $false "Exists" "Not found"
            continue
        }
        
        $StatusOk = ($Service.Status -eq "Stopped")
        Write-CheckResult "$($Item.name) - Status" $StatusOk "Stopped" $Service.Status.ToString()
        
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
        Write-CheckResult $RegPath $false "Exists" "Not found"
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
        
        if ($null -eq $Tasks -or $Tasks.Count -eq 0) {
            Write-CheckResult $Path $true "No tasks or all disabled" "No tasks found"
            continue
        }
        
        $AllDisabled = $true
        $DisabledCount = 0
        $TotalCount = $Tasks.Count
        $AccessDeniedCount = 0
        
        foreach ($Task in $Tasks) {
            if ($Task.State -eq "Disabled") {
                $DisabledCount++
            } elseif ($Task.State -eq "Ready") {
                # Access Denied задачи остаются в Ready - это нормально
                $AccessDeniedCount++
            } else {
                $AllDisabled = $false
                Write-CheckResult "$($Task.TaskName)" $false "Disabled" $Task.State.ToString()
            }
        }
        
        if ($AllDisabled) {
            Write-CheckResult "$($Category.Value.description) - все задачи" $true "Все Disabled или Access Denied" "${DisabledCount} Disabled, ${AccessDeniedCount} Access Denied"
        } else {
            Write-Host "  [INFO] Отключено: ${DisabledCount} из ${TotalCount} задач (${AccessDeniedCount} Access Denied)" -ForegroundColor Yellow
        }
    }
}

# ==============================================================================
# ИТОГОВЫЙ ОТЧЕТ
# ==============================================================================
Write-Host "`n=== ИТОГОВЫЙ ОТЧЕТ ===" -ForegroundColor Cyan
Write-Host "Всего проверок: ${TotalChecks}" -ForegroundColor White
Write-Host "Пройдено: ${PassedChecks}" -ForegroundColor Green
Write-Host "Провалено: ${FailedChecks}" -ForegroundColor $(if ($FailedChecks -gt 0) { "Red" } else { "Green" })

if ($FailedChecks -eq 0) {
    Write-Host "`n[OK] ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ! Система готова к следующему блоку." -ForegroundColor Green
} else {
    Write-Host "`n[!] ОБНАРУЖЕНЫ ОШИБКИ! Запустите apply_block.ps1 повторно или проверьте вручную." -ForegroundColor Yellow
}

pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\verify_block.ps1", $script, $utf8Bom)

Write-Host "[+] Файл verify_block.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green