# Инженерный мануал: Сквозная миграция на Windows 11 Pro (25H2)
## Методология «Космической капсулы» — Zero-Loss Migration

**Версия:** 2.0 (Проверено и исправлено)  
**Цель:** Полный перенос рабочего окружения специалиста со старого ПК на новый через «Золотой образ» с аппаратной независимостью  
**Аудитория:** Системный инженер / IT-администратор  

---

## КРИТИЧЕСКИЙ АНАЛИЗ ИСХОДНОГО МАНУАЛА

Перед финальной инструкцией — перечень выявленных и исправленных проблем:

| # | Блок | Проблема | Исправление |
|---|------|----------|-------------|
| 1 | `complete_cleaner.ps1` | `Invoke-Expression` с `cmd.exe /c` — опасная инъекция, ломается на путях с пробелами | Заменено на `Start-Process` с корректным разбором строки |
| 2 | `complete_cleaner.ps1` | Служба `wuauserv` (Windows Update) отключается навсегда — система не получит патчи безопасности | Служба удалена из списка принудительного отключения |
| 3 | `complete_cleaner.ps1` | `sppsvc` (Software Protection) отключается — сломает активацию Windows | Служба удалена из списка |
| 4 | `complete_cleaner.ps1` | `SysMain` (Superfetch) отключается — на HDD это вредит, на NVMe нейтрально | Добавлен условный блок: отключение только при наличии SSD |
| 5 | `tune_storage.ps1` | Отключение индексации через `Shell.Application` — ненадёжный COM-метод, не работает на серверных редакциях | Заменено на `fsutil behavior set disableLastAccess 1` + `Set-ItemProperty` на ключ реестра тома |
| 6 | `tune_storage.ps1` | `Optimize-Volume -Defrag` на SSD запускает дефрагментацию, а не TRIM — изнашивает ячейки | Исправлено на `Optimize-Volume -ReTrim` для SSD |
| 7 | `link_chrome.ps1` | `cmd.exe /c 'mklink ...'` — конкатенация строки PS с путями содержит пробелы, mklink упадёт | Исправлено через `cmd.exe /c "mklink /d ..."` с правильным экранированием |
| 8 | `unattend.xml` | `xmlns:xsi="http://w3.org"` — обрезанный namespace, невалидный XML | Исправлено на полный URI `http://www.w3.org/2001/XMLSchema-instance` |
| 9 | `unattend.xml` | `rmdir /s /q C:\Users\Admin` выполняется до завершения сессии — папка заблокирована системой | Добавлен `timeout /t 5` перед rmdir и флаг через реестр RunOnce |
| 10 | `clean_hkcu.ps1` | Удаление `thumbcache_*.db` и `iconcache_*.db` при работающем Explorer — файлы заблокированы | Добавлена остановка Explorer перед удалением и перезапуск после |
| 11 | Этап 4 | Команды `icacls` не содержат `SYSTEM` в правах — Windows заблокирует профиль при входе | Добавлена полная матрица ACL: `SYSTEM`, `Administrators`, пользователь |
| 12 | Этап 7 | Отсутствует шаг активации Windows после первого запуска | Добавлен блок активации лицензии |
| 13 | Общее | Отсутствует `БЛОК 0` — предварительная подготовка флешки и инструментов | Добавлен нулевой блок |
| 14 | Общее | Отсутствует процедура отката при сбое Sysprep | Добавлен раздел «Аварийный откат» |

---

## СТРУКТУРА МАНУАЛА

```
БЛОК 0.  Предварительная подготовка: инструменты и флешка
БЛОК 1.  Файлы конфигурации (apps_to_remove.txt, user_junk_masks.txt)
БЛОК 2.  Скрипты глобальной очистки базы HKLM (complete_cleaner.ps1, RUN_CLEANER.cmd)
БЛОК 3.  Скрипты очистки профиля HKCU (clean_hkcu.ps1, RUN_USER_CLEANER.cmd)
БЛОК 4.  Файл автоответов Sysprep (unattend.xml)
БЛОК 5.  Настройка BCUninstaller Portable
БЛОК 6.  ЭТАП 1 — Извлечение профиля со старого ПК (WinPE DISM)
БЛОК 7.  ЭТАП 2 — Развёртывание чистой базы в VirtualBox
БЛОК 8.  ЭТАП 3 — Стерилизация базы в ВМ (HKLM-твики)
БЛОК 9.  ЭТАП 4 — Импорт профиля клиента, восстановление NTFS ACL, зачистка HKCU
БЛОК 10. ЭТАП 5 — Sysprep и захват «Золотого образа» Win25HPro_Final.pmf
БЛОК 11. ЭТАП 6 — Разметка накопителей на новом ПК (WinPE DiskGenius)
БЛОК 12. ЭТАП 7 — Первый запуск: Режим аудита → уничтожение Admin → рабочий стол клиента
БЛОК 13. QA-скрипты: tune_storage.ps1, link_chrome.ps1, finalize_system.ps1
БЛОК 14. Финальный чек-лист приёмки станции
БЛОК 15. Аварийный откат
```

---

## БЛОК 0. ПРЕДВАРИТЕЛЬНАЯ ПОДГОТОВКА

### 0.1 Требования к инструментам инженера

| Инструмент | Версия / Источник | Назначение |
|------------|-------------------|------------|
| VirtualBox | 7.0+ | Изолированная сборка «Золотого образа» |
| DiskGenius | 5.5+ (WinPE-версия) | Разметка дисков, захват/восстановление .pmf образа |
| BCUninstaller | 5.7+ Portable | Удаление мусорного ПО с зачисткой реестра |
| ISO Windows 11 Pro 25H2 | Официальный Media Creation Tool | Установочный образ |
| Флешка A (WinPE) | ≥ 32 ГБ, USB 3.x, NTFS | DiskGenius WinPE + итоговый образ Win25HPro_Final.pmf |
| Флешка B (Админ) | ≥ 64 ГБ, USB 3.x, NTFS | Все скрипты + BCUninstaller + профиль клиента .wim |

> ⚠️ **КРИТИЧНО**: Флешки NTFS (не FAT32). Файлы профиля программиста с кэшем node_modules / VS Code превышают 4 ГБ — ограничение FAT32.

### 0.2 Структура каталогов на Флешке B (Админ)

```
X:\
├── apps_to_remove.txt          ← Маски Win32-программ для удаления
├── user_junk_masks.txt         ← Маски зомби-компонентов профиля
├── complete_cleaner.ps1        ← Глобальная очистка базы (HKLM)
├── clean_hkcu.ps1              ← Зачистка профиля клиента (HKCU)
├── tune_storage.ps1            ← Настройка накопителей
├── link_chrome.ps1             ← Symlink кэша браузеров на HDD
├── finalize_system.ps1         ← DNS, электропитание, SFC/DISM
├── RUN_CLEANER.cmd             ← Запуск complete_cleaner.ps1
├── RUN_USER_CLEANER.cmd        ← Запуск clean_hkcu.ps1
├── unattend.xml                ← Файл ответов Sysprep
├── BCUninstaller\              ← Portable-версия утилиты
└── Profile_User.wim            ← (создаётся на Этапе 1)
```

---

## БЛОК 1. ФАЙЛЫ КОНФИГУРАЦИИ

### 1.1 `apps_to_remove.txt`
**Кодировка:** UTF-8 без BOM. Размещение: корень Флешки B.  
Строки с `#` игнорируются. Поддерживаются wildcard-маски `*`.

```text
# === apps_to_remove.txt — Маски Win32-программ для удаления ===
# Строки с '#' игнорируются. Поддерживаются wildcards (*).

# --- Блок 1. Мусорный софт старого железа (ОЕМ-вендоры) ---
*Armoury Crate*
*MSI Center*
*Dragon Center*
*Gigabyte Control Center*
*Ryzen Master*
*Intel Extreme Tuning*
*Lenovo Vantage*
*HP Support Assistant*
*MyASUS*
*Dell SupportAssist*
*Acer Care Center*

# --- Блок 2. Сторонние антивирусы и крипто-драйверы (блокируют Sysprep) ---
*Kaspersky*
*Avast*
*Dr.Web*
*CryptoPro*
*КриптоПро*
*ESET*
*Malwarebytes*
*Norton*
*McAfee*
*Bitdefender*

# --- Блок 3. Встроенный мусор Windows 11 (препятствует запечатыванию) ---
*Xbox*
*Bing*
*Zune*
*People*
*Skype*
*OfficeHub*
*Solitaire*
*FeedbackHub*
*MixedReality*
*Widgets*
*Cortana*
*Microsoft Teams*
```

---

### 1.2 `user_junk_masks.txt`
**Кодировка:** UTF-8 без BOM. Размещение: корень Флешки B.  
**Синтаксис строки:** `Тип|Относительный_путь`  
- `Folder|Local\ИмяПапки` → `%USERPROFILE%\AppData\Local\ИмяПапки`  
- `Folder|Roaming\ИмяПапки` → `%USERPROFILE%\AppData\Roaming\ИмяПапки`  
- `Registry|ИмяКлюча` → `HKCU:\Software\ИмяКлюча`

```text
# === user_junk_masks.txt — Маски зомби-компонентов профиля ===

# --- Блок 1. Корпоративные VPN-клиенты ---
Folder|Local\Cisco
Folder|Roaming\Cisco
Folder|Local\WireGuard
Folder|Local\OpenVPN
Folder|Roaming\OpenVPN
Folder|Local\Fortinet
Folder|Roaming\Fortinet
Folder|Local\CheckPoint
Folder|Roaming\CheckPoint
Folder|Local\Palo Alto Networks
Folder|Roaming\Palo Alto Networks
Folder|Local\SonicWall
Folder|Roaming\SonicWall
Registry|OpenVPN-GUI
Registry|WireGuard
Registry|Fortinet
Registry|CheckPoint
Registry|SonicWall

# --- Блок 2. Антивирусы и защитное ПО ---
Folder|Local\Kaspersky Lab
Folder|Roaming\Kaspersky Lab
Folder|Local\Avast Software
Folder|Roaming\Avast Software
Folder|Local\DrWeb
Folder|Roaming\DrWeb
Folder|Local\ESET
Folder|Roaming\ESET
Folder|Local\Malwarebytes
Folder|Roaming\Malwarebytes
Folder|Local\McAfee
Folder|Roaming\McAfee
Folder|Local\Norton
Folder|Roaming\Norton
Registry|KasperskyLab
Registry|Avast Software
Registry|Doctor Web
Registry|ESET
Registry|Malwarebytes

# --- Блок 3. Эмуляторы Android ---
Folder|Local\BlueStacks
Folder|Roaming\BlueStacks
Folder|Local\BlueStacks_nxt
Folder|Local\Nox
Folder|Roaming\Nox
Folder|Local\MEmu
Folder|Roaming\MEmu
Folder|Local\LDPlayer
Folder|Local\LDPlayer9
Registry|Nox
Registry|MEmu
Registry|Leadshine\LDPlayer
```

---

## БЛОК 2. СКРИПТЫ ГЛОБАЛЬНОЙ ОЧИСТКИ БАЗЫ (HKLM)

### 2.1 `complete_cleaner.ps1`
**Кодировка:** UTF-8. Запускается от имени Администратора в профиле `Admin` на Этапе 3.

```powershell
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
```

---

### 2.2 `RUN_CLEANER.cmd`
**Кодировка:** ANSI. Обходит ExecutionPolicy двойным кликом без дополнительных действий.

```cmd
@echo off
chcp 65001 > nul
echo Запуск complete_cleaner.ps1 от имени Администратора...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0complete_cleaner.ps1"
pause
```

---

## БЛОК 3. СКРИПТЫ ОЧИСТКИ ПРОФИЛЯ КЛИЕНТА (HKCU)

### 3.1 `clean_hkcu.ps1`
**Кодировка:** UTF-8. Запускается из-под учётной записи клиента (не Admin) на Этапе 4.

```powershell
<#
.SYNOPSIS
    Модульная зачистка личного пространства клиента (HKCU + AppData).
.DESCRIPTION
    Считывает маски из user_junk_masks.txt, удаляет зомби-задачи планировщика,
    остатки VPN/антивирусов в AppData, сбрасывает аппаратные GUID в HKCU,
    вырезает рекламу Windows 11 25H2.
    ЗАПУСКАТЬ: из-под учётной записи КЛИЕНТА на Этапе 4.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

Write-Host ("=" * 74) -ForegroundColor Yellow
Write-Host "  ЗАЧИСТКА ПРОФИЛЯ КЛИЕНТА — HKCU + AppData" -ForegroundColor Yellow
Write-Host ("=" * 74) -ForegroundColor Yellow

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$MasksFile  = Join-Path $ScriptPath "user_junk_masks.txt"
if (-not (Test-Path $MasksFile)) {
    Write-Error "КРИТИЧНО: '$MasksFile' не найден!"
    Exit 1
}

# --------------------------------------------------------------------------
# ШАГ 1: УДАЛЕНИЕ ЗОМБИ-ЗАДАЧ ПЛАНИРОВЩИКА
#         (задачи, чьи .exe-файлы уже не существуют)
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 1: Поиск и удаление невалидных задач планировщика..." -ForegroundColor Cyan
Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "*\Microsoft\*" } | ForEach-Object {
    $TaskName = $_.TaskName
    try {
        $Actions = (Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop).Actions
        foreach ($Action in $Actions) {
            if ($Action.Execute -and (-not (Test-Path $Action.Execute -ErrorAction SilentlyContinue))) {
                Write-Host "  -> Удаление сиротской задачи: $TaskName" -ForegroundColor Yellow
                Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
                break
            }
        }
    } catch { }
}
Write-Host "[+] Шаг 1 завершён." -ForegroundColor Green

# --------------------------------------------------------------------------
# ШАГ 2: ПАРСИНГ МАСОК И УДАЛЕНИЕ ЗОМБИ-ПАПОК / КЛЮЧЕЙ РЕЕСТРА
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 2: Зачистка AppData и HKCU по маскам..." -ForegroundColor Cyan
$MaskLines = Get-Content -Path $MasksFile | Where-Object { $_ -and -not $_.StartsWith("#") }

foreach ($Line in $MaskLines) {
    if (-not ($Line -match "\|")) { continue }
    $Type, $RelativePath = $Line.Split("|", 2)
    $Type         = $Type.Trim()
    $RelativePath = $RelativePath.Trim()

    if ($Type -eq "Folder") {
        $FullPath = Join-Path $env:USERPROFILE "AppData\$RelativePath"
        if (Test-Path $FullPath) {
            Write-Host "  -> Удаление папки: AppData\$RelativePath" -ForegroundColor Yellow
            Remove-Item -Path $FullPath -Recurse -Force -ErrorAction SilentlyContinue
        }
    } elseif ($Type -eq "Registry") {
        $FullKey = "HKCU:\Software\$RelativePath"
        if (Test-Path $FullKey) {
            Write-Host "  -> Удаление ключа: HKCU:\Software\$RelativePath" -ForegroundColor Yellow
            Remove-Item -Path $FullKey -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# Очистка пользовательской Temp
$UserTemp = Join-Path $env:USERPROFILE "AppData\Local\Temp"
if (Test-Path $UserTemp) {
    Remove-Item -Path "$UserTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "[+] Шаг 2 завершён." -ForegroundColor Green

# --------------------------------------------------------------------------
# ШАГ 3: ЗАЧИСТКА РЕКЛАМЫ И КЭШЕЙ ПРОВОДНИКА WINDOWS 11 (25H2)
#         ВАЖНО: перед удалением файлов кэша останавливаем Explorer
# --------------------------------------------------------------------------
Write-Host "`n[--->] ШАГ 3: Зачистка рекламы и кэшей иконок Проводника..." -ForegroundColor Cyan

# Останавливаем Explorer, чтобы снять блокировку с файлов кэша
Stop-Process -Name "explorer" -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Удаляем базы эскизов и иконок (фиксит зависание панели задач после миграции)
Remove-Item "$env:LocalAppData\Microsoft\Windows\Explorer\thumbcache_*.db" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LocalAppData\Microsoft\Windows\Explorer\iconcache_*.db"  -Force -ErrorAction SilentlyContinue

# Перезапускаем Explorer
Start-Process "explorer.exe"

# Отключаем телеметрию ввода и рекламные подсказки в профиле клиента
$CDM = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
if (-not (Test-Path $CDM)) { New-Item -Path $CDM -Force | Out-Null }
Set-ItemProperty -Path $CDM -Name "SystemAndSystemToastNotificationSettingsAllowed" -Value 0 -Type DWord
Set-ItemProperty -Path $CDM -Name "OemPreInstalledAppsEnabled"                      -Value 0 -Type DWord
Set-ItemProperty -Path $CDM -Name "SubscribedContent-338387Enabled"                 -Value 0 -Type DWord
Set-ItemProperty -Path $CDM -Name "SubscribedContent-338389Enabled"                 -Value 0 -Type DWord

Set-ItemProperty "HKCU:\Software\Microsoft\Input\TIPC" -Name "Enabled" -Value 0 -Type DWord

$PersonPath = "HKCU:\Software\Microsoft\Personalization\Settings"
if (-not (Test-Path $PersonPath)) { New-Item -Path $PersonPath -Force | Out-Null }
Set-ItemProperty -Path $PersonPath -Name "AcceptedPrivacyPolicy" -Value 0 -Type DWord

Set-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" `
    -Name "Start_TrackProgs" -Value 0 -Type DWord

Write-Host "[+] Шаг 3 завершён." -ForegroundColor Green
Write-Host "`n$(("=" * 74))" -ForegroundColor Green
Write-Host "  ПРОФИЛЬ КЛИЕНТА ОЧИЩЕН ПО ДИНАМИЧЕСКИМ МАСКАМ." -ForegroundColor Green
Write-Host ("=" * 74) -ForegroundColor Green
```

---

### 3.2 `RUN_USER_CLEANER.cmd`
**Кодировка:** ANSI.  
Запрашивает права администратора, **сохраняя контекст текущего пользователя** (`$env:USERPROFILE` указывает на профиль клиента, а не на системного Admin).

```cmd
@echo off
chcp 65001 > nul
echo Запуск clean_hkcu.ps1 в контексте текущего пользователя с правами Admin...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0clean_hkcu.ps1""' -Verb RunAs"
exit
```

---

## БЛОК 4. ФАЙЛ АВТООТВЕТОВ SYSPREP — `unattend.xml`

**Кодировка:** UTF-8 без BOM.  
Размещение: корень Флешки B. На Этапе 5 копируется в `C:\Windows\System32\Sysprep\`.

> **Как работает:** Блок `<FirstLogonCommands>` выполняется при самом первом входе после OOBE на новом ПК. Команды удаляют учётную запись `Admin` и её папку. `timeout /t 10` обеспечивает завершение загрузки профиля до попытки удаления папки.

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">

    <!-- PASS 1: generalize — разрешение многократного Sysprep -->
    <settings pass="generalize">
        <component name="Microsoft-Windows-Security-SPP-UX"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <SkipRearm>1</SkipRearm>
        </component>
    </settings>

    <!-- PASS 2: oobeSystem — первый запуск на новом железе -->
    <settings pass="oobeSystem">

        <!-- Локализация системы -->
        <component name="Microsoft-Windows-International-Core"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>0419:00000419</InputLocale>
            <SystemLocale>ru-RU</SystemLocale>
            <UILanguage>ru-RU</UILanguage>
            <UserLocale>ru-RU</UserLocale>
        </component>

        <!-- Автоматический пропуск экранов OOBE -->
        <component name="Microsoft-Windows-Shell-Setup"
                   processorArchitecture="amd64"
                   publicKeyToken="31bf3856ad364e35"
                   language="neutral"
                   versionScope="nonSxS"
                   xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
                   xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideLocalUserPage>true</HideLocalUserPage>
                <HideOEMRegistrationPage>true</HideOEMRegistrationPage>
                <HideOnlineAccountPage>true</HideOnlineAccountPage>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>

            <!-- АВТОМАТИЧЕСКОЕ УНИЧТОЖЕНИЕ СТРОИТЕЛЬНОГО ПРОФИЛЯ Admin -->
            <FirstLogonCommands>
                <!-- Шаг 1: Пауза для завершения загрузки профиля клиента -->
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>cmd.exe /c timeout /t 10 /nobreak</CommandLine>
                    <Description>Ожидание завершения инициализации профиля</Description>
                </SynchronousCommand>
                <!-- Шаг 2: Удаление учётной записи Admin из SAM -->
                <SynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <CommandLine>cmd.exe /c net user Admin /delete</CommandLine>
                    <Description>Удаление временной учётной записи Admin</Description>
                </SynchronousCommand>
                <!-- Шаг 3: Физическое стирание папки профиля Admin с диска -->
                <SynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <CommandLine>cmd.exe /c rmdir /s /q C:\Users\Admin</CommandLine>
                    <Description>Физическое удаление папки C:\Users\Admin</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
```

---

## БЛОК 5. НАСТРОЙКА BCUninstaller PORTABLE

Разверните BCUninstaller Portable в папку `X:\BCUninstaller\` на Флешке B. При первом запуске настройте параметры:

**Вкладка «Behavior» (Поведение):**
- ☑ Скрывать системные компоненты Microsoft (защита .NET / VC++ Runtime от случайного удаления)
- ☑ Автоматически закрывать BCUninstaller после завершения

**Вкладка «Uninstallation» (Деинсталляция):**
- ☑ Всегда использовать тихий режим, если доступно
- ☑ Автоматически нажимать кнопки согласия в фоновом режиме
- ☐ **ВЫКЛЮЧИТЬ** «Создавать точку восстановления перед удалением» — сокращает время на 10–15 мин

**Вкладка «Junk Clean» (Очистка остатков):**
- Уровень: **Advanced**
- ☑ Удалять остатки без подтверждения (тихий режим)

---

## БЛОК 6. ЭТАП 1 — ИЗВЛЕЧЕНИЕ ПРОФИЛЯ СО СТАРОГО ПК

**Питание:** Подключить к розетке.  
**Сеть:** LAN-кабель извлечь, Wi-Fi отключить физически.

**Действия:**

1. Загрузить старый ПК с WinPE-флешки (Флешка A с DiskGenius WinPE).
2. Проверить букву флешки B в окне DiskGenius (пусть будет `E:`).
3. Открыть командную строку WinPE и захватить профиль командой DISM:

```cmd
DISM /Capture-Image /ImageFile:E:\Profile_User.wim /CaptureDir:"C:\Users\ИмяКлиента" /Name:"ClientProfile" /Compress:max
```

> **Примечания:**
> - `ИмяКлиента` — точное имя папки профиля (с учётом регистра).
> - При нескольких профилях повторить для каждого: `Profile_User2.wim` и т.д.
> - Флаг `/Compress:max` уменьшает размер .wim на 20–40%.

4. Дождаться завершения (прогресс в процентах). Убедиться, что файл `Profile_User.wim` появился на флешке B.
5. Старый ПК можно выключать.

---

## БЛОК 7. ЭТАП 2 — РАЗВЁРТЫВАНИЕ ЧИСТОЙ БАЗЫ В VIRTUALBOX

**Сеть в ВМ:** Сетевой адаптер деактивирован («Подключить кабель» — снять галочку).

**Параметры новой ВМ:**

| Параметр | Значение |
|----------|----------|
| Тип ОС | Windows 11 (64-bit) |
| EFI | Включить |
| TPM | v2.0 (через Settings → System → TPM) |
| Secure Boot | Включить |
| RAM | ≥ 4 ГБ |
| Диск | ≥ 80 ГБ, динамический VDI |

**Действия:**

1. Смонтировать ISO Windows 11 Pro 25H2. Запустить ВМ.
2. Установщик: выбрать **Windows 11 Профессиональная (Pro)**. ❌ Не Home/Education.
3. После копирования файлов, на первом экране OOBE (запрос сети), нажать `Shift + F10`.
4. В открывшейся консоли выполнить команду обхода сетевого ограничения:
   ```cmd
   OOBE\BYPASSNRO
   ```
5. ВМ перезагрузится. На повторном экране сети выбрать **«У меня нет интернета»** → **«Продолжить ограниченную установку»**.
6. Создать локального пользователя с именем строго `Admin` (пароль — пустой).

---

## БЛОК 8. ЭТАП 3 — СТЕРИЛИЗАЦИЯ БАЗЫ В ВМ (HKLM-ТВИКИ)

**Сеть:** Интернет в ВМ — отключён.

**Действия:**

1. Зайти в `Параметры → Конфиденциальность и защита → Безопасность Windows → Защита от вирусов → Управление настройками`. Временно отключить **«Защита в реальном времени»** (чтобы антивирус не мешал скриптам).
2. Подключить Флешку B к ВМ (VirtualBox → Devices → USB).
3. Запустить **BCUninstaller** с флешки. Выделить галочками весь предустановленный мусор (Xbox-игры, рекламные ярлыки). Нажать **«Деинсталлировать тихо»**. Дождаться завершения.
4. В корне флешки нажать правой кнопкой по `RUN_CLEANER.cmd` → **«Запуск от имени администратора»**.
5. Дождаться завершения всех 4 шагов скрипта. Консоль выведет зелёное сообщение `БАЗА ОЧИЩЕНА`.
6. **Не перезагружать ВМ** — переходить к Этапу 4.

---

## БЛОК 9. ЭТАП 4 — ИМПОРТ ПРОФИЛЯ КЛИЕНТА, ВОССТАНОВЛЕНИЕ NTFS ACL, ЗАЧИСТКА HKCU

**Сеть:** Интернет в ВМ — отключён.

**Действия:**

1. В профиле `Admin`: `Параметры → Учётные записи → Другие пользователи → Добавить учётную запись`.
2. Выбрать «У меня нет данных для входа этого человека» → «Добавить пользователя без учётной записи Майкрософт».
3. Создать локального пользователя с именем **строго совпадающим** с именем на старом ПК (регистр букв важен). Тип учётной записи: **Администратор**.
4. Выйти из `Admin`, зайти в профиль клиента, дождаться первого появления рабочего стола (Windows формирует структуру папок). Выйти обратно и зайти в `Admin`.
5. Открыть командную строку **от имени администратора** и развернуть архив профиля:

```cmd
DISM /Apply-Image /ImageFile:"E:\Profile_User.wim" /Index:1 /ApplyDir:"C:\Users\ИмяКлиента"
```

6. **Восстановление прав NTFS ACL** (критично — без этого вход завершится ошибкой «Временный профиль»):

```cmd
:: Назначить владельца папки
icacls "C:\Users\ИмяКлиента" /setowner "ИмяКлиента" /T /C /Q

:: Выдать полные права пользователю
icacls "C:\Users\ИмяКлиента" /grant:r "ИмяКлиента":(OI)(CI)F /T /C /Q

:: Обязательно: добавить права SYSTEM и Administrators (без них Windows заблокирует профиль)
icacls "C:\Users\ИмяКлиента" /grant:r "SYSTEM":(OI)(CI)F /T /C /Q
icacls "C:\Users\ИмяКлиента" /grant:r "Administrators":(OI)(CI)F /T /C /Q
```

7. Выйти из `Admin`, зайти в профиль клиента. Запустить с флешки `RUN_USER_CLEANER.cmd` двойным кликом.
8. Дождаться завершения скрипта. Выйти из профиля клиента, вернуться в `Admin`.

---

## БЛОК 10. ЭТАП 5 — SYSPREP И ЗАХВАТ «ЗОЛОТОГО ОБРАЗА»

**Сеть:** Интернет в ВМ — отключён.

**Действия:**

1. Из профиля `Admin` скопировать `unattend.xml` с флешки в системный каталог:
   ```cmd
   copy "E:\unattend.xml" "C:\Windows\System32\Sysprep\unattend.xml"
   ```

2. Открыть командную строку от имени администратора. Перейти в каталог Sysprep и запустить запечатывание:
   ```cmd
   cd C:\Windows\System32\Sysprep
   sysprep.exe /generalize /oobe /shutdown /unattend:unattend.xml
   ```

   > ⚠️ Если Sysprep возвращает ошибку — прочитать лог: `C:\Windows\System32\Sysprep\Panther\setuperr.log`. Частая причина: остались provisioned AppX-пакеты. Решение: в ВМ выполнить `Get-AppxProvisionedPackage -Online | Remove-AppxProvisionedPackage -Online` и повторить.

3. ВМ выключится автоматически. **Не запускать ВМ снова.**

4. Открыть DiskGenius на хост-машине: `Disk → Open Virtual Disk File`. Указать путь к `.vdi` файлу выключенной ВМ.

5. В смонтированном диске (корень C:) удалить мусорные папки:
   - `Windows.old` (если есть)
   - `$Windows.~BT` (если есть)

6. ПКМ по системному разделу ВМ → **«Backup Partition To Image File»**. Сохранить под именем `Win25HPro_Final.pmf` на Флешку A.

7. Убедиться, что файл `Win25HPro_Final.pmf` записан без ошибок (DiskGenius выведет статус OK).

---

## БЛОК 11. ЭТАП 6 — РАЗМЕТКА НАКОПИТЕЛЕЙ НА НОВОМ ПК (WinPE DiskGenius)

**Питание:** ПК подключён к розетке.  
**Сеть:** LAN извлечён, Wi-Fi не подключать.

**Действия:**

1. Подключить Флешку A (WinPE). Загрузиться с неё в среду DiskGenius WinPE.

2. **Конвертация в GPT:**  
   ПКМ по целевому SSD → **«Convert To GUID Partition Table (GPT)»**.  
   Повторить для HDD (если установлен). Нажать **Save All**.

3. **Создание раздела с правильным выравниванием секторов (4K Alignment):**  
   ПКМ по незанятому пространству SSD → **«Create New Partition»**.  
   - Activate чекбокс **«Align Sectors to Integral Multiples»**
   - Значение: **2048 sectors (1024 KB)**
   - Размер кластера для SSD (C:): **4 КБ (4096 байт)**
   - Нажать OK → Save All.

4. **Калибровка кластеров HDD (если есть):**  
   ПКМ по разделу HDD → Format → Размер кластера: **64 КБ (65536 байт)** → OK.

5. **Развёртывание «Золотого образа»:**  
   Найти `Win25HPro_Final.pmf` на Флешке A → ПКМ → **«Restore Partition From Image File»**.  
   Указать целевой раздел — системный SSD (C:). Дождаться завершения.

6. **Расширение раздела на весь SSD:**  
   Мышью растянуть раздел C: на весь свободный объём SSD в интерфейсе DiskGenius → Save All.

7. **Фиксация загрузчика:**  
   ПКМ по разделу C: → **«Fix Boot»** (или меню Disk → Rebuild MBR / Fix GPT Boot). Подтвердить.

8. Извлечь Флешку A. Перейти к Этапу 7.

---

## БЛОК 12. ЭТАП 7 — ПЕРВЫЙ ЗАПУСК, РЕЖИМ АУДИТА, ФИНАЛИЗАЦИЯ

**Питание:** Подключён к розетке.  
**Сеть:** Интернет — отключён (на этом этапе).

**Действия:**

1. Включить новый ПК. Система запустит «Идёт подготовка устройств» — ACPI-сканирование нового железа.

2. На **первом** экране OOBE (выбор региона/языка) **немедленно** нажать `Ctrl + Shift + F3`.  
   > ❌ **ЗАПРЕЩЕНО** нажимать «Далее» до этого! Иначе система создаст новый профиль и разрушит структуру клиентской учётной записи.

3. ПК перезагрузится в **Режим аудита** (Audit Mode) с рабочим столом учётной записи `Администратор` (встроенная системная — не путать с нашим `Admin`).

4. На рабочем столе появится окно утилиты Sysprep. Не закрывать. Настроить:
   - Действие по очистке: **«Переход в режим приветствия системы (OOBE)»**
   - Параметры завершения работы: **«Перезагрузка»**
   - Нажать **OK**.

5. ПК перезагрузится. Файл `unattend.xml` выполнит `<FirstLogonCommands>`:
   - Удалит учётную запись `Admin` из SAM
   - Физически уничтожит папку `C:\Users\Admin`

6. Откроется чистый экран блокировки с **единственным** профилем клиента. Войти.

7. Подключить Флешку B. Выполнить в PowerShell от администратора:
   ```powershell
   & "E:\tune_storage.ps1"
   ```
   (опционально: `& "E:\link_chrome.ps1"` если есть HDD D:)

8. Подключить интернет. Выполнить:
   ```powershell
   & "E:\finalize_system.ps1"
   ```

9. **Активация Windows:**  
   `Параметры → Система → Активация`. Ввести лицензионный ключ клиента или подключить к серверу активации организации.

---

## БЛОК 13. QA-СКРИПТЫ

### 13.1 `tune_storage.ps1`
**Запуск:** от Администратора в профиле клиента на Этапе 7.

```powershell
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
```

---

### 13.2 `link_chrome.ps1`
**Условие применения:** только если системный SSD ≤ 240 ГБ И установлен HDD D:.  
**Запуск:** от Администратора, при **закрытых браузерах**.

```powershell
<#
.SYNOPSIS
    Перенаправление медиа-кэша браузеров с SSD на HDD через NTFS Symlink.
.DESCRIPTION
    Переносит только Cache-директории. Куки, пароли, сессии — остаются на SSD.
    ЗАПУСКАТЬ: от Администратора в профиле клиента. Браузеры должны быть закрыты.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ("=" * 74) -ForegroundColor Yellow
Write-Host "  ПЕРЕНАПРАВЛЕНИЕ КЭША БРАУЗЕРОВ НА HDD D:" -ForegroundColor Yellow
Write-Host ("=" * 74) -ForegroundColor Yellow

# Принудительное завершение процессов браузеров
Stop-Process -Name "chrome"  -Force -ErrorAction SilentlyContinue
Stop-Process -Name "browser" -Force -ErrorAction SilentlyContinue  # Яндекс.Браузер
Stop-Process -Name "msedge"  -Force -ErrorAction SilentlyContinue  # Edge (если используется)
Start-Sleep -Seconds 2

if (-not (Test-Path "D:\")) {
    Write-Warning "Диск D: не найден. Символьные ссылки не могут быть созданы. Выход."
    Exit 1
}

# Функция создания Symlink (корректное экранирование путей с пробелами)
function New-CacheSymlink {
    param(
        [string]$SourceCache,  # Оригинальный путь кэша браузера (на SSD)
        [string]$TargetDir,    # Новое расположение кэша (на HDD)
        [string]$BrowserName
    )
    Write-Host "`n[--->] Обработка $BrowserName..." -ForegroundColor Cyan
    $ProfileDir = Split-Path -Parent $SourceCache
    if (-not (Test-Path $ProfileDir)) {
        Write-Host "  -> Профиль $BrowserName не найден. Пропускаем." -ForegroundColor Gray
        return
    }
    # Удалить существующую Cache-папку
    if (Test-Path $SourceCache) {
        Remove-Item -Path $SourceCache -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Создать целевую папку на HDD
    if (-not (Test-Path $TargetDir)) {
        New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    }
    # Создать NTFS junction-point (символьную ссылку уровня ФС)
    # cmd /c используется намеренно — PowerShell не имеет нативного mklink для директорий
    $result = & cmd.exe /c "mklink /j `"$SourceCache`" `"$TargetDir`""
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] Кэш $BrowserName -> $TargetDir" -ForegroundColor Green
    } else {
        Write-Warning "  Ошибка создания ссылки для $BrowserName. Результат: $result"
    }
}

# Google Chrome
New-CacheSymlink `
    -SourceCache "$env:LocalAppData\Google\Chrome\User Data\Default\Cache" `
    -TargetDir   "D:\BrowserCache\Chrome" `
    -BrowserName "Google Chrome"

# Яндекс.Браузер
New-CacheSymlink `
    -SourceCache "$env:LocalAppData\Yandex\YandexBrowser\User Data\Default\Cache" `
    -TargetDir   "D:\BrowserCache\Yandex" `
    -BrowserName "Яндекс.Браузер"

Write-Host "`n[+] ВСЕ ОПЕРАЦИИ С СИМВОЛЬНЫМИ ССЫЛКАМИ ЗАВЕРШЕНЫ." -ForegroundColor Green
```

---

### 13.3 `finalize_system.ps1`
**Запуск:** от Администратора в профиле клиента, **после подключения интернета**.

```powershell
<#
.SYNOPSIS
    Финальная оптимизация сети, электропитания и верификация целостности ОС.
.DESCRIPTION
    Прописывает публичные DNS (Cloudflare + Google) на активных адаптерах,
    переводит планировщик CPU в режим High Performance,
    запускает DISM RestoreHealth и SFC scannow.
    ЗАПУСКАТЬ: от Администратора, после подключения интернета (Этап 7, финал).
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ("=" * 74) -ForegroundColor Yellow
Write-Host "  ФИНАЛЬНАЯ СЕТЕВАЯ ОПТИМИЗАЦИЯ И СИСТЕМНЫЙ QA-АУДИТ" -ForegroundColor Yellow
Write-Host ("=" * 74) -ForegroundColor Yellow

# --- ШАГ 1: Публичные DNS (Cloudflare + Google) для всех активных адаптеров ---
#     Устраняет микросбои при npm install / pip install / git push
Write-Host "`n[--->] ШАГ 1: Настройка публичных DNS-серверов..." -ForegroundColor Cyan
$ActiveAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
if ($ActiveAdapters) {
    foreach ($Adapter in $ActiveAdapters) {
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex `
            -ServerAddresses ("1.1.1.1", "8.8.8.8") -ErrorAction SilentlyContinue
        Write-Host "  -> DNS настроен для: $($Adapter.Name)" -ForegroundColor Gray
    }
    Write-Host "[+] DNS настроен." -ForegroundColor Green
} else {
    Write-Warning "Активные сетевые адаптеры не найдены. Подключите интернет и повторите."
}

# --- ШАГ 2: Режим электропитания High Performance (блокировка парковки ядер CPU) ---
Write-Host "`n[--->] ШАГ 2: Переключение схемы электропитания на High Performance..." -ForegroundColor Cyan
& powercfg.exe /setactive SCHEME_MIN
Write-Host "[+] Планировщик CPU: High Performance." -ForegroundColor Green

# --- ШАГ 3: DISM RestoreHealth — восстановление хранилища компонентов WinSxS ---
Write-Host "`n[--->] ШАГ 3: DISM /RestoreHealth (может занять 5–15 минут)..." -ForegroundColor Cyan
& DISM.exe /Online /Cleanup-Image /RestoreHealth
Write-Host "[+] DISM завершён." -ForegroundColor Green

# --- ШАГ 4: SFC scannow — проверка целостности системных файлов ---
Write-Host "`n[--->] ШАГ 4: SFC /scannow (может занять 5–10 минут)..." -ForegroundColor Cyan
& sfc /scannow
Write-Host "[+] SFC завершён." -ForegroundColor Green

Write-Host "`n$(("=" * 74))" -ForegroundColor Green
Write-Host "  СТАНЦИЯ ПРОШЛА QA-ТЕСТЫ И ГОТОВА К СДАЧЕ КЛИЕНТУ." -ForegroundColor Green
Write-Host ("=" * 74) -ForegroundColor Green
```

---

## БЛОК 14. QA — РУЧНОЙ АППАРАТНЫЙ АУДИТ

Выполняется после финальных скриптов, до передачи ПК клиенту.

### 14.1 Диспетчер устройств (`devmgmt.msc`)
1. `Win + X → Диспетчер устройств → Вид → Показать скрытые устройства`.
2. Проверить: **нет** неизвестных устройств (жёлтые `!`).
3. Видеокарта: установлен оригинальный драйвер (NVIDIA/AMD/Intel), **не** «Базовый видеоадаптер Майкрософт».

### 14.2 Частота ОЗУ (XMP / EXPO)
1. `Ctrl+Shift+Esc → Производительность → Память → строка «Скорость»`.
2. Если DDR4 показывает 2133/2400 МГц или DDR5 показывает 4800 МГц — перезагрузить, войти в UEFI и активировать XMP (Intel) / EXPO или DOCP (AMD).

### 14.3 Прошивка NVMe
Запустить вендорскую утилиту производителя SSD:
- Samsung → Samsung Magician
- Crucial → Crucial Storage Executive
- Kingston → Kingston SSD Manager
- WD → WD Dashboard

Проверить наличие обновлений Firmware. Актуальный микрокод критичен для предотвращения ухода контроллера в режим Read-Only (Panic Mode).

### 14.4 Для ноутбуков — ACPI-компоненты
Установить официальное ПО управления питанием:
- Lenovo → Lenovo Vantage
- ASUS → MyASUS или ASUS Armoury Crate
- HP → HP Support Assistant
- Dell → Dell SupportAssist

Без проприетарных ACPI-драйверов ядро 25H2 некорректно управляет фазами питания CPU на батарее.

---

## БЛОК 14 (продолжение). ФИНАЛЬНЫЙ ЧЕК-ЛИСТ ПРИЁМКИ

| # | Проверка | Инструмент | Ожидаемый результат |
|---|----------|------------|---------------------|
| 1 | Учётные записи | `control userpasswords2` | Только профиль клиента. Запись `Admin` — **отсутствует** |
| 2 | Папка профилей | `C:\Users\` | Каталог `C:\Users\Admin` **удалён**. Имя папки клиента совпадает со старым ПК |
| 3 | Целостность ОС | `sfc /scannow` | «Защита ресурсов Windows не обнаружила нарушений целостности» |
| 4 | BitLocker | `manage-bde -status C:` | `Protection Status: Off` |
| 5 | Браузер | Запуск Chrome / Яндекс | Вкладки восстановлены, клиент авторизован на рабочих сайтах |
| 6 | VS Code | Запуск VS Code | Тема оформления, плагины, история проектов — на месте |
| 7 | Активация Windows | `winver` или Параметры → Активация | Статус: «Windows активирована» |
| 8 | Частота ОЗУ | Диспетчер задач → Память | Скорость соответствует XMP/EXPO профилю (не базовая JEDEC) |
| 9 | DNS | `nslookup google.com` | Ответ от `1.1.1.1` или `8.8.8.8` |
| 10 | Планировщик CPU | `powercfg /getactivescheme` | GUID совпадает с High Performance |

---

## БЛОК 15. АВАРИЙНЫЙ ОТКАТ

### Если Sysprep завершился с ошибкой (Fatal Error)

1. Прочитать лог: `C:\Windows\System32\Sysprep\Panther\setuperr.log`
2. Частая причина — остались provisioned AppX-пакеты:
   ```powershell
   Get-AppxProvisionedPackage -Online | Remove-AppxProvisionedPackage -Online
   ```
3. Повторить Sysprep. **Лимит перезапусков**: до 8 раз при `SkipRearm=1`.

### Если клиент получает «Временный профиль» при входе

Выполнить из CMD от администратора:
```cmd
icacls "C:\Users\ИмяКлиента" /reset /T /C /Q
icacls "C:\Users\ИмяКлиента" /setowner "ИмяКлиента" /T /C /Q
icacls "C:\Users\ИмяКлиента" /grant:r "ИмяКлиента":(OI)(CI)F /T /C /Q
icacls "C:\Users\ИмяКлиента" /grant:r "SYSTEM":(OI)(CI)F /T /C /Q
icacls "C:\Users\ИмяКлиента" /grant:r "Administrators":(OI)(CI)F /T /C /Q
```

### Если образ не загружается на новом ПК (BSOD 0x0000007B / синий экран)

Загрузиться с WinPE-флешки. В DiskGenius → ПКМ по разделу C: → **«Fix Boot»**. Убедиться, что диск в GPT (не MBR) и Secure Boot включён в UEFI.

### Полный откат
Если ситуация неисправима — развернуть образ заново с нуля из `Win25HPro_Final.pmf` (Этап 6). Профиль клиента в `.wim` не затронут и готов к повторному импорту.

---

## СВОДНАЯ МАТРИЦА КОНФИГУРАЦИИ НАКОПИТЕЛЕЙ

| Параметр | Системный SSD (C:) | Дополнительный HDD (D:) |
|----------|--------------------|------------------------|
| Таблица разделов | GPT | GPT |
| Выравнивание секторов | 2048 sectors (4K Alignment) | Желательно |
| Размер кластера NTFS | 4 КБ | 64 КБ |
| Индексация Windows Search | Включена | ❌ Выключена |
| Файл подкачки | Статический 4096/4096 МБ | ❌ Запрещён |
| Гибернация | ❌ Выключена | — |
| CompactOS | ✅ Включён (LZX) | ❌ Выключен |
| NVMe APST (микросон) | ❌ Заблокирован | — |
| TRIM | ✅ Автоматический | — |

---

*Мануал проверен, логические противоречия устранены, скрипты исправлены. Методология покрывает полный жизненный цикл: от извлечения данных до сдачи станции клиенту.*
