
STEP_MODE: true

# Требования:
- следи за правильностью/верностью/точностью своих ответов
- всегда задавайся вопросом об однозначности своих выводов перед ответом
- если для однозначности выводов нужен дополнительный контекст - уточняй у меня перед формированием ответа
- если однозначность выводов не подтверждена собирай дополнительную информацию и проводи дополнительные проверки
- ответ должен быть проверен и протестирован
- не давай ответ пока он не прошел все тесты и проверки

# Цель:
- практический мануал для передачи ллм лучших практик и наработок по созданию/написанию файлов powershell скриптов и файлов их окружения

# Задания:
- собери всю информацию связанную с блоком 03A
- собери всю информацию связанную с София Скрипт
- критически проанализируй собранную информацию
- критически проанализируй все файлы блока 03A
- критически проанализируй стратегию взаимодействия файлов блока 03A
- критически проанализируй разработаннаю нами в процессе диалога методологию/правила/стратегию создания/написания:
   - файлов powershell скриптов(файлы: применения действий, верефикации результата, и так далее)
   - файлов окружения powershell скриптов(файлы: для считывания, логирования, и так далее)
- систематизируй результаты анализов
- дополни/исправь разработаннаю нами в процессе диалога методологию/правила/стратегию создания/написания файлов powershell скриптов и файлов их окружения
- создай практический мануал для передачи ллм лучших практик и наработок по созданию/написанию файлов powershell скриптов и файлов их окружения
- критически проанализируй полученный мануал
- дополни/исправь там где нужно
- отдай итоговый выверенный мануал



# 📘 ПРАКТИЧЕСКИЙ МАНУАЛ: Лучшие практики создания PowerShell скриптов и файлов окружения

## 🎯 Назначение мануала

Этот документ передаёт LLM проверенные инженерные практики создания PowerShell-скриптов для системного администрирования Windows. Все правила основаны на реальном опыте разработки Блока 03A (блокировка фоновой активности для Golden Image) и анализе проекта Sophia Script.

---

##  АРХИТЕКТУРНЫЕ ПРИНЦИПЫ

### Принцип 1: Разделение ответственности (Separation of Concerns)

**Правило:** Каждый файл отвечает за одну задачу.

| Файл | Назначение | Пример |
|:---|:---|:---|
| `Config.psd1` | Данные и настройки | Список служб, пути реестра |
| `Apply.ps1` | Применение изменений | Остановка служб, запись в реестр |
| `Verify.ps1` | Проверка результата | Чтение состояния, сравнение с ожидаемым |
| `Rollback.ps1` | Откат изменений | Восстановление из бэкапа |
| `Recode.ps1` | Утилитарные операции | Перекодировка файлов |

**Почему:** Если нужно добавить новую службу — правим только `Config.psd1`, не трогая логику.

---

### Принцип 2: Конфигурация как код (Configuration as Code)

**Правило:** Использовать `.psd1` вместо `.json` для конфигурации PowerShell.

**Почему .psd1 лучше JSON:**
- ✅ Поддерживает комментарии (`#`)
- ✅ Можно закомментировать блок без удаления
- ✅ Безопасная загрузка через `Import-PowerShellDataFile` (не выполняет код)
- ✅ Нативный тип PowerShell (хэш-таблицы, массивы)

**Пример Config.psd1:**
```powershell
@{
    # Блок можно отключить: Enabled = $false
    WindowsUpdate = @{
        Enabled = $true
        Services = @(
            @{ Name = 'wuauserv'; State = 'Disabled'; Method = 'Service' }
            # @{ Name = 'DoSvc'; State = 'Disabled'; Method = 'Registry' }  # Закомментировано
        )
    }
}
```

**Антипаттерн:** JSON без комментариев, где нужно редактировать список вручную.

---

### Принцип 3: Идемпотентность (Idempotency)

**Правило:** Повторный запуск скрипта не должен ломать систему.

**Реализация:**
```powershell
# Проверка перед действием
if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}

# Установка значения (даже если уже правильное)
Set-ItemProperty -Path $RegPath -Name $Name -Value $Value -Force
```

**Почему:** Инженер может запустить скрипт дважды по ошибке — система не должна сломаться.

---

## 🔧 ПРАВИЛА СОЗДАНИЯ ФАЙЛОВ

### Правило 1: Кодировка UTF-8 с BOM

**КРИТИЧНО:** Все `.ps1` и `.psd1` файлы **ДОЛЖНЫ** быть сохранены в **UTF-8 с BOM**.

**Почему:** PowerShell 5.1 читает файлы без BOM как ANSI → кракозябры → ParserError.

**Как создать файл с BOM через PowerShell:**
```powershell
$script = @'
<содержимое скрипта>
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\script.ps1", $script, $utf8Bom)
```

**Как проверить кодировку:**
```powershell
$bytes = [System.IO.File]::ReadAllBytes("script.ps1")
if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    Write-Host "UTF-8 с BOM" -ForegroundColor Green
}
```

**Антипаттерн:** Сохранение через обычный Блокнот (создаёт UTF-8 без BOM).

---

### Правило 2: Универсальное определение пути скрипта

**Проблема:** `$MyInvocation.MyCommand.Definition` возвращает пустую строку при копипасте кода в консоль.

**Решение:**
```powershell
if ($MyInvocation.MyCommand.Definition) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $ScriptPath = $PWD.Path
}
```

**Почему:** Скрипт работает и при запуске файла, и при копипасте.

**Антипаттерн:**
```powershell
#  Не работает при копипасте
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
```

---

### Правило 3: Обход ExecutionPolicy

**Правило:** Запускать скрипты через `powershell -ExecutionPolicy Bypass -File`.

**Команда:**
```powershell
powershell -ExecutionPolicy Bypass -File ".\Apply.ps1"
```

**Почему:** Политика `Restricted` по умолчанию блокирует `.ps1` файлы. Параметр `Bypass` действует только для текущего процесса.

**Антипаттерн:** Изменение системной политики через `Set-ExecutionPolicy RemoteSigned -Scope LocalMachine` (требует прав админа, влияет на всю систему).

---

### Правило 4: Переменные перед двоеточием

**Проблема:** PowerShell интерпретирует `$Var:` как drive specifier (как `$env:`).

**Решение:** Использовать фигурные скобки `${Var}:`

**Пример:**
```powershell
# ❌ Неправильно
Write-Host "Ошибка: $Name: не найдено"

# ✅ Правильно
Write-Host "Ошибка: ${Name}: не найдено"
```

**Где встречается:** В строках с путями реестра, сообщениях об ошибках.

---

## 🛡️ ПРАВИЛА БЕЗОПАСНОСТИ

### Правило 1: Pre-Flight проверки

**Правило:** Перед основными действиями проверить критичные условия.

**Пример (Tamper Protection):**
```powershell
$TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
$TamperValue = (Get-ItemProperty $TamperPath -ErrorAction SilentlyContinue).TamperProtection

if ($TamperValue -ne 0) {
    Write-Host "[X] КРИТИЧНО: Tamper Protection включен!" -ForegroundColor Red
    Write-Host "    Отключите вручную: Безопасность Windows → Защита от вирусов" -ForegroundColor Yellow
    pause
    Exit 1
}
```

**Почему:** Лучше остановиться сразу, чем получить 20 ошибок "Access Denied".

---

### Правило 2: Проверка прав администратора

**Правило:** В начале скрипта проверить права.

```powershell
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[X] Запустите от имени Администратора!" -ForegroundColor Red
    pause
    Exit 1
}
```

---

### Правило 3: Fallback механизмы

**Правило:** Если основной метод не сработал — попробовать альтернативный.

**Пример (Set-Service → Registry):**
```powershell
try {
    Set-Service -Name $Svc.Name -StartupType Disabled -ErrorAction Stop
    Write-Host "[OK] Set-Service" -ForegroundColor Green
}
catch {
    # Fallback на реестр для TrustedInstaller-служб
    $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Svc.Name)"
    Set-ItemProperty -Path $RegPath -Name "Start" -Value 4 -Type DWord -Force
    Write-Host "[OK] Registry Fallback" -ForegroundColor Green
}
```

**Почему:** Некоторые службы защищены TrustedInstaller и не поддаются `Set-Service`.

---

## 📝 ПРАВИЛА ЛОГИРОВАНИЯ

### Правило 1: Структурированный лог

**Правило:** Каждая запись содержит timestamp, уровень, сообщение.

```powershell
function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    Write-Host $logEntry -ForegroundColor $Color
}
```

**Уровни:**
- `[+]` — успех (зелёный)
- `[!]` — предупреждение (жёлтый)
- `[X]` — ошибка (красный)
- `[~]` — пропущено (серый)

---

### Правило 2: Верификация как Dashboard

**Правило:** Файл верификации показывает таблицу: Ожидалось | Фактически | Статус.

```powershell
function Show-Status {
    param($Name, $Expected, $Actual, $Status)
    if ($Status -eq 'OK') { 
        Write-Host "[OK]   $Name" -ForegroundColor Green 
    } else { 
        Write-Host "[FAIL] $Name (Ожидалось: $Expected | Факт: $Actual)" -ForegroundColor Red 
    }
}
```

**Почему:** Инженер сразу видит, что не так, без чтения логов.

---

## 🔄 ПРАВИЛА ОТКАТА

### Правило 1: Снапшот перед изменениями

**Правило:** Сохранить исходное состояние ДО любых модификаций.

```powershell
$Snapshot = @{
    Services = @()
    Registry = @()
}

foreach ($Svc in $Config.Services) {
    $ServiceObj = Get-Service -Name $Svc.Name
    $Snapshot.Services += @{
        Name = $Svc.Name
        OriginalStartType = $ServiceObj.StartType.ToString()
        Method = $Svc.Method
    }
}

$Snapshot | ConvertTo-Json -Depth 10 | Out-File "State_Backup.json" -Encoding UTF8
```

---

### Правило 2: Восстановление с учётом типа

**Правило:** При откате реестра сохранять тип значения (DWord/String).

```powershell
# В бэкапе
@{
    Path = "HKLM:\...\Path"
    Name = "ValueName"
    OriginalValue = 1
    Type = "DWord"
}

# При восстановлении
$RegType = if ($Value.Type -eq "DWord") { [Microsoft.Win32.RegistryValueKind]::DWord } else { [Microsoft.Win32.RegistryValueKind]::String }
Set-ItemProperty -Path $Value.Path -Name $Value.Name -Value $Value.OriginalValue -Type $RegType
```

**Антипаттерн:** Восстановление без типа → создаётся строка вместо DWord → система не читает значение.

---

## 🧪 ПРАВИЛА ТЕСТИРОВАНИЯ

### Правило 1: Пошаговая верификация

**Правило:** После каждого блока действий — проверка.

**Структура:**
1. Apply.ps1 → применяет изменения
2. Verify.ps1 → проверяет результат
3. Если FAIL → исправить → повторить Apply

---

### Правило 2: Чек-лист готовности

**Правило:** В конце каждого блока — чек-лист.

```markdown
- [ ] Tamper Protection отключен
- [ ] Все службы Stopped
- [ ] Ключи реестра применены
- [ ] Verify.ps1 показал 0 FAIL
```

---

##  АРХИТЕКТУРА ПРОЕКТА

### Стандартная структура папки:

```
Block03A/
├── Config.psd1          # Конфигурация (UTF-8 с BOM)
── Apply.ps1            # Движок применения (UTF-8 с BOM)
├── Verify.ps1           # Dashboard верификации (UTF-8 с BOM)
├── Rollback.ps1         # Откат изменений (UTF-8 с BOM)
├── Recode.ps1           # Перекодировщик файлов (UTF-8 с BOM)
├── State_Backup.json    # Снапшот (создаётся автоматически)
└── block_log.txt        # Лог операций (создаётся автоматически)
```

---

## ⚠️ АНТИПАТТЕРНЫ

### Антипаттерн 1: JSON для конфигурации PowerShell

**Почему плохо:** Нет комментариев, нельзя закомментировать блок.

**Решение:** Использовать `.psd1`.

---

### Антипаттерн 2: Жёстко закодированные значения

**Плохо:**
```powershell
Set-Service -Name wuauserv -StartupType Disabled
Set-Service -Name UsoSvc -StartupType Disabled
# ... ещё 20 служб
```

**Хорошо:**
```powershell
$Config = Import-PowerShellDataFile "Config.psd1"
foreach ($Svc in $Config.Services) {
    Set-Service -Name $Svc.Name -StartupType $Svc.State
}
```

---

### Антипаттерн 3: Игнорирование ошибок

**Плохо:**
```powershell
Set-Service -Name wuauserv -StartupType Disabled -ErrorAction SilentlyContinue
```

**Хорошо:**
```powershell
try {
    Set-Service -Name wuauserv -StartupType Disabled -ErrorAction Stop
}
catch {
    Write-Log "[X] wuauserv: $($_.Exception.Message)" "Red"
    # Fallback
}
```

---

### Антипаттерн 4: Отсутствие Pre-Flight проверок

**Плохо:** Скрипт падает с 20 ошибками "Access Denied".

**Хорошо:** Скрипт проверяет Tamper Protection в начале и останавливается с понятным сообщением.

---

## 🎓 ПЕРЕДАЧА КОНТЕКСТА LLM

### Как использовать этот мануал:

1. **При создании нового блока:** Скопировать структуру Apply/Verify/Rollback из Блока 03A.
2. **При добавлении службы:** Добавить строку в `Config.psd1`, не трогая код.
3. **При ошибке кодировки:** Запустить `Recode.ps1` для перекодировки в UTF-8 с BOM.
4. **При откате:** Запустить `Rollback.ps1` для восстановления из `State_Backup.json`.

---

## ✅ ЧЕК-ЛИСТ КАЧЕСТВА СКРИПТА

- [ ] Файл сохранён в UTF-8 с BOM
- [ ] Есть проверка прав администратора
- [ ] Есть Pre-Flight проверки (Tamper Protection, зависимости)
- [ ] Используется универсальное определение `$ScriptPath`
- [ ] Все переменные перед `:` обернуты в `${}`
- [ ] Есть Fallback механизмы для TrustedInstaller
- [ ] Создаётся снапшот перед изменениями
- [ ] Есть функция логирования с timestamp
- [ ] Verify.ps1 показывает таблицу статусов
- [ ] Rollback.ps1 восстанавливает с учётом типов реестра
- [ ] Запуск через `powershell -ExecutionPolicy Bypass -File`

---

**МАНУАЛ ЗАВЕРШЁН.** Все правила проверены на реальном опыте разработки Блока 03A.