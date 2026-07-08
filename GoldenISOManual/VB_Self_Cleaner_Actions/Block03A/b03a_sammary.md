# 📋 САММАРИ: БЛОК 03A — Первичная блокировка фоновой активности

## 🎯 Назначение блока

Блок 03A решает **критическую задачу** подготовки Golden Image Windows 10/11: полное подавление фоновой активности системы (телеметрия, обновления, индексация, AI-компоненты) перед началом модификаций. Без этого блока любые последующие действия будут нестабильны, а Sysprep гарантированно упадёт.

**Ключевая проблема:** Windows 11 25H2 агрессивно обновляет AppX-пакеты в фоне через службы `InstallService`, `AppXSvc`, `ClipSVC`. Если эти службы активны во время сборки образа — Sysprep получит фатальную ошибку рассинхронизации AppX.

---

## 🏗️ Архитектура файлов (модульная система)

```
Block03A/
├── Config.psd1          # Конфигурация (поддерживает комментарии)
├── Apply.ps1            # Движок применения блокировок
├── Verify.ps1           # Dashboard верификации
├── Rollback.ps1         # Откат изменений из снапшота
├── Recode.ps1           # Перекодировщик файлов (UTF-8 с BOM)
├── State_Backup.json    # Снапшот состояния (создаётся автоматически)
└── block_log.txt        # Лог операций (создаётся автоматически)
```

### Почему `.psd1` вместо `.json`?
- ✅ Поддерживает комментарии (`#`) — можно закомментировать блок без удаления
- ✅ Безопасная загрузка через `Import-PowerShellDataFile` (не выполняет код)
- ✅ Нативный формат PowerShell (хэш-таблицы, массивы)

### Почему модульная архитектура?
- ✅ **Разделение ответственности:** Config — только данные, Apply — только логика
- ✅ **Идемпотентность:** повторный запуск не ломает систему
- ✅ **Верификация:** `Verify.ps1` работает как независимый аудитор
- ✅ **Откат:** `Rollback.ps1` восстанавливает систему из снапшота
- ✅ **Масштабируемость:** добавление новой службы = правка только `Config.psd1`

---

## 🔴 Критические проблемы и их решения

### Проблема 1: Tamper Protection блокирует изменения

**Симптом:** `Access Denied` при попытке изменить службы Defender или реестр.

**Решение:**
1. Отключить Tamper Protection **вручную через GUI**: Безопасность Windows → Защита от вирусов → Управление настройками → Выключить "Защита от несанкционированного доступа"
2. Перезагрузить ВМ
3. `Apply.ps1` имеет **Pre-Flight Check** — если Tamper Protection включен, скрипт остановится с понятной инструкцией

**Код проверки:**
```powershell
$TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
$TamperValue = (Get-ItemProperty $TamperPath -ErrorAction SilentlyContinue).TamperProtection
if ($TamperValue -ne 0) {
    Write-Host "[X] Tamper Protection включен!" -ForegroundColor Red
    pause; Exit 1
}
```

---

### Проблема 2: TrustedInstaller защищает службы

**Симптом:** `Set-Service` возвращает `Access Denied` для `WaaSMedicSvc`, `DoSvc`, `AppXSvc`, `ClipSVC`, `InstallService`.

**Решение:** Автоматический **fallback на реестр** в `Apply.ps1`:
```powershell
try {
    Set-Service -Name $Svc.Name -StartupType Disabled -ErrorAction Stop
}
catch {
    # Fallback на реестр
    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Svc.Name)"
    Set-ItemProperty -Path $RegPath -Name "Start" -Value 4 -Type DWord -Force
}
```

**Значения параметра `Start`:**
| Значение | Тип запуска |
|:---:|:---|
| 0 | Boot |
| 1 | System |
| 2 | Automatic |
| 3 | Manual |
| 4 | **Disabled** |

---

### Проблема 3: Кодировка UTF-8 без BOM

**Симптом:** Кракозябры (`РПСѓС‚СЊ` вместо `Путь`), ошибки парсинга `ParserError`, `MissingCatchOrFinally`.

**Решение:** Все `.ps1` и `.psd1` файлы **ДОЛЖНЫ** быть сохранены в **UTF-8 с BOM**.

**Как создать файл с BOM через PowerShell:**
```powershell
$script = @'
<содержимое скрипта>
'@
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\script.ps1", $script, $utf8Bom)
```

**Перекодировщик:** `Recode.ps1` (если файлы созданы вручную через Блокнот).

---

### Проблема 4: ExecutionPolicy блокирует запуск

**Симптом:** `UnauthorizedAccess` при запуске `.ps1` файлов.

**Решение:** Запускать через:
```powershell
powershell -ExecutionPolicy Bypass -File ".\Apply.ps1"
```

Параметр `Bypass` действует **только для текущего процесса**, не изменяет системные настройки.

---

### Проблема 5: Пустой `$ScriptPath` при копипасте

**Симптом:** `$MyInvocation.MyCommand.Definition` возвращает пустую строку при вставке кода в консоль.

**Решение:** Универсальный паттерн:
```powershell
if ($MyInvocation.MyCommand.Definition) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $ScriptPath = $PWD.Path
}
```

---

### Проблема 6: Переменные перед двоеточием

**Симптом:** `InvalidVariableReferenceWithDrive` — PowerShell интерпретирует `$Var:` как drive specifier.

**Решение:** Использовать фигурные скобки `${Var}:`:
```powershell
# ❌ Неправильно
Write-Host "Ошибка: $Name: не найдено"

# ✅ Правильно
Write-Host "Ошибка: ${Name}: не найдено"
```

---

## 📊 Список заблокированных сущностей

### Службы (14 штук)

| Категория | Службы | Метод |
|:---|:---|:---|
| **Windows Update** | `wuauserv`, `UsoSvc`, `WaaSMedicSvc`, `DoSvc`, `BITS` | Service/Registry |
| **Store/AppX** | `InstallService`, `AppXSvc`, `ClipSVC`, `LicenseManager` | Registry/Service |
| **Телеметрия** | `DiagTrack`, `dmwappushservice`, `WerSvc` | Service |
| **Индексация** | `WSearch`, `SysMain` | Service |

### Ключи реестра (4 политики)

| Путь | Параметр | Значение |
|:---|:---|:---|
| `HKLM:\...\DeliveryOptimization` | `DODownloadMode` | 0 |
| `HKLM:\...\DeliveryOptimization` | `AllowCloudDownload` | 0 |
| `HKLM:\...\OneDrive` | `DisableFileSyncNGSC` | 1 |
| `HKLM:\...\OneDrive` | `PreventOneDriveFromStarting` | 1 |

### Задачи планировщика (6 путей)

- `\Microsoft\Windows\WindowsUpdate\*`
- `\Microsoft\Windows\Setup\*`
- `\Microsoft\Windows\Application Experience\*`
- `\Microsoft\Windows\Customer Experience Improvement Program\*`
- `\Microsoft\Windows\Autochk\*`
- `\Microsoft\Windows\DiskDiagnostic\*`

**Примечание:** Некоторые задачи защищены TrustedInstaller и возвращают `Access Denied` — это **нормально**, службы уже отключены, Sysprep очистит задачи при `/generalize`.

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
6. Если OK → переход к следующему блоку (Блок 04)
```

---

## ✅ Чек-лист применения

### Перед запуском Apply.ps1:
- [ ] PowerShell запущен от имени Администратора
- [ ] Tamper Protection отключен (значение = 0)
- [ ] Все 4 файла созданы через here-string + WriteAllText
- [ ] Все файлы в кодировке UTF-8 с BOM
- [ ] `Config.psd1` создан в папке `Z:\home-pc\Block03A\`

### После запуска Apply.ps1:
- [ ] `State_Backup.json` создан (снапшот состояния)
- [ ] Все службы из конфига → Status: Stopped
- [ ] Защищённые службы (TrustedInstaller) → Start=4 в реестре
- [ ] Ключи реестра Delivery Optimization и OneDrive применены
- [ ] Задачи планировщика отключены (Access Denied — это нормально)

### После запуска Verify.ps1:
- [ ] Dashboard показал 0 провалов
- [ ] Все проверки пройдены (зелёные галочки)

---

## 📚 Лучшие практики (выработаны в процессе диалога)

### 1. Разделение ответственности
Каждый файл отвечает за одну задачу:
- `Config.psd1` — только данные
- `Apply.ps1` — только логика применения
- `Verify.ps1` — только проверка
- `Rollback.ps1` — только откат

### 2. Конфигурация как код
Использовать `.psd1` вместо `.json` для конфигурации PowerShell.

### 3. Идемпотентность
Повторный запуск скрипта не должен ломать систему.

### 4. Pre-Flight проверки
Перед основными действиями проверить критичные условия (Tamper Protection, права админа).

### 5. Fallback механизмы
Если основной метод не сработал — попробовать альтернативный (Set-Service → Registry).

### 6. Снапшот перед изменениями
Сохранить исходное состояние ДО любых модификаций.

### 7. Верификация как Dashboard
Файл верификации показывает таблицу: Ожидалось | Фактически | Статус.

### 8. Восстановление с учётом типа
При откате реестра сохранять тип значения (DWord/String).

---

## 🔗 Связь с другими блоками

| Блок | Связь |
|:---|:---|
| **Блок 02** (Установка Windows + Audit Mode) | Предоставляет чистую среду Audit Mode для блокировки служб |
| **Блок 03B** (Повторная блокировка после установки ПО) | Использует тот же `Apply.ps1` для повторной блокировки (инсталляторы могут восстановить службы) |
| **Блок 04** (Offline-обновление системы) | Начинается после успешной блокировки. DISM устанавливает обновления без вмешательства WU |

---

## ⚠️ Критические ловушки

| Ловушка | Симптом | Решение |
|:---|:---|:---|
| Tamper Protection включен | `[X] КРИТИЧНО: Tamper Protection включен` | Отключить вручную через GUI → Перезагрузить ВМ |
| Access Denied для Set-Service | `Отказано в доступе` | Скрипт автоматически делает fallback на реестр |
| Access Denied для задач | `Task Skipped (Access Denied)` | Это нормально — службы уже отключены |
| Кракозябры в выводе | `РПСѓС‚СЊ` вместо `Путь` | Использовать Recode.ps1 для перекодировки в UTF-8 с BOM |
| UnauthorizedAccess | `Невозможно загрузить файл` | Запускать через `powershell -ExecutionPolicy Bypass -File` |
| Пустой $ScriptPath | `Не удается привязать аргумент` | Используется универсальный паттерн с fallback на `$PWD` |

---

## 📊 Сравнение с Sophia Script

| Критерий | Sophia Script | Наши скрипты (Блок 03A) |
|:---|:---|:---|
| **Функционал** | ~235 функций (полная настройка) | ~20 функций (только блокировка) |
| **Архитектура** | Монолитный модуль с GUI | Модульная система (Config + Apply + Verify + Rollback) |
| **Верификация** | ❌ Нет встроенной проверки | ✅ Dashboard с цветными статусами |
| **Откат** | ❌ Нет встроенного отката | ✅ Rollback из снапшота |
| **Tamper Protection** | ❌ Не проверяет | ✅ Pre-Flight Check с инструкцией |
| **Fallback механизмы** | ❌ Нет | ✅ Автоматический fallback на реестр |
| **Кодировка** | Стандартная | UTF-8 с BOM (гарантировано) |

**Вывод:** Sophia Script — для широкой настройки системы. Наши скрипты — для критичной блокировки перед Sysprep (где важна верификация и откат).

---

## 🎯 Итоговый статус

**БЛОК 03A ЗАВЕРШЁН.** Все фоновые службы заблокированы, задачи планировщика отключены, телеметрия подавлена. Система готова к установке offline-обновлений через DISM (Блок 04).

**Жду команду на переход к Блоку 04 (Offline-обновление системы).**
