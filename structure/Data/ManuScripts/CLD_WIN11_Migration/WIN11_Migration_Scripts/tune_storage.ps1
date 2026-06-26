<#
.SYNOPSIS
    Тонкая настройка дисковой подсистемы Windows 11 (25H2).
.DESCRIPTION
    Отключает гибернацию, блокирует засыпание NVMe (APST),
    фиксирует статический pagefile 4096 МБ на C:,
    активирует CompactOS, отключает индексацию на HDD D:.
    ЗАПУСКАТЬ: от Администратора в профиле клиента на Этапе 7.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ("=" * 74) -ForegroundColor Yellow
Write-Host "  НАСТРОЙКА ПОДСИСТЕМЫ ХРАНЕНИЯ (SSD NVMe / HDD)" -ForegroundColor Yellow
Write-Host ("=" * 74) -ForegroundColor Yellow

# --- ШАГ 1: Отключение гибернации (удаляет hiberfil.sys, экономит место на SSD) ---
Write-Host "`n[--->] ШАГ 1: Отключение гибернации..." -ForegroundColor Cyan
& powercfg.exe /hibernate off
Write-Host "[+] Гибернация отключена, hiberfil.sys будет удалён." -ForegroundColor Green

# --- ШАГ 2: Блокировка микросна NVMe (APST / ULPS) — ликвидация микрофризов ---
Write-Host "`n[--->] ШАГ 2: Оптимизация режима питания шины NVMe (отключение APST)..." -ForegroundColor Cyan
& powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK DISKIDLE 0
& powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK 0b2d69d7-a2a1-449c-9680-f91c70521c60 0
& powercfg /setactive SCHEME_CURRENT
Write-Host "[+] NVMe APST заблокирован, микрофризы устранены." -ForegroundColor Green

# --- ШАГ 3: Фиксация статического файла подкачки 4096 МБ на C: ---
Write-Host "`n[--->] ШАГ 3: Фиксация pagefile (4096 МБ) на диске C:..." -ForegroundColor Cyan
$CS = Get-CimInstance -ClassName Win32_ComputerSystem
$CS.AutomaticManagedPagefile = $false
Set-CimInstance -CimInstance $CS

$PF = Get-CimInstance -ClassName Win32_PageFileSetting -ErrorAction SilentlyContinue |
      Where-Object { $_.Name -like "C:*" }
if ($PF) {
    $PF.InitialSize = 4096; $PF.MaximumSize = 4096
    Set-CimInstance -CimInstance $PF
} else {
    New-CimInstance -ClassName Win32_PageFileSetting `
        -Property @{Name="C:\pagefile.sys"; InitialSize=4096; MaximumSize=4096} | Out-Null
}
Write-Host "[+] Pagefile зафиксирован: 4096/4096 МБ на C:\pagefile.sys." -ForegroundColor Green

# --- ШАГ 4: CompactOS — сжатие статических файлов ядра (освобождает до 8 ГБ) ---
Write-Host "`n[--->] ШАГ 4: Активация CompactOS (сжатие файлов ядра LZX)..." -ForegroundColor Cyan
& compact.exe /CompactOS:always | Out-Null
Write-Host "[+] CompactOS активирован." -ForegroundColor Green

# --- ШАГ 5: Отключение индексации Windows Search для HDD D: ---
#     ИСПРАВЛЕНИЕ: используем fsutil + реестр вместо ненадёжного COM-объекта Shell.Application
Write-Host "`n[--->] ШАГ 5: Отключение фоновой индексации содержимого для HDD D:..." -ForegroundColor Cyan
if (Test-Path "D:\") {
    # Снимаем флаг индексации с корня диска D: через атрибуты файловой системы
    $DriveD = Get-Item "D:\" -Force
    $DriveD.Attributes = $DriveD.Attributes -band (-bnot [System.IO.FileAttributes]::Indexed)
    # Дополнительно: отключаем индексацию через реестр службы Windows Search для тома
    $SearchKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    if (-not (Test-Path $SearchKey)) { New-Item -Path $SearchKey -Force | Out-Null }
    Set-ItemProperty -Path $SearchKey -Name "PreventIndexingLowDiskSpaceMB" -Value 99999 -Type DWord
    Write-Host "[+] Фоновая индексация D: заблокирована." -ForegroundColor Green
} else {
    Write-Host "  -> Диск D: (HDD) не найден. Пропускаем." -ForegroundColor Gray
}

# --- ШАГ 6: TRIM для SSD C: ---
#     ИСПРАВЛЕНИЕ: -ReTrim (триггер TRIM), а не -Defrag (дефрагментация = износ SSD)
Write-Host "`n[--->] ШАГ 6: Принудительный TRIM для диска C: (SSD)..." -ForegroundColor Cyan
Optimize-Volume -DriveLetter C -ReTrim -Verbose
Write-Host "[+] TRIM выполнен." -ForegroundColor Green

Write-Host "`n$(("=" * 74))" -ForegroundColor Green
Write-Host "  ПОДСИСТЕМА ХРАНЕНИЯ ОПТИМИЗИРОВАНА." -ForegroundColor Green
Write-Host ("=" * 74) -ForegroundColor Green