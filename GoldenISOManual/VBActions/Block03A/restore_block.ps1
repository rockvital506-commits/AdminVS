$script = @'
<#
.SYNOPSIS
    Откат блокировок фоновой активности из резервной копии
.DESCRIPTION
    Восстанавливает исходное состояние служб, задач и реестра из block_backup.json
    КРИТИЧНО: Для защищённых служб (DoSvc, AppXSvc, ClipSVC, InstallService, WaaSMedicSvc)
    используется реестр, а не Set-Service.
.NOTES
    Запускать от имени Администратора
    Требует: block_backup.json (создается автоматически при apply_block.ps1)
    ВАЖНО: Файл должен быть сохранён в UTF-8 с BOM
#>

[CmdletBinding()]
param(
    [string]$BackupFile = "block_backup.json"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$BackupPath = Join-Path $ScriptPath $BackupFile

# Проверка резервной копии
if (-not (Test-Path $BackupPath)) {
    Write-Host "[X] Резервная копия '$BackupPath' не найдена!" -ForegroundColor Red
    Write-Host "    Запустите apply_block.ps1 с параметром -CreateBackup для создания копии" -ForegroundColor Yellow
    pause
    Exit 1
}

$Backup = Get-Content $BackupPath -Raw -Encoding UTF8 | ConvertFrom-Json

Write-Host "[!] ВНИМАНИЕ: Откат изменений из резервной копии от $($Backup.timestamp)" -ForegroundColor Yellow
Write-Host "    Продолжить? (Y/N)" -ForegroundColor Yellow
$confirm = Read-Host
if ($confirm -ne "Y" -and $confirm -ne "y") {
    Write-Host "Отменено." -ForegroundColor Gray
    Exit 0
}

# ==============================================================================
# ВОССТАНОВЛЕНИЕ WINDOWS DEFENDER
# ==============================================================================
Write-Host "`n=== ВОССТАНОВЛЕНИЕ WINDOWS DEFENDER ===" -ForegroundColor Cyan

if ($Backup.defender -and $Backup.defender.PSObject.Properties.Count -gt 0) {
    try {
        if ($Backup.defender.DisableRealtimeMonitoring -eq $true) {
            Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction Stop
            Write-Host "[+] DisableRealtimeMonitoring -> False" -ForegroundColor Green
        }
        if ($Backup.defender.DisableBehaviorMonitoring -eq $true) {
            Set-MpPreference -DisableBehaviorMonitoring $false -ErrorAction Stop
            Write-Host "[+] DisableBehaviorMonitoring -> False" -ForegroundColor Green
        }
        if ($Backup.defender.DisableIOAVProtection -eq $true) {
            Set-MpPreference -DisableIOAVProtection $false -ErrorAction Stop
            Write-Host "[+] DisableIOAVProtection -> False" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[X] Defender: $($_.Exception.Message)" -ForegroundColor Red
    }
} else {
    Write-Host "[~] Defender: данные не найдены в backup" -ForegroundColor Gray
}

# ==============================================================================
# ВОССТАНОВЛЕНИЕ СЛУЖБ (С УЧЁТОМ МЕТОДА)
# ==============================================================================
Write-Host "`n=== ВОССТАНОВЛЕНИЕ СЛУЖБ ===" -ForegroundColor Cyan

foreach ($Service in $Backup.services) {
    try {
        if ($Service.method -eq "registry" -and $Service.registry_path) {
            # КРИТИЧНО: Для защищённых служб используем реестр
            $StartValue = if ($Service.original_start -eq "Disabled") { 4 } elseif ($Service.original_start -eq "Manual") { 3 } elseif ($Service.original_start -eq "Automatic") { 2 } else { 3 }
            
            if (Test-Path $Service.registry_path) {
                Set-ItemProperty -Path $Service.registry_path -Name "Start" -Value $StartValue -Type DWord -Force -ErrorAction Stop
                Write-Host "[+] $($Service.name) -> Start=$StartValue (Registry)" -ForegroundColor Green
            } else {
                Write-Host "[!] $($Service.name): путь реестра не найден" -ForegroundColor Yellow
            }
        }
        else {
            # Обычные службы через Set-Service
            Set-Service -Name $Service.name -StartupType $Service.original_start -ErrorAction Stop
            Write-Host "[+] $($Service.name) -> $($Service.original_start) (Set-Service)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[X] $($Service.name): $($_.Exception.Message)" -ForegroundColor Red
        
        # Fallback на реестр
        Write-Host "    Попытка fallback через реестр..." -ForegroundColor Yellow
        $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Service.name)"
        if (Test-Path $RegPath) {
            $StartValue = if ($Service.original_start -eq "Disabled") { 4 } elseif ($Service.original_start -eq "Manual") { 3 } elseif ($Service.original_start -eq "Automatic") { 2 } else { 3 }
            Set-ItemProperty -Path $RegPath -Name "Start" -Value $StartValue -Type DWord -Force -ErrorAction SilentlyContinue
            Write-Host "[+] $($Service.name) -> Start=$StartValue (Registry fallback)" -ForegroundColor Green
        }
    }
}

# ==============================================================================
# ВОССТАНОВЛЕНИЕ РЕЕСТРА (С УЧЁТОМ ТИПА)
# ==============================================================================
Write-Host "`n=== ВОССТАНОВЛЕНИЕ РЕЕСТРА ===" -ForegroundColor Cyan

foreach ($RegEntry in $Backup.registry) {
    foreach ($Value in $RegEntry.values) {
        try {
            # Определяем тип значения
            $RegType = if ($Value.type -eq "DWord") { [Microsoft.Win32.RegistryValueKind]::DWord } else { [Microsoft.Win32.RegistryValueKind]::String }
            
            Set-ItemProperty -Path $RegEntry.path -Name $Value.name -Value $Value.value -Type $RegType -Force -ErrorAction Stop
            Write-Host "[+] $($RegEntry.path)\$($Value.name) = $($Value.value) ($($Value.type))" -ForegroundColor Green
        }
        catch {
            Write-Host "[X] $($RegEntry.path)\$($Value.name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# ==============================================================================
# СБРОС ПОЛИТИК (если они были изменены)
# ==============================================================================
Write-Host "`n=== СБРОС ПОЛИТИК ===" -ForegroundColor Cyan

$PolicyPaths = @(
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization",
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"
)

foreach ($Path in $PolicyPaths) {
    if (Test-Path $Path) {
        try {
            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            Write-Host "[+] Удалена политика: $Path" -ForegroundColor Green
        }
        catch {
            Write-Host "[!] $Path : $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# ==============================================================================
# ВОССТАНОВЛЕНИЕ ЗАДАЧ ПЛАНИРОВЩИКА
# ==============================================================================
Write-Host "`n=== ВОССТАНОВЛЕНИЕ ЗАДАЧ ===" -ForegroundColor Cyan

foreach ($Task in $Backup.tasks) {
    try {
        Enable-ScheduledTask -TaskName $Task.name -TaskPath $Task.path -ErrorAction Stop | Out-Null
        Write-Host "[+] $($Task.name) -> Enabled" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] $($Task.name): Access Denied (защищено TrustedInstaller)" -ForegroundColor Yellow
    }
}

# ==============================================================================
# ИТОГ
# ==============================================================================
Write-Host "`n[+] ОТКАТ ЗАВЕРШЕН" -ForegroundColor Green
Write-Host "[!] Рекомендуется перезагрузить систему для применения изменений" -ForegroundColor Yellow

pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\restore_block.ps1", $script, $utf8Bom)

Write-Host "[+] Файл restore_block.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green