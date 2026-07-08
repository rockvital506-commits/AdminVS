$script = @'
<#
.SYNOPSIS
    Откат изменений Блока 03A из снапшота.
.NOTES
    Кодировка: UTF-8 с BOM (гарантирована при создании).
#>
[CmdletBinding()]
param()

$ScriptPath = $PSScriptRoot
$BackupFile = Join-Path $ScriptPath "State_Backup.json"

if (-not (Test-Path $BackupFile)) {
    Write-Host "[X] Файл State_Backup.json не найден. Невозможно выполнить откат." -ForegroundColor Red
    pause; Exit 1
}

$Snapshot = Get-Content $BackupFile -Raw | ConvertFrom-Json

Write-Host "[!] ВНИМАНИЕ: Выполняется откат к состоянию до блокировок." -ForegroundColor Yellow
$confirm = Read-Host "Продолжить? (Y/N)"
if ($confirm -ne 'Y' -and $confirm -ne 'y') { Exit 0 }

# 1. ОТКАТ СЛУЖБ
Write-Host "`n[INFO] Восстановление служб..." -ForegroundColor Cyan
foreach ($Svc in $Snapshot.Services) {
    Write-Host "  -> $($Svc.Name) (Возврат к: $($Svc.OriginalStartType))" -ForegroundColor Gray
    if ($Svc.Method -eq 'Registry') {
        $StartVal = switch ($Svc.OriginalStartType) { 'Disabled' { 4 } 'Manual' { 3 } 'Automatic' { 2 } default { 3 } }
        Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\$($Svc.Name)" -Name "Start" -Value $StartVal -Type DWord -Force
    } else {
        Set-Service -Name $Svc.Name -StartupType $Svc.OriginalStartType -ErrorAction SilentlyContinue
    }
}

# 2. ОТКАТ РЕЕСТРА
Write-Host "`n[INFO] Восстановление реестра..." -ForegroundColor Cyan
foreach ($Key in $Snapshot.Registry) {
    if ($Key.OriginalValue -ne $null) {
        Set-ItemProperty -Path $Key.Path -Name $Key.Name -Value $Key.OriginalValue -Type $Key.Type -Force
        Write-Host "  -> Reg: $($Key.Name) = $($Key.OriginalValue)" -ForegroundColor Green
    }
}

Write-Host "`n[+] ОТКАТ ЗАВЕРШЕН. Рекомендуется перезагрузка." -ForegroundColor Green
pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\Rollback.ps1", $script, $utf8Bom)

Write-Host "[+] Файл Rollback.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green