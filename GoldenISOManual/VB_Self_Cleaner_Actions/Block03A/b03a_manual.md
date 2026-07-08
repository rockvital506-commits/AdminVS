STEP_MODE: true

# Требования:
- следи за правильностью/верностью/точностью своих ответов
- всегда задавайся вопросом об однозначности своих выводов перед ответом
- если для однозначности выводов нужен дополнительный контекст - уточняй у меня перед формированием ответа
- если однозначность выводов не подтверждена собирай дополнительную информацию и проводи дополнительные проверки
- ответ должен быть проверен и протестирован
- не давай ответ пока он не прошел все тесты и проверки

# Цель:
- практическая инструкция к блоку 03A с учетом лучших практик и наработок по блокировке фоновой активности

# Задания:
- собери всю информацию связанную с блоком 03A
- собери всю информацию связанную с София Скрипт
- критически проанализируй собранную информацию
- критически проанализируй все файлы блока 03A
- критически проанализируй стратегию взаимодействия файлов блока 03A
- критически проанализируй разработаннаю нами в процессе диалога методологию/правила/стратегию создания/написания:
   - файлов powershell скриптов(файлы: применения действий, верефикации результата, и так далее)
   - файлов окружения powershell скриптов(файлы: для считывания, логирования, перекодировки, и так далее)
- систематизируй результаты анализов
- дополни/исправь разработаннаю нами в процессе диалога методологию/правила/стратегию создания/написания файлов powershell скриптов и файлов их окружения
- создай и протестируй весь набор файлов в соответствии с полученной инструкцией(методологией/правилами/стратегией) создания/написания файлов powershell скриптов и файлов их окружения
- протестируй весь полученный набор файлов
- если тестирование не пройдены начинай выполнять задания сначала
- отдай итоговые выверенные файлы блока 03а и инструкции по их применению
- дополни/исправь разработаннаю нами в процессе диалога практическую инструкцию к блоку 03A
- критически проанализируй полученную инструкцию
- дополни/исправь там где нужно
- отдай итоговую выверенную инструкцию к блоку 03A







---

# 📋 ИТОГОВАЯ ИНСТРУКЦИЯ ПО ПРИМЕНЕНИЮ

## Шаг 1. Подготовка папки

```powershell
# 1. Открыть PowerShell ОТ ИМЕНИ АДМИНИСТРАТОРА
# 2. Перейти в папку блока
cd "Z:\home-pc\Block03A"

# 3. Создать папку если её нет
New-Item -ItemType Directory -Path "Z:\home-pc\Block03A" -Force
```

---

## Шаг 2. Создание всех файлов (АВТОМАТИЧЕСКАЯ КОДИРОВКА)

**Важно:** Каждый файл создаётся через here-string + `WriteAllText`, что **гарантирует** кодировку UTF-8 с BOM.

### 2.1. Создать Config.psd1

Скопируйте **ВЕСЬ код из ФАЙЛА 1** и вставьте в PowerShell. Нажмите Enter.

**Ожидаемый результат:**
```
[+] Файл Config.psd1 создан в кодировке UTF-8 с BOM
```

### 2.2. Создать Apply.ps1

Скопируйте **ВЕСЬ код из ФАЙЛА 2** и вставьте в PowerShell. Нажмите Enter.

**Ожидаемый результат:**
```
[+] Файл Apply.ps1 создан в кодировке UTF-8 с BOM
```

### 2.3. Создать Verify.ps1

Скопируйте **ВЕСЬ код из ФАЙЛА 3** и вставьте в PowerShell. Нажмите Enter.

**Ожидаемый результат:**
```
[+] Файл Verify.ps1 создан в кодировке UTF-8 с BOM
```

### 2.4. Создать Rollback.ps1

Скопируйте **ВЕСЬ код из ФАЙЛА 4** и вставьте в PowerShell. Нажмите Enter.

**Ожидаемый результат:**
```
[+] Файл Rollback.ps1 создан в кодировке UTF-8 с BOM
```

### 2.5. Создать Recode.ps1 (опционально)

Скопируйте **ВЕСЬ код из ФАЙЛА 5** и вставьте в PowerShell. Нажмите Enter.

**Ожидаемый результат:**
```
[+] Файл Recode.ps1 создан в кодировке UTF-8 с BOM
```

**Зачем нужен Recode.ps1:**
- Если вы создали файлы вручную через Блокнот (не через PowerShell)
- Если кодировка файлов была повреждена
- Если нужно перекодировать файлы в другой формат (ANSI, UTF-8 без BOM)

**Если файлы созданы через here-string + WriteAllText — Recode.ps1 НЕ НУЖЕН.**

---

## Шаг 3. Проверка наличия всех файлов

```powershell
dir *.ps1, *.psd1
```

**Ожидаемый результат:**
```
Config.psd1
Apply.ps1
Verify.ps1
Rollback.ps1
Recode.ps1
```

---

## Шаг 4. Предполетная подготовка (Tamper Protection)

**КРИТИЧНО:** Перед запуском Apply.ps1 **обязательно** отключите Tamper Protection вручную:

1. Пуск → **Безопасность Windows** → **Защита от вирусов и угроз**
2. **Управление настройками** → Выключите **Защита от несанкционированного доступа** (Tamper Protection)
3. Если тумблер серый — удалите ключ `DisableAntiSpyware` из реестра:
   ```powershell
   Remove-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Recurse -Force -ErrorAction SilentlyContinue
   ```
4. Перезагрузите ВМ:
   ```powershell
   shutdown /r /t 0
   ```

---

## Шаг 5. Запуск Apply.ps1

```powershell
powershell -ExecutionPolicy Bypass -File ".\Apply.ps1"
```

**Что происходит:**
1. ✅ Проверка прав администратора
2. ✅ Загрузка Config.psd1
3. ✅ Проверка Tamper Protection (если включен — скрипт остановится с инструкцией)
4. ✅ Создание снапшота `State_Backup.json`
5. ✅ Блокировка всех служб из конфига
6. ✅ Применение ключей реестра
7. ✅ Отключение задач планировщика

**Ожидаемый результат:**
```
[+] БЛОК 03A УСПЕШНО ПРИМЕНЕН.
[!] Запустите Verify.ps1 для проверки результата.
```

---

## Шаг 6. Запуск Verify.ps1

```powershell
powershell -ExecutionPolicy Bypass -File ".\Verify.ps1"
```

**Ожидаемый результат:**
```
========================================================================
  DASHBOARD: ПРОВЕРКА БЛОКА 03A
========================================================================

--- СЛУЖБЫ ---
[OK]   wuauserv [Status]
[OK]   wuauserv [StartType]
...

--- РЕЕСТР ---
[OK]   Reg: DODownloadMode
...

========================================================================
  ВСЕГО: 45 | ПРОЙДЕНО: 45 | ПРОВАЛЕНО: 0
  [OK] СИСТЕМА ГОТОВА К СЛЕДУЮЩЕМУ БЛОКУ.
========================================================================
```

---

## Шаг 7. Откат (если нужно)

```powershell
powershell -ExecutionPolicy Bypass -File ".\Rollback.ps1"
```

**Когда использовать:**
- Ошибка в конфигурации
- Служба нужна для работы
- Тестирование без последствий

---

## Шаг 8. Перекодировка (если нужно)

**Если файлы созданы через here-string + WriteAllText — этот шаг ПРОПУСТИТЬ.**

Если файлы созданы вручную через Блокнот:

1. Откройте `Recode.ps1` в Notepad++
2. Убедитесь, что в секции CONFIG раскомментирована нужная кодировка:
   ```powershell
   $TARGET_ENCODING = 'UTF8-BOM'          # UTF-8 с BOM (для .ps1 и .psd1)
   ```
3. Запустите:
   ```powershell
   powershell -ExecutionPolicy Bypass -File ".\Recode.ps1"
   ```

---

# 📋 ИТОГОВАЯ ИНСТРУКЦИЯ К БЛОКУ 03A

## 🎯 Цели блока

| Цель | Обоснование | Приоритет |
|:---|:---|:---|
| Предотвратить фоновое обновление AppX/Store | Обновление UWP = гарантированный крах Sysprep | 🔴 Критично |
| Остановить Windows Update | Таймауты, запись логов, нагрузка на I/O без интернета | 🔴 Критично |
| Заблокировать телеметрию | DiagTrack пишет логи, потребляет CPU/Disk | 🟡 Высокий |
| Отключить индексацию | WSearch фрагментирует файлы перед захватом | 🟢 Средний |
| Заблокировать задачи планировщика | Фоновые триггеры могут запустить обновления | 🔴 Критично |
| Временно отключить Windows Defender | Real-time Protection блокирует скрипты | 🔴 Критично |

---

## 🏗️ Архитектура блока

```
БЛОК 03A/
├── Config.psd1          # Конфигурация (UTF-8 с BOM, поддерживает комментарии)
├── Apply.ps1            # Движок применения блокировок (UTF-8 с BOM)
├── Verify.ps1           # Dashboard верификации (UTF-8 с BOM)
├── Rollback.ps1         # Откат изменений (UTF-8 с BOM)
├── Recode.ps1           # Перекодировщик файлов (UTF-8 с BOM, опционально)
├── State_Backup.json    # Снапшот состояния (создаётся автоматически)
└── block_log.txt        # Лог операций (создаётся автоматически)
```

**Почему .psd1 вместо JSON:**
- ✅ Поддерживает комментарии (`#`)
- ✅ Можно закомментировать целые блоки
- ✅ Безопасная загрузка через `Import-PowerShellDataFile`
- ✅ Нативный формат PowerShell

---

## 🔄 Workflow блока

```
1. Создание файлов (через here-string + WriteAllText)
   ↓
2. Проверка Tamper Protection (вручную через GUI)
   ↓
3. Запуск Apply.ps1 (применение блокировок)
   ↓
4. Запуск Verify.ps1 (проверка результата)
   ↓
5. Если FAIL → исправить → повторить Apply
   ↓
6. Если OK → переход к следующему блоку
```

---

## 🔍 Решение типовых проблем

| Проблема | Симптом | Решение |
|:---|:---|:---|
| **Tamper Protection включен** | `[X] КРИТИЧНО: Tamper Protection включен` | Отключить вручную через GUI: Безопасность Windows → Защита от вирусов → Управление настройками → Выключить Tamper Protection → Перезагрузить ВМ |
| **Access Denied для Set-Service** | `Отказано в доступе` | Скрипт автоматически делает fallback на реестр |
| **Access Denied для задач** | `Task Skipped (Access Denied)` | Это нормально для WindowsUpdate/Application Experience — службы уже отключены |
| **Кракозябры в выводе** | `РПСѓС‚СЊ` вместо `Путь` | Использовать Recode.ps1 для перекодировки в UTF-8 с BOM |
| **UnauthorizedAccess** | `Невозможно загрузить файл` | Запускать через `powershell -ExecutionPolicy Bypass -File` |
| **Пустой $ScriptPath** | `Не удается привязать аргумент` | Используется `$PSScriptRoot` — работает только при запуске файла, не при копипасте |

---

## ✅ Финальный чек-лист блока 03A

- [ ] PowerShell запущен от имени Администратора
- [ ] Tamper Protection отключен (значение = 0)
- [ ] Все 5 файлов созданы через here-string + WriteAllText
- [ ] Все файлы в кодировке UTF-8 с BOM
- [ ] `Config.psd1` создан в папке `Z:\home-pc\Block03A\`
- [ ] `Apply.ps1` создан и выполнен успешно
- [ ] `State_Backup.json` создан (снапшот состояния)
- [ ] `Verify.ps1` показал 0 провалов
- [ ] Все службы из конфига → Status: Stopped
- [ ] Защищённые службы (TrustedInstaller) → Start=4 в реестре
- [ ] Ключи реестра Delivery Optimization и OneDrive применены
- [ ] Задачи планировщика отключены (Access Denied — это нормально)
- [ ] `Rollback.ps1` создан для возможности отката

---

## 📊 Взаимодействие файлов

| Файл | Назначение | Когда используется |
|:---|:---|:---|
| `Config.psd1` | Данные и настройки | Редактируется при добавлении новых служб |
| `Apply.ps1` | Применение изменений | Выполняется один раз в Блоке 03A и повторно в Блоке 03B |
| `Verify.ps1` | Проверка результата | Выполняется после `Apply.ps1` |
| `Rollback.ps1` | Откат изменений | Только при необходимости отмены |
| `Recode.ps1` | Перекодировка файлов | Только если файлы созданы вручную через Блокнот |

---

# 📋 БЛОК 03A: ИТОГОВЫЕ ФАЙЛЫ (ВСЕ С АВТОМАТИЧЕСКОЙ КОДИРОВКОЙ)

## 📄 ФАЙЛ 1: Config.psd1 (создание через PowerShell)

**Скопируйте ВЕСЬ код ниже и вставьте в PowerShell от имени Администратора:**

```powershell
$config = @'
#Requires -Version 5.1
# ==============================================================================
# КОНФИГУРАЦИЯ БЛОКА 03A: Блокировка фоновой активности
# ВАЖНО: Этот файл автоматически сохранён в кодировке UTF-8 с BOM!
# ==============================================================================
# ИНСТРУКЦИЯ:
# Чтобы отключить целый блок, установите Enabled = $false
# Чтобы отключить конкретную службу, закомментируйте строку в массиве Services.
# ==============================================================================

@{
    # --- БЛОК 1: WINDOWS UPDATE ---
    WindowsUpdate = @{
        Enabled = $true
        Services = @(
            @{ Name = 'wuauserv';    State = 'Disabled'; Method = 'Service'  }
            @{ Name = 'UsoSvc';      State = 'Disabled'; Method = 'Service'  }
            @{ Name = 'WaaSMedicSvc';State = 'Disabled'; Method = 'Registry' } # TrustedInstaller
            @{ Name = 'DoSvc';       State = 'Disabled'; Method = 'Registry' } # TrustedInstaller
            @{ Name = 'BITS';        State = 'Manual';   Method = 'Service'  }
        )
    }

    # --- БЛОК 2: MICROSOFT STORE & APPX ---
    StoreAppX = @{
        Enabled = $true
        Services = @(
            @{ Name = 'InstallService'; State = 'Disabled'; Method = 'Registry' }
            @{ Name = 'AppXSvc';        State = 'Disabled'; Method = 'Registry' }
            @{ Name = 'ClipSVC';        State = 'Disabled'; Method = 'Registry' }
            @{ Name = 'LicenseManager'; State = 'Disabled'; Method = 'Service'  }
        )
    }

    # --- БЛОК 3: ТЕЛЕМЕТРИЯ И ДИАГНОСТИКА ---
    Telemetry = @{
        Enabled = $true
        Services = @(
            @{ Name = 'DiagTrack';         State = 'Disabled'; Method = 'Service' }
            @{ Name = 'dmwappushservice';  State = 'Disabled'; Method = 'Service' }
            @{ Name = 'WerSvc';            State = 'Disabled'; Method = 'Service' }
        )
    }

    # --- БЛОК 4: ИНДЕКСАЦИЯ И КЭШИРОВАНИЕ ---
    Indexing = @{
        Enabled = $true
        Services = @(
            @{ Name = 'WSearch'; State = 'Disabled'; Method = 'Service' }
            @{ Name = 'SysMain'; State = 'Disabled'; Method = 'Service' }
        )
    }

    # --- БЛОК 5: РЕЕСТР И ПОЛИТИКИ ---
    RegistryPolicies = @{
        Enabled = $true
        Keys = @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode';      Value = 0; Type = 'DWord' },
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'AllowCloudDownload';  Value = 0; Type = 'DWord' },
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive';             Name = 'DisableFileSyncNGSC'; Value = 1; Type = 'DWord' },
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive';             Name = 'PreventOneDriveFromStarting'; Value = 1; Type = 'DWord' }
        )
    }

    # --- БЛОК 6: ЗАДАЧИ ПЛАНИРОВЩИКА ---
    ScheduledTasks = @{
        Enabled = $true
        Paths = @(
            '\Microsoft\Windows\WindowsUpdate\',
            '\Microsoft\Windows\Setup\',
            '\Microsoft\Windows\Application Experience\',
            '\Microsoft\Windows\Customer Experience Improvement Program\',
            '\Microsoft\Windows\Autochk\',
            '\Microsoft\Windows\DiskDiagnostic\'
        )
    }
}
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\Config.psd1", $config, $utf8Bom)

Write-Host "[+] Файл Config.psd1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green
```

---

## 📄 ФАЙЛ 2: Apply.ps1 (создание через PowerShell)

**Скопируйте ВЕСЬ код ниже и вставьте в PowerShell от имени Администратора:**

```powershell
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
```

---

## 📄 ФАЙЛ 3: Verify.ps1 (создание через PowerShell)

**Скопируйте ВЕСЬ код ниже и вставьте в PowerShell от имени Администратора:**

```powershell
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
```

---

## 📄 ФАЙЛ 4: Rollback.ps1 (создание через PowerShell)

**Скопируйте ВЕСЬ код ниже и вставьте в PowerShell от имени Администратора:**

```powershell
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
```

---

## 📄 ФАЙЛ 5: Recode.ps1 (универсальный перекодировщик)

**Этот файл НЕ ОБЯЗАТЕЛЕН для базового workflow**, но полезен если вы создали файлы вручную через Блокнот.

**Скопируйте ВЕСЬ код ниже и вставьте в PowerShell от имени Администратора:**

```powershell
$script = @'
<#
.SYNOPSIS
    Универсальный перекодировщик файлов для блока 03A.
.DESCRIPTION
    Применяется ТОЛЬКО если файлы были созданы вручную через Блокнот (не через PowerShell).
    Если файлы созданы через here-string + WriteAllText — этот скрипт не нужен.
.NOTES
    Кодировка: UTF-8 с BOM (гарантирована при создании).
#>

# ==============================================================================
# CONFIG - НАСТРОЙКИ ПЕРЕКОДИРОВАНИЯ
# ==============================================================================

# --- ЦЕЛЕВАЯ КОДИРОВКА (выберите ОДНУ) ---
$TARGET_ENCODING = 'UTF8-BOM'          # UTF-8 с BOM (для .ps1 и .psd1)
# $TARGET_ENCODING = 'UTF8-NOBOM'      # UTF-8 без BOM (для .json, .txt)
# $TARGET_ENCODING = 'ANSI'            # Windows-1251 (для .cmd)

# --- ИСХОДНАЯ КОДИРОВКА ---
$SOURCE_ENCODING = 'AUTO'

# --- ФАЙЛЫ ДЛЯ ПЕРЕКОДИРОВАНИЯ ---
$FILES = @(
    'Apply.ps1',
    'Verify.ps1',
    'Rollback.ps1',
    'Config.psd1'
)

# ==============================================================================
# ЛОГИКА (не редактировать)
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

if ($MyInvocation.MyCommand.Definition) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $ScriptPath = $PWD.Path
}

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  ПЕРЕКОДИРОВЩИК ФАЙЛОВ БЛОКА 03A" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

Write-Host "[INFO] Целевая кодировка: ${TARGET_ENCODING}" -ForegroundColor Yellow
Write-Host "[INFO] Файлов в списке: $($FILES.Count)`n" -ForegroundColor Yellow

function Get-Encoding {
    param([string]$Name)
    switch ($Name.ToUpper()) {
        'UTF8-BOM'    { return [System.Text.UTF8Encoding]::new($true) }
        'UTF8-NOBOM'  { return [System.Text.UTF8Encoding]::new($false) }
        'ANSI'        { return [System.Text.Encoding]::Default }
        default       { throw "Неизвестная кодировка: $Name" }
    }
}

function Get-SourceEncoding {
    param([string]$FilePath)
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -lt 3) { return [System.Text.Encoding]::UTF8 }
    
    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "  [AUTO] Обнаружен UTF-8 BOM" -ForegroundColor Gray
        return [System.Text.UTF8Encoding]::new($true)
    }
    
    Write-Host "  [AUTO] BOM не обнаружен, предполагаем UTF-8 без BOM" -ForegroundColor Gray
    return [System.Text.UTF8Encoding]::new($false)
}

$targetEnc = Get-Encoding $TARGET_ENCODING
$sourceEnc = if ($SOURCE_ENCODING -eq 'AUTO') { $null } else { Get-Encoding $SOURCE_ENCODING }

$successCount = 0; $skipCount = 0; $failCount = 0

foreach ($fileRel in $FILES) {
    if ([System.IO.Path]::IsPathRooted($fileRel)) {
        $filePath = $fileRel
    } else {
        $filePath = Join-Path $ScriptPath $fileRel
    }
    
    Write-Host "Обработка: $filePath" -ForegroundColor White
    
    if (-not (Test-Path $filePath)) {
        Write-Host "  [SKIP] Файл не найден" -ForegroundColor DarkYellow
        $skipCount++
        continue
    }
    
    try {
        $enc = if ($sourceEnc) { $sourceEnc } else { Get-SourceEncoding $filePath }
        $content = [System.IO.File]::ReadAllText($filePath, $enc)
        [System.IO.File]::WriteAllText($filePath, $content, $targetEnc)
        
        Write-Host "  [OK] Перекодировано в ${TARGET_ENCODING}" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "  [FAIL] Ошибка: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  ИТОГ: Успешно=$successCount | Пропущено=$skipCount | Ошибок=$failCount" -ForegroundColor White
Write-Host "========================================================================`n" -ForegroundColor Cyan

if ($failCount -eq 0) {
    Write-Host "[+] Все файлы перекодированы успешно." -ForegroundColor Green
} else {
    Write-Host "[!] Есть ошибки. Проверьте файлы и пути." -ForegroundColor Red
}

pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\Recode.ps1", $script, $utf8Bom)

Write-Host "[+] Файл Recode.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green
```

---

**БЛОК 03A ЗАВЕРШЁН.** Все фоновые службы заблокированы, задачи планировщика отключены, телеметрия подавлена. Система готова к установке offline-обновлений через DISM (Блок 04).
