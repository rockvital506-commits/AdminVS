$script = @'
<#
.SYNOPSIS
    Dashboard верификации Блока 03A.
.DESCRIPTION
    Показывает фактическое состояние системы в сравнении с Config.psd1.
.NOTES
    Кодировка: UTF-8 с BOM (гарантирована при создании).
#>
[CmdletBinding()]
param()

$ScriptPath = $PSScriptRoot
$Config = Import-PowerShellDataFile -Path (Join-Path $ScriptPath "Config.psd1")

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  DASHBOARD: ПРОВЕРКА БЛОКА 03A" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

$Total = 0; $Passed = 0; $Failed = 0

function Show-Status {
    param($Name, $Expected, $Actual, $Status)
    $Total++
    if ($Status -eq 'OK') { 
        $Passed++; Write-Host "[OK]   $Name" -ForegroundColor Green 
    } else { 
        $Failed++; Write-Host "[FAIL] $Name (Ожидалось: $Expected | Факт: $Actual)" -ForegroundColor Red 
    }
}

# 1. ПРОВЕРКА СЛУЖБ
Write-Host "--- СЛУЖБЫ ---" -ForegroundColor Yellow
foreach ($Block in $Config.Values) {
    if ($Block.Enabled -and $Block.Services) {
        foreach ($Svc in $Block.Services) {
            $Obj = Get-Service -Name $Svc.Name -ErrorAction SilentlyContinue
            if (-not $Obj) { Show-Status $Svc.Name "Exists" "Not Found" "FAIL"; continue }
            
            $ExpStatus = if ($Svc.State -eq 'Disabled') { 'Stopped' } else { 'Any' }
            $ActStatus = $Obj.Status.ToString()
            $St = if ($ExpStatus -eq 'Any' -or $ActStatus -eq $ExpStatus) { 'OK' } else { 'FAIL' }
            Show-Status "$($Svc.Name) [Status]" $ExpStatus $ActStatus $St

            if ($Svc.Method -eq 'Registry') {
                $RegVal = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$($Svc.Name)" -ErrorAction SilentlyContinue).Start
                $ExpStart = if ($Svc.State -eq 'Disabled') { 4 } else { 3 }
                $St = if ($RegVal -eq $ExpStart) { 'OK' } else { 'FAIL' }
                Show-Status "$($Svc.Name) [RegStart]" $ExpStart $RegVal $St
            } else {
                $ExpStart = $Svc.State
                $ActStart = $Obj.StartType.ToString()
                $St = if ($ActStart -eq $ExpStart) { 'OK' } else { 'FAIL' }
                Show-Status "$($Svc.Name) [StartType]" $ExpStart $ActStart $St
            }
        }
    }
}

# 2. ПРОВЕРКА РЕЕСТРА
Write-Host "`n--- РЕЕСТР ---" -ForegroundColor Yellow
if ($Config.RegistryPolicies.Enabled) {
    foreach ($Key in $Config.RegistryPolicies.Keys) {
        $ActVal = (Get-ItemProperty -Path $Key.Path -ErrorAction SilentlyContinue).$($Key.Name)
        $St = if ($ActVal -eq $Key.Value) { 'OK' } else { 'FAIL' }
        Show-Status "Reg: $($Key.Name)" $Key.Value $ActVal $St
    }
}

# 3. ИТОГ
Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  ВСЕГО: $Total | ПРОЙДЕНО: $Passed | ПРОВАЛЕНО: $Failed" -ForegroundColor White
if ($Failed -eq 0) { Write-Host "  [OK] СИСТЕМА ГОТОВА К СЛЕДУЮЩЕМУ БЛОКУ." -ForegroundColor Green }
else { Write-Host "  [!] ТРЕБУЕТСЯ ВНИМАНИЕ." -ForegroundColor Red }
Write-Host "========================================================================`n" -ForegroundColor Cyan
pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\Verify.ps1", $script, $utf8Bom)

Write-Host "[+] Файл Verify.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green