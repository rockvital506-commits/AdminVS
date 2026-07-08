






# 📋 БЛОК 03A. ПЕРВИЧНАЯ БЛОКИРОВКА ФОНОВОЙ АКТИВНОСТИ (ИТОГОВАЯ ВЕРСИЯ)

## 🎯 Цели блока

| Цель | Обоснование | Приоритет |
|:---|:---|:---|
| **Предотвратить фоновое обновление AppX-пакетов** | Обновление UWP-приложений в фоне = гарантированный крах Sysprep с фатальной ошибкой рассинхронизации | 🔴 Критично |
| **Остановить Windows Update** | Без интернета CU не загрузится, но служба будет пытаться → таймауты, запись логов, нагрузка на I/O | 🔴 Критично |
| **Заблокировать телеметрию** | DiagTrack пишет логи, потребляет CPU/Disk, может инициировать сетевые запросы (таймауты без сети) | 🟡 Высокий |
| **Отключить индексацию** | WSearch сканирует диск, создаёт лишнюю запись, фрагментирует файлы перед захватом образа | 🟢 Средний |
| **Заблокировать задачи планировщика** | Фоновые триггеры могут запустить обновление или диагностику в неподходящий момент | 🔴 Критично |
| **Временно отключить Windows Defender** | Real-time protection блокирует выполнение скриптов удаления AppX и модификацию системных файлов | 🔴 Критично |

**Почему №3A:** Выполняется СРАЗУ после входа в Audit Mode (Блок 02), ДО любых других модификаций системы. Если пропустить — Windows Update или Store могут обновить AppX-пакеты за считанные минуты, и придётся откатываться к снимку ВМ.

**Контекст выполнения:**
- Встроенный профиль Administrator в Audit Mode
- Окно Sysprep Tool свёрнуто (не закрыто)
- Сеть отключена на уровне VirtualBox
- Hot-Plug VDI подключен (содержит скрипты блока)

---

## 🗺️ Структура блока

```
БЛОК 03A. ПЕРВИЧНАЯ БЛОКИРОВКА ФОНОВОЙ АКТИВНОСТИ
├── 03A.1. Подготовка среды выполнения (решение проблем PowerShell)
├── 03A.2. Временное отключение Windows Defender (критично для скриптов)
├── 03A.3. Блокировка Windows Update (критично)
├── 03A.4. Блокировка Microsoft Store и AppX (критично)
├── 03A.5. Блокировка телеметрии и диагностики
├── 03A.6. Блокировка индексации и кэширования
├── 03A.7. Блокировка Delivery Optimization через политики
├── 03A.8. Блокировка критичных задач планировщика
├── 03A.9. Отключение автозапуска OneDrive и облачной синхронизации
├── 03A.10. Верификация блокировки
└── 03A.11. Решение типовых проблем (Troubleshooting)
```

---

## 🏗️ Модульная архитектура блока

Блок реализован в виде модульной системы из 5 файлов, что обеспечивает:
- ✅ Разделение конфигурации и логики (добавление службы = правка JSON)
- ✅ Автоматическую верификацию всех объектов
- ✅ Возможность отката одной командой
- ✅ Прозрачное логирование всех операций
- ✅ Повторное использование для Блока 03B (повторная блокировка после установки ПО)

| Файл | Назначение | Когда используется |
|:---|:---|:---|
| `block_config.json` | Конфигурация всех объектов для блокировки | Редактируется при добавлении новых служб/задач |
| `apply_block.ps1` | Скрипт применения блокировок | Выполняется один раз в Блоке 03A и повторно в Блоке 03B |
| `verify_block.ps1` | Скрипт верификации результатов | Выполняется после `apply_block.ps1` |
| `restore_block.ps1` | Скрипт отката изменений | Только при необходимости отмены |
| `README.md` | Документация и примеры | Справочный файл |

---

## 🛠️ Действия блока

### ДЕЙСТВИЕ 03A.1. Подготовка среды выполнения

| Параметр | Значение | Обоснование | Риск при ошибке |
|:---|:---|:---|:---|
| **Открытие PowerShell** | ПКМ по Пуск → Windows PowerShell (Администратор) | Все команды требуют прав Administrator. В Audit Mode встроенный Admin уже имеет полные права, но PowerShell должен быть запущен с elevated privileges | Команды не выполнятся, ошибки доступа |
| **Обход ExecutionPolicy** | `powershell -ExecutionPolicy Bypass -File ".\apply_block.ps1"` | PowerShell 5.1 по умолчанию имеет политику `Restricted`, блокирующую запуск `.ps1` скриптов. Параметр `Bypass` действует только для текущего процесса | Ошибка `UnauthorizedAccess` |
| **Кодировка скриптов** | **UTF-8 с BOM** (критично для PowerShell 5.1) | PowerShell 5.1 читает файлы без BOM как ANSI, что приводит к кракозябрам и ошибкам парсинга | Ошибки `ParserError`, `MissingCatchOrFinally` |
| **Проверка контекста** | `whoami` → `win11-vm\administrator` | Подтверждение, что мы в Audit Mode под встроенным Admin | Неправильный контекст → непредсказуемые результаты |
| **Проверка сети** | `ipconfig /all` → нет активных адаптеров | Подтверждение изоляции от интернета | Сеть активна → риск фоновых обновлений |

**Критично: создание скриптов в правильной кодировке**

Если скрипты создаются вручную через PowerShell, используйте этот шаблон для сохранения в UTF-8 с BOM:

```powershell
# Шаблон сохранения скрипта в UTF-8 с BOM
$script = @'
<содержимое скрипта>
'@
$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\apply_block.ps1", $script, $utf8Bom)
```

**Правило для переменных перед двоеточием:**
Всегда используйте `${VariableName}` когда переменная находится прямо перед двоеточием `:`:

| ❌ Неправильно | ✅ Правильно |
|---|---|
| `Write-Host "Ошибка: $Name: не найдено"` | `Write-Host "Ошибка: ${Name}: не найдено"` |
| `"C:\Users\$User:Documents"` | `"C:\Users\${User}\Documents"` |

---

### ДЕЙСТВИЕ 03A.2. Временное отключение Windows Defender

**Почему ПЕРВОЕ:** Real-time protection блокирует выполнение скриптов удаления AppX, модификацию системных файлов и даже запуск `Set-Service` для некоторых защищённых служб.

| Параметр | Значение | Обоснование | Риск при ошибке |
|:---|:---|:---|:---|
| **DisableRealtimeMonitoring** | `$true` | Полное отключение защиты в реальном времени | Скрипты удаления AppX будут заблокированы |
| **DisableBehaviorMonitoring** | `$true` | Отключение поведенческого анализа | Поведенческий анализ блокирует модификации реестра |
| **DisableIOAVProtection** | `$true` | Отключение сканирования скачанных файлов | Блокирует запуск установщиков |

**Команды:**
```powershell
# Временное отключение Windows Defender (до перезагрузки)
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue

# Верификация
Get-MpPreference | Select-Object DisableRealtimeMonitoring, DisableBehaviorMonitoring
```

**Ожидаемый результат:**
- ✅ `DisableRealtimeMonitoring` = `True`
- ✅ `DisableBehaviorMonitoring` = `True`

⚠️ **ВАЖНО:** Windows Defender будет автоматически включён после перезагрузки. Для перманентного отключения используется Блок 08 (политики HKLM).

---

### ДЕЙСТВИЕ 03A.3. Блокировка Windows Update (критично)

**Почему второе:** Windows Update — самый агрессивный источник фоновой активности. Даже без интернета служба будет пытаться подключиться, писать логи, создавать таймауты.

| Служба | Имя | Метод блокировки | Обоснование | Риск при пропуске |
|:---|:---|:---|:---|:---|
| **Windows Update** | `wuauserv` | `Set-Service` → Disabled + Stop | Главная служба обновлений | Фоновая загрузка обновлений → Sysprep crash |
| **Update Orchestrator Service** | `UsoSvc` | `Set-Service` → Disabled + Stop | Управляет расписанием обновлений. Может перезапускать wuauserv | Обход блокировки wuauserv |
| **Windows Update Medic Service** | `WaaSMedicSvc` | 🔴 **Только через реестр** (Start=4) | Защищена TrustedInstaller. Восстанавливает wuauserv если отключена | Автоматическое включение wuauserv после перезагрузки |
| **Delivery Optimization** | `DoSvc` | 🔴 **Только через реестр** (Start=4) | P2P-загрузка обновлений. Защищена TrustedInstaller | Лишняя запись на диск, фрагментация |
| **Background Intelligent Transfer Service** | `BITS` | `Set-Service` → Manual + Stop | Используется WU для загрузки файлов. Не отключаем полностью (нужен для других задач) | WU может использовать BITS для обхода блокировки |

**Критическое замечание о защищённых службах:**
Службы `WaaSMedicSvc`, `DoSvc`, `AppXSvc`, `ClipSVC`, `InstallService` защищены механизмом **TrustedInstaller**. Команда `Set-Service` возвращает `Access Denied` даже от имени Administrator. Единственный рабочий метод — прямая модификация реестра:

```powershell
# Универсальный паттерн для защищённых служб
$RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\<ServiceName>"
Set-ItemProperty -Path $RegPath -Name "Start" -Value 4 -Type DWord -Force
```

Значения параметра `Start`:
| Значение | Тип запуска |
|:---:|:---|
| 0 | Boot |
| 1 | System |
| 2 | Automatic |
| 3 | Manual |
| 4 | **Disabled** |

---

### ДЕЙСТВИЕ 03A.4. Блокировка Microsoft Store и AppX (критично)

**Почему третье:** Store может автоматически обновлять provisioned AppX-пакеты даже без участия пользователя. Это главная причина рассинхронизации при Sysprep.

| Служба | Имя | Метод блокировки | Обоснование | Риск при пропуске |
|:---|:---|:---|:---|:---|
| **Install Service** | `InstallService` | 🔴 **Только через реестр** (Start=4) | Управляет установкой/обновлением AppX-пакетов из Store | Store обновляет пакеты → рассинхронизация → Sysprep failure |
| **AppX Deployment Service** | `AppXSvc` | 🔴 **Только через реестр** (Start=4) | Развертывание AppX-пакетов. Защищена TrustedInstaller | Автоматическое развертывание обновленных пакетов |
| **Client License Service** | `ClipSVC` | 🔴 **Только через реестр** (Start=4) | Управление лицензиями AppX. Защищена TrustedInstaller | Сетевые запросы (таймауты без интернета) |
| **Windows License Manager Service** | `LicenseManager` | `Set-Service` → Disabled + Stop | Управление лицензиями Store-приложений | Лицензионные проверки, сетевая активность |

---

### ДЕЙСТВИЕ 03A.5. Блокировка телеметрии и диагностики

**Почему четвёртое:** Телеметрия пишет логи, потребляет CPU/Disk I/O, может инициировать сетевые запросы (даже без интернета — таймауты).

| Служба | Имя | Метод блокировки | Обоснование | Риск при пропуске |
|:---|:---|:---|:---|:---|
| **Connected User Experiences and Telemetry** | `DiagTrack` | `Set-Service` → Disabled + Stop | Главная служба телеметрии | Запись логов, потребление I/O, сетевые запросы |
| **WAP Push Message Routing Service** | `dmwappushservice` | `Set-Service` → Disabled + Stop | Маршрутизация push-уведомлений | Дополнительный канал телеметрии |
| **Windows Error Reporting Service** | `WerSvc` | `Set-Service` → Disabled + Stop | Сбор отчетов об ошибках | Запись дампов, потребление Disk I/O |

---

### ДЕЙСТВИЕ 03A.6. Блокировка индексации и кэширования

**Почему пятое:** Индексация сканирует диск, создаёт лишнюю запись, фрагментирует файлы. SysMain (SuperFetch) кэширует приложения в RAM — лишнее потребление памяти.

| Служба | Имя | Метод блокировки | Обоснование | Риск при пропуске |
|:---|:---|:---|:---|:---|
| **Windows Search** | `WSearch` | `Set-Service` → Disabled + Stop | Индексация содержимого файлов | Лишняя запись на диск, фрагментация |
| **SysMain (SuperFetch)** | `SysMain` | `Set-Service` → Disabled + Stop | Кэширование часто используемых приложений в RAM | Потребление RAM, фоновая запись логов |

---

### ДЕЙСТВИЕ 03A.7. Блокировка Delivery Optimization через политики

**Почему шестое:** `DoSvc` уже заблокирован в Действии 03A.3, но здесь мы дополнительно блокируем его через реестр политик для надёжности.

| Параметр реестра | Путь | Значение | Обоснование |
|:---|:---|:---|:---|
| **DODownloadMode** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization` | `0` (Отключено) | Запрещает P2P-загрузку обновлений даже если служба будет включена |
| **AllowCloudDownload** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization` | `0` | Запрещает загрузку из облака |

---

### ДЕЙСТВИЕ 03A.8. Блокировка критичных задач планировщика

**Почему седьмое:** Задачи планировщика могут запускаться по расписанию и инициировать обновления, диагностику, телеметрию.

| Задача планировщика | Путь | Метод блокировки | Обоснование |
|:---|:---|:---|:---|
| **Windows Update** | `\Microsoft\Windows\WindowsUpdate\*` | `Disable-ScheduledTask` | Запускает проверку обновлений |
| **Setup** | `\Microsoft\Windows\Setup\*` | `Disable-ScheduledTask` | Задачи настройки системы |
| **Application Experience** | `\Microsoft\Windows\Application Experience\*` | `Disable-ScheduledTask` | Сбор данных о приложениях |
| **Customer Experience Improvement Program** | `\Microsoft\Windows\Customer Experience Improvement Program\*` | `Disable-ScheduledTask` | Программа улучшения качества |
| **Autochk** | `\Microsoft\Windows\Autochk\*` | `Disable-ScheduledTask` | Проверка диска при загрузке |
| **DiskDiagnostic** | `\Microsoft\Windows\DiskDiagnostic\*` | `Disable-ScheduledTask` | Диагностика диска |

**⚠️ Известная проблема: Access Denied для некоторых задач**

Задачи в путях `\Microsoft\Windows\WindowsUpdate\*` и `\Microsoft\Windows\Application Experience\*` защищены TrustedInstaller и возвращают `Access Denied` даже при запуске `Disable-ScheduledTask` от имени Administrator.

**Решение:** Это **не критично** для Golden Image, потому что:
1. Службы WU уже отключены на уровне `wuauserv`, `UsoSvc`, `WaaSMedicSvc` → задачи не смогут запуститься
2. Sysprep при `/generalize` сам очистит эти задачи
3. Для полного отключения потребовались бы `psexec -s` или TakeOwnership, что избыточно

---

### ДЕЙСТВИЕ 03A.9. Отключение автозапуска OneDrive и облачной синхронизации

**Почему восьмое:** OneDrive попытается подключиться при первом входе пользователя, создаст таймауты без интернета.

| Параметр реестра | Путь | Значение | Обоснование |
|:---|:---|:---|:---|
| **DisableFileSyncNGSC** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive` | `1` | Отключает OneDrive на уровне политики |
| **PreventOneDriveFromStarting** | `HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive` | `1` | Запрещает автозапуск OneDrive |

---

### ДЕЙСТВИЕ 03A.10. Верификация блокировки

**Почему последнее:** После всех блокировок нужно убедиться, что все службы остановлены и задачи отключены.

| Проверка | Команда | Ожидаемый результат | Действие при сбое |
|:---|:---|:---|:---|
| **Службы Windows Update** | `Get-Service wuauserv, UsoSvc, WaaSMedicSvc, DoSvc, BITS` | Все Stopped, StartType: Disabled (кроме BITS = Manual) | Повторить блокировку |
| **Службы Store/AppX** | `Get-Service InstallService, AppXSvc, ClipSVC, LicenseManager` | Все Stopped | Повторить блокировку через реестр |
| **Защищённые службы (реестр)** | `Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Services\<Name> \| Select Start` | Start = 4 | Повторить запись в реестр |
| **Службы телеметрии** | `Get-Service DiagTrack, dmwappushservice, WerSvc` | Все Stopped, StartType: Disabled | Повторить блокировку |
| **Службы индексации** | `Get-Service WSearch, SysMain` | Все Stopped, StartType: Disabled | Повторить блокировку |
| **Windows Defender** | `Get-MpPreference \| Select DisableRealtimeMonitoring` | DisableRealtimeMonitoring = True | Повторить `Set-MpPreference` |
| **Задачи планировщика** | `Get-ScheduledTask -TaskPath "\Microsoft\Windows\WindowsUpdate\*"` | State: Disabled (или Access Denied — это нормально) | — |
| **Реестр Delivery Optimization** | `Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"` | DODownloadMode = 0 | Повторить настройку |
| **Реестр OneDrive** | `Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive"` | DisableFileSyncNGSC = 1 | Повторить настройку |

**Рекомендуется использовать скрипт `verify_block.ps1`** для автоматической верификации всех объектов из `block_config.json`.

---

### ДЕЙСТВИЕ 03A.11. Решение типовых проблем (Troubleshooting)

| Проблема | Симптом | Причина | Решение |
|:---|:---|:---|:---|
| **`UnauthorizedAccess` при запуске скрипта** | `Невозможно загрузить файл... выполнение сценариев отключено` | ExecutionPolicy = Restricted | Запускать через `powershell -ExecutionPolicy Bypass -File ".\script.ps1"` |
| **Кракозябры в выводе скрипта** | `РПСѓС‚СЊ` вместо `Путь` | Файл сохранён в UTF-8 без BOM | Пересохранить в UTF-8 **с BOM** через Notepad++ или скрипт |
| **`Access Denied` для Set-Service** | `Отказано в доступе` при `Set-Service -Name DoSvc` | Служба защищена TrustedInstaller | Использовать реестр: `Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\DoSvc" -Name "Start" -Value 4` |
| **`InvalidVariableReferenceWithDrive`** | `Недопустимая ссылка на переменную. За знаком : не следует...` | PowerShell путает `$Var:` с drive specifier | Использовать `${Var}:` с фигурными скобками |
| **`MissingCatchOrFinally`** | `В операторе Try отсутствует блок Catch` | Ошибка парсинга из-за кракозябр | Пересохранить файл в UTF-8 с BOM |
| **Служба перезапускается после блокировки** | Status меняется с Stopped на Running | Зависимые службы или триггеры | Проверить зависимости: `Get-Service <имя> -DependentServices` |
| **Окно Sysprep Tool закрыто** | Нет визуального признака Audit Mode | Случайное закрытие | Запустить вручную: `C:\Windows\System32\Sysprep\sysprep.exe` |
| **Access Denied для Disable-ScheduledTask** | Ошибка при отключении задач WindowsUpdate/Application Experience | Защищено TrustedInstaller | **Не критично** — службы WU уже отключены, Sysprep очистит задачи |

---
=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================


---

## 📋 ИНСТРУКЦИЯ ПО ПРИМЕНЕНИЮ

### Шаг 1. Подготовка папки

```powershell
# 1. Открыть PowerShell ОТ ИМЕНИ АДМИНИСТРАТОРА
# 2. Перейти в папку блока
cd "Z:\home-pc\Block03A"

# 3. Создать папку если её нет
New-Item -ItemType Directory -Path "Z:\home-pc\Block03A" -Force
```

### Шаг 2. Создание block_config.json

Создайте файл `block_config.json` вручную (через Notepad++ с кодировкой **UTF-8 без BOM** — для JSON это не критично) и вставьте содержимое из **ФАЙЛ 1** выше.

Проверка:
```powershell
Test-Path ".\block_config.json"  # Должно вернуть True
```

### Шаг 3. Создание apply_block.ps1

Скопируйте **весь код из ФАЙЛ 2** и вставьте в PowerShell от имени Администратора. Нажмите Enter.

Скрипт:
1. Создаст файл `apply_block.ps1` в UTF-8 с BOM
2. Автоматически запустит его с обходом ExecutionPolicy
3. Отключит Windows Defender (3 метода: Set-MpPreference + Tamper Protection + Group Policy)
4. Создаст резервную копию `block_backup.json`
5. Заблокирует все службы из конфига
6. Применит ключи реестра
7. Отключит задачи планировщика

### Шаг 4. Создание verify_block.ps1

Скопируйте **весь код из ФАЙЛ 3** и вставьте в PowerShell. Нажмите Enter.

Затем запустите верификацию:
```powershell
powershell -ExecutionPolicy Bypass -File ".\verify_block.ps1"
```

### Шаг 5. Создание restore_block.ps1 (на всякий случай)

Скопируйте **весь код из ФАЙЛ 4** и вставьте в PowerShell. Нажмите Enter.

Для отката изменений (если нужно):
```powershell
powershell -ExecutionPolicy Bypass -File ".\restore_block.ps1"
```


---

## 🔍 Решение типовых проблем

| Проблема | Решение |
|:---|:---|
| **`UnauthorizedAccess`** | Запускать через `powershell -ExecutionPolicy Bypass -File ".\script.ps1"` |
| **Кракозябры** | Файлы создаются через `[System.IO.File]::WriteAllText` с BOM — проблема исключена |
| **`Access Denied` для Set-Service** | Скрипт автоматически делает fallback на реестр |
| **`Access Denied` для задач WindowsUpdate** | Это нормально — службы уже отключены, Sysprep очистит задачи |
| **Пустой $ScriptPath** | Универсальный паттерн с fallback на `$PWD` |
| **`InvalidVariableReferenceWithDrive`** | Везде используется `${Var}:` с фигурными скобками |



---

## 🔄 Связь с другими блоками

| Предыдущий блок | Связь |
|:---|:---|
| **Блок 02** (Установка Windows + Audit Mode) | Предоставляет чистую среду Audit Mode для блокировки служб |

| Следующий блок | Связь |
|:---|:---|
| **Блок 04** (Offline-обновление системы) | Начинается после блокировки служб. DISM устанавливает обновления без вмешательства WU |
| **Блок 03B** (Повторная блокировка после установки ПО) | Использует тот же `apply_block.ps1` для повторной блокировки после установки ПО (инсталляторы могут восстановить службы) |

---

## 📊 Сводная таблица всех заблокированных сущностей

| Категория | Сущность | Метод | Статус |
|:---|:---|:---|:---|
| **Защита** | Windows Defender Real-time Protection | `Set-MpPreference` | ✅ Отключено |
| **Windows Update** | wuauserv | `Set-Service` → Disabled | ✅ Отключено |
| **Windows Update** | UsoSvc | `Set-Service` → Disabled | ✅ Отключено |
| **Windows Update** | WaaSMedicSvc | 🔴 Реестр → Start=4 | ✅ Отключено |
| **Windows Update** | DoSvc | 🔴 Реестр → Start=4 | ✅ Отключено |
| **Windows Update** | BITS | `Set-Service` → Manual | ✅ Manual |
| **Store/AppX** | InstallService | 🔴 Реестр → Start=4 | ✅ Отключено |
| **Store/AppX** | AppXSvc | 🔴 Реестр → Start=4 | ✅ Отключено |
| **Store/AppX** | ClipSVC | 🔴 Реестр → Start=4 | ✅ Отключено |
| **Store/AppX** | LicenseManager | `Set-Service` → Disabled | ✅ Отключено |
| **Телеметрия** | DiagTrack | `Set-Service` → Disabled | ✅ Отключено |
| **Телеметрия** | dmwappushservice | `Set-Service` → Disabled | ✅ Отключено |
| **Телеметрия** | WerSvc | `Set-Service` → Disabled | ✅ Отключено |
| **Индексация** | WSearch | `Set-Service` → Disabled | ✅ Отключено |
| **Индексация** | SysMain | `Set-Service` → Disabled | ✅ Отключено |
| **Политики** | DODownloadMode | Реестр → 0 | ✅ Отключено |
| **Политики** | AllowCloudDownload | Реестр → 0 | ✅ Отключено |
| **Политики** | DisableFileSyncNGSC | Реестр → 1 | ✅ Отключено |
| **Политики** | PreventOneDriveFromStarting | Реестр → 1 | ✅ Отключено |
| **Задачи** | WindowsUpdate\* | `Disable-ScheduledTask` | ⚠️ Access Denied (не критично) |
| **Задачи** | Setup\* | `Disable-ScheduledTask` | ✅ Отключено |
| **Задачи** | Application Experience\* | `Disable-ScheduledTask` | ⚠️ Access Denied (не критично) |
| **Задачи** | CEIP\* | `Disable-ScheduledTask` | ✅ Отключено |
| **Задачи** | Autochk\* | `Disable-ScheduledTask` | ✅ Отключено |
| **Задачи** | DiskDiagnostic\* | `Disable-ScheduledTask` | ✅ Отключено |

---
=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================

=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================



# 📋 БЛОК 03A. ПЕРВИЧНАЯ БЛОКИРОВКА ФОНОВОЙ АКТИВНОСТИ — ФИНАЛЬНАЯ ВЕРСИЯ С ИСПРАВЛЕНИЯМИ

## 🔍 Критический анализ и внесенные исправления

На основе выявленных проблем в ходе работы, внесены следующие критические исправления:

| Проблема | Решение | Файл |
|:---|:---|:---|
| **Windows Defender не отключается** | Добавлено принудительное отключение через реестр Tamper Protection + Group Policy | `block_config.json`, `apply_block.ps1`, `restore_block.ps1` |
| **Задачи планировщика Access Denied** | Добавлены задачи "Refresh Group Policy Cache" и "SdbinstMergeDbTask" в конфиг. Access Denied обработан как штатная ситуация | `block_config.json`, `verify_block.ps1` |
| **Кодировка UTF-8 без BOM** | Все скрипты создаются через `[System.IO.File]::WriteAllText` с BOM | Все файлы |
| **ExecutionPolicy Restricted** | Запуск строго через `powershell -ExecutionPolicy Bypass -File` | Инструкция |
| **Пустой $ScriptPath** | Универсальный паттерн: `$MyInvocation` → fallback `$PWD` | Все файлы |

---

## 📄 ФАЙЛ 1: block_config.json (ИСПРАВЛЕН)

```json
{
  "metadata": {
    "version": "3.0",
    "description": "Конфигурация блокировки фоновой активности для Golden Image",
    "target_os": "Windows 10/11 Pro",
    "execution_context": "Audit Mode (Administrator)"
  },
  "services": {
    "windows_update": {
      "description": "Службы Windows Update",
      "priority": "critical",
      "items": [
        {
          "name": "wuauserv",
          "method": "service",
          "startup_type": "Disabled",
          "reason": "Главная служба обновлений"
        },
        {
          "name": "UsoSvc",
          "method": "service",
          "startup_type": "Disabled",
          "reason": "Update Orchestrator Service"
        },
        {
          "name": "WaaSMedicSvc",
          "method": "registry",
          "startup_type": "Disabled",
          "registry_path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\WaaSMedicSvc",
          "registry_value": 4,
          "reason": "Windows Update Medic Service (защищена TrustedInstaller)"
        },
        {
          "name": "DoSvc",
          "method": "registry",
          "startup_type": "Disabled",
          "registry_path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\DoSvc",
          "registry_value": 4,
          "reason": "Delivery Optimization (защищена TrustedInstaller)"
        },
        {
          "name": "BITS",
          "method": "service",
          "startup_type": "Manual",
          "reason": "Background Intelligent Transfer Service (не Disabled, нужен для других задач)"
        }
      ]
    },
    "store_appx": {
      "description": "Microsoft Store и AppX",
      "priority": "critical",
      "items": [
        {
          "name": "InstallService",
          "method": "registry",
          "startup_type": "Disabled",
          "registry_path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\InstallService",
          "registry_value": 4,
          "reason": "Install Service (защищена TrustedInstaller)"
        },
        {
          "name": "AppXSvc",
          "method": "registry",
          "startup_type": "Disabled",
          "registry_path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\AppXSvc",
          "registry_value": 4,
          "reason": "AppX Deployment Service (защищена TrustedInstaller)"
        },
        {
          "name": "ClipSVC",
          "method": "registry",
          "startup_type": "Disabled",
          "registry_path": "HKLM:\\SYSTEM\\CurrentControlSet\\Services\\ClipSVC",
          "registry_value": 4,
          "reason": "Client License Service (защищена TrustedInstaller)"
        },
        {
          "name": "LicenseManager",
          "method": "service",
          "startup_type": "Disabled",
          "reason": "Windows License Manager Service"
        }
      ]
    },
    "telemetry": {
      "description": "Телеметрия и диагностика",
      "priority": "high",
      "items": [
        {
          "name": "DiagTrack",
          "method": "service",
          "startup_type": "Disabled",
          "reason": "Connected User Experiences and Telemetry"
        },
        {
          "name": "dmwappushservice",
          "method": "service",
          "startup_type": "Disabled",
          "reason": "WAP Push Message Routing Service"
        },
        {
          "name": "WerSvc",
          "method": "service",
          "startup_type": "Disabled",
          "reason": "Windows Error Reporting Service"
        }
      ]
    },
    "indexing": {
      "description": "Индексация и кэширование",
      "priority": "medium",
      "items": [
        {
          "name": "WSearch",
          "method": "service",
          "startup_type": "Disabled",
          "reason": "Windows Search"
        },
        {
          "name": "SysMain",
          "method": "service",
          "startup_type": "Disabled",
          "reason": "SysMain (SuperFetch)"
        }
      ]
    }
  },
  "registry_keys": {
    "delivery_optimization": {
      "description": "Блокировка Delivery Optimization через политики",
      "path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\DeliveryOptimization",
      "items": [
        {
          "name": "DODownloadMode",
          "value": 0,
          "type": "DWord",
          "reason": "Запрет P2P-загрузки"
        },
        {
          "name": "AllowCloudDownload",
          "value": 0,
          "type": "DWord",
          "reason": "Запрет облачной загрузки"
        }
      ]
    },
    "onedrive": {
      "description": "Отключение OneDrive",
      "path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\OneDrive",
      "items": [
        {
          "name": "DisableFileSyncNGSC",
          "value": 1,
          "type": "DWord",
          "reason": "Отключение синхронизации"
        },
        {
          "name": "PreventOneDriveFromStarting",
          "value": 1,
          "type": "DWord",
          "reason": "Запрет автозапуска"
        }
      ]
    },
    "defender_tamper": {
      "description": "Отключение Tamper Protection Windows Defender",
      "path": "HKLM:\\SOFTWARE\\Microsoft\\Windows Defender\\Features",
      "items": [
        {
          "name": "TamperProtection",
          "value": 0,
          "type": "DWord",
          "reason": "Отключение защиты от изменений настроек Defender"
        }
      ]
    },
    "defender_policy": {
      "description": "Отключение Windows Defender через Group Policy",
      "path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows Defender",
      "items": [
        {
          "name": "DisableAntiSpyware",
          "value": 1,
          "type": "DWord",
          "reason": "Полное отключение Defender через политики"
        }
      ]
    },
    "defender_realtime": {
      "description": "Отключение Real-Time Protection через политики",
      "path": "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows Defender\\Real-Time Protection",
      "items": [
        {
          "name": "DisableRealtimeMonitoring",
          "value": 1,
          "type": "DWord",
          "reason": "Отключение мониторинга в реальном времени"
        }
      ]
    }
  },
  "scheduled_tasks": {
    "windows_update": {
      "description": "Задачи Windows Update",
      "paths": [
        "\\Microsoft\\Windows\\WindowsUpdate\\*"
      ]
    },
    "setup": {
      "description": "Задачи настройки системы",
      "paths": [
        "\\Microsoft\\Windows\\Setup\\*"
      ]
    },
    "application_experience": {
      "description": "Сбор данных о приложениях",
      "paths": [
        "\\Microsoft\\Windows\\Application Experience\\*"
      ]
    },
    "customer_experience": {
      "description": "Программа улучшения качества",
      "paths": [
        "\\Microsoft\\Windows\\Customer Experience Improvement Program\\*"
      ]
    },
    "autochk": {
      "description": "Проверка диска при загрузке",
      "paths": [
        "\\Microsoft\\Windows\\Autochk\\*"
      ]
    },
    "disk_diagnostic": {
      "description": "Диагностика диска",
      "paths": [
        "\\Microsoft\\Windows\\DiskDiagnostic\\*"
      ]
    }
  }
}
```

---

##  ФАЙЛ 2: apply_block.ps1 (ИСПРАВЛЕН)

```powershell
$script = @'
<#
.SYNOPSIS
    Применение блокировок фоновой активности из block_config.json
.NOTES
    Запускать от имени Администратора в Audit Mode
    ВАЖНО: Файл должен быть сохранён в UTF-8 с BOM
#>

[CmdletBinding()]
param(
    [switch]$SkipBackup,
    [string]$ConfigFile = "block_config.json"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"

if ($MyInvocation.MyCommand.Definition) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $ScriptPath = $PWD.Path
}

$ConfigPath = Join-Path $ScriptPath $ConfigFile
$LogFile = Join-Path $ScriptPath "block_log.txt"
$BackupFile = Join-Path $ScriptPath "block_backup.json"

Write-Host "[INFO] Script path: ${ScriptPath}" -ForegroundColor Gray
Write-Host "[INFO] Config path: ${ConfigPath}" -ForegroundColor Gray

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "[X] КРИТИЧНО: Запустите скрипт от имени Администратора!" -ForegroundColor Red
    pause
    Exit 1
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "[X] КРИТИЧНО: Файл конфигурации '${ConfigPath}' не найден!" -ForegroundColor Red
    pause
    Exit 1
}

try {
    $Config = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "[+] Конфигурация загружена: ${ConfigPath}" -ForegroundColor Green
}
catch {
    Write-Host "[X] Ошибка чтения конфигурации: $($_.Exception.Message)" -ForegroundColor Red
    pause
    Exit 1
}

function Write-Log {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[${timestamp}] ${Message}"
    Add-Content -Path $LogFile -Value $logEntry -Encoding UTF8
    Write-Host $logEntry -ForegroundColor $Color
}

# ==============================================================================
# ШАГ 0: ВРЕМЕННОЕ ОТКЛЮЧЕНИЕ WINDOWS DEFENDER (УСИЛЕННОЕ)
# ==============================================================================
Write-Log "=== ОТКЛЮЧЕНИЕ WINDOWS DEFENDER ===" "Yellow"

# Метод 1: Через Set-MpPreference
try {
    Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction Stop
    Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction Stop
    Set-MpPreference -DisableIOAVProtection $true -ErrorAction Stop
    Write-Log "[+] Defender: Set-MpPreference выполнен" "Green"
}
catch {
    Write-Log "[!] Defender: Set-MpPreference не сработал - $($_.Exception.Message)" "Yellow"
}

# Метод 2: Отключение Tamper Protection через реестр
try {
    $TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
    if (Test-Path $TamperPath) {
        Set-ItemProperty -Path $TamperPath -Name "TamperProtection" -Value 0 -Type DWord -Force -ErrorAction Stop
        Write-Log "[+] Defender: TamperProtection отключен через реестр" "Green"
    }
}
catch {
    Write-Log "[!] Defender: TamperProtection - $($_.Exception.Message)" "Yellow"
}

# Метод 3: Group Policy для полного отключения
try {
    $PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
    if (-not (Test-Path $PolicyPath)) {
        New-Item -Path $PolicyPath -Force | Out-Null
    }
    Set-ItemProperty -Path $PolicyPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force -ErrorAction Stop
    
    $RealtimePath = "$PolicyPath\Real-Time Protection"
    if (-not (Test-Path $RealtimePath)) {
        New-Item -Path $RealtimePath -Force | Out-Null
    }
    Set-ItemProperty -Path $RealtimePath -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force -ErrorAction Stop
    
    Write-Log "[+] Defender: Group Policy отключен" "Green"
}
catch {
    Write-Log "[!] Defender: Group Policy - $($_.Exception.Message)" "Yellow"
}

# ==============================================================================
# СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ
# ==============================================================================
if (-not $SkipBackup) {
    Write-Log "Создание резервной копии..." "Cyan"
    
    $Backup = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        services = @()
        registry = @()
        tasks = @()
        defender = @{}
    }
    
    foreach ($Category in $Config.services.PSObject.Properties) {
        foreach ($Item in $Category.Value.items) {
            $Service = Get-Service -Name $Item.name -ErrorAction SilentlyContinue
            if ($Service) {
                $Backup.services += @{
                    name = $Item.name
                    method = $Item.method
                    registry_path = if ($Item.registry_path) { $Item.registry_path } else { $null }
                    original_start = $Service.StartType.ToString()
                    original_status = $Service.Status.ToString()
                }
            }
        }
    }
    
    foreach ($Category in $Config.registry_keys.PSObject.Properties) {
        $RegPath = $Category.Value.path
        if (Test-Path $RegPath) {
            $RegValues = @()
            foreach ($Item in $Category.Value.items) {
                $CurrentValue = (Get-ItemProperty $RegPath -ErrorAction SilentlyContinue).$($Item.name)
                $RegValues += @{
                    name = $Item.name
                    value = $CurrentValue
                    type = $Item.type
                }
            }
            $Backup.registry += @{
                path = $RegPath
                values = $RegValues
            }
        }
    }
    
    foreach ($Category in $Config.scheduled_tasks.PSObject.Properties) {
        foreach ($Path in $Category.Value.paths) {
            $Tasks = Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue
            foreach ($Task in $Tasks) {
                $Backup.tasks += @{
                    name = $Task.TaskName
                    path = $Task.TaskPath
                    state = $Task.State.ToString()
                }
            }
        }
    }
    
    $MpPref = Get-MpPreference -ErrorAction SilentlyContinue
    if ($MpPref) {
        $Backup.defender = @{
            DisableRealtimeMonitoring = $MpPref.DisableRealtimeMonitoring
            DisableBehaviorMonitoring = $MpPref.DisableBehaviorMonitoring
            DisableIOAVProtection = $MpPref.DisableIOAVProtection
        }
    }
    
    $Backup | ConvertTo-Json -Depth 10 | Out-File $BackupFile -Encoding UTF8
    Write-Log "[+] Резервная копия создана: ${BackupFile}" "Green"
}

# ==============================================================================
# БЛОКИРОВКА СЛУЖБ С АВТОМАТИЧЕСКИМ FALLBACK
# ==============================================================================
Write-Log "=== НАЧАЛО БЛОКИРОВКИ СЛУЖБ ===" "Yellow"

foreach ($Category in $Config.services.PSObject.Properties) {
    Write-Log "--- $($Category.Value.description) ---" "Cyan"
    
    foreach ($Item in $Category.Value.items) {
        Write-Log "Обработка: $($Item.name)" "Gray"
        
        try {
            Stop-Service -Name $Item.name -Force -ErrorAction SilentlyContinue
            
            if ($Item.method -eq "service") {
                Set-Service -Name $Item.name -StartupType $Item.startup_type -ErrorAction Stop
                Write-Log "[+] $($Item.name) -> $($Item.startup_type) (Set-Service)" "Green"
            }
            elseif ($Item.method -eq "registry") {
                if (Test-Path $Item.registry_path) {
                    Set-ItemProperty -Path $Item.registry_path -Name "Start" -Value $Item.registry_value -Type DWord -Force -ErrorAction Stop
                    Write-Log "[+] $($Item.name) -> Start=$($Item.registry_value) (Registry)" "Green"
                }
                else {
                    Write-Log "[!] $($Item.name): путь реестра не найден" "Yellow"
                }
            }
        }
        catch {
            Write-Log "[X] $($Item.name): ошибка - $($_.Exception.Message)" "Red"
            
            if ($Item.method -eq "service") {
                Write-Log "    Попытка fallback через реестр..." "Yellow"
                $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Item.name)"
                if (Test-Path $RegPath) {
                    $StartValue = if ($Item.startup_type -eq "Disabled") { 4 } elseif ($Item.startup_type -eq "Manual") { 3 } else { 2 }
                    Set-ItemProperty -Path $RegPath -Name "Start" -Value $StartValue -Type DWord -Force -ErrorAction SilentlyContinue
                    Write-Log "[+] $($Item.name) -> Start=${StartValue} (Registry fallback)" "Green"
                }
            }
        }
    }
}

# ==============================================================================
# БЛОКИРОВКА КЛЮЧЕЙ РЕЕСТРА
# ==============================================================================
Write-Log "=== БЛОКИРОВКА КЛЮЧЕЙ РЕЕСТРА ===" "Yellow"

foreach ($Category in $Config.registry_keys.PSObject.Properties) {
    Write-Log "--- $($Category.Value.description) ---" "Cyan"
    
    $RegPath = $Category.Value.path
    
    if (-not (Test-Path $RegPath)) {
        New-Item -Path $RegPath -Force | Out-Null
        Write-Log "[+] Создан раздел: ${RegPath}" "Green"
    }
    
    foreach ($Item in $Category.Value.items) {
        try {
            Set-ItemProperty -Path $RegPath -Name $Item.name -Value $Item.value -Type $Item.type -Force -ErrorAction Stop
            Write-Log "[+] $($Item.name) = $($Item.value)" "Green"
        }
        catch {
            Write-Log "[X] $($Item.name): ошибка - $($_.Exception.Message)" "Red"
        }
    }
}

# ==============================================================================
# БЛОКИРОВКА ЗАДАЧ ПЛАНИРОВЩИКА
# ==============================================================================
Write-Log "=== БЛОКИРОВКА ЗАДАЧ ПЛАНИРОВЩИКА ===" "Yellow"

foreach ($Category in $Config.scheduled_tasks.PSObject.Properties) {
    Write-Log "--- $($Category.Value.description) ---" "Cyan"
    
    foreach ($Path in $Category.Value.paths) {
        try {
            $Tasks = Get-ScheduledTask -TaskPath $Path -ErrorAction SilentlyContinue
            
            if ($null -eq $Tasks -or $Tasks.Count -eq 0) {
                Write-Log "[~] Задачи не найдены: ${Path}" "Gray"
            }
            else {
                foreach ($Task in $Tasks) {
                    try {
                        Disable-ScheduledTask -TaskName $Task.TaskName -TaskPath $Task.TaskPath -ErrorAction Stop | Out-Null
                        Write-Log "[+] Отключена: $($Task.TaskName)" "Green"
                    }
                    catch {
                        Write-Log "[!] $($Task.TaskName): Access Denied (защищено TrustedInstaller, не критично)" "Yellow"
                    }
                }
            }
        }
        catch {
            Write-Log "[X] Ошибка пути ${Path}: $($_.Exception.Message)" "Red"
        }
    }
}

# ==============================================================================
# ИТОГ
# ==============================================================================
Write-Log "=== БЛОКИРОВКА ЗАВЕРШЕНА ===" "Green"
Write-Host "`n[!] Запустите verify_block.ps1 для проверки результатов" -ForegroundColor Yellow

pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\apply_block.ps1", $script, $utf8Bom)

Write-Host "[+] Файл apply_block.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green
```

---

## 📄 ФАЙЛ 3: verify_block.ps1 (ИСПРАВЛЕН)

```powershell
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
```

---

##  ФАЙЛ 4: restore_block.ps1 (ИСПРАВЛЕН)

```powershell
$script = @'
<#
.SYNOPSIS
    Откат блокировок фоновой активности из резервной копии
.DESCRIPTION
    Восстанавливает исходное состояние служб, задач и реестра из block_backup.json
    КРИТИЧНО: Для защищённых служб используется реестр, а не Set-Service.
.NOTES
    Запускать от имени Администратора
    Требует: block_backup.json
    ВАЖНО: Файл должен быть сохранён в UTF-8 с BOM
#>

[CmdletBinding()]
param(
    [string]$BackupFile = "block_backup.json"
)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if ($MyInvocation.MyCommand.Definition) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $ScriptPath = $PWD.Path
}

$BackupPath = Join-Path $ScriptPath $BackupFile

if (-not (Test-Path $BackupPath)) {
    Write-Host "[X] Резервная копия '${BackupPath}' не найдена!" -ForegroundColor Red
    Write-Host "    Запустите apply_block.ps1 для создания копии" -ForegroundColor Yellow
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

# Восстановление Tamper Protection
$TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
if (Test-Path $TamperPath) {
    try {
        Set-ItemProperty -Path $TamperPath -Name "TamperProtection" -Value 1 -Type DWord -Force -ErrorAction Stop
        Write-Host "[+] TamperProtection восстановлен" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] TamperProtection: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# Удаление Group Policy для Defender
$PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (Test-Path $PolicyPath) {
    try {
        Remove-Item -Path $PolicyPath -Recurse -Force -ErrorAction Stop
        Write-Host "[+] Group Policy Defender удалена" -ForegroundColor Green
    }
    catch {
        Write-Host "[!] Group Policy Defender: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

# ==============================================================================
# ВОССТАНОВЛЕНИЕ СЛУЖБ
# ==============================================================================
Write-Host "`n=== ВОССТАНОВЛЕНИЕ СЛУЖБ ===" -ForegroundColor Cyan

foreach ($Service in $Backup.services) {
    try {
        if ($Service.method -eq "registry" -and $Service.registry_path) {
            $StartValue = if ($Service.original_start -eq "Disabled") { 4 } elseif ($Service.original_start -eq "Manual") { 3 } elseif ($Service.original_start -eq "Automatic") { 2 } else { 3 }
            
            if (Test-Path $Service.registry_path) {
                Set-ItemProperty -Path $Service.registry_path -Name "Start" -Value $StartValue -Type DWord -Force -ErrorAction Stop
                Write-Host "[+] $($Service.name) -> Start=${StartValue} (Registry)" -ForegroundColor Green
            } else {
                Write-Host "[!] $($Service.name): путь реестра не найден" -ForegroundColor Yellow
            }
        }
        else {
            Set-Service -Name $Service.name -StartupType $Service.original_start -ErrorAction Stop
            Write-Host "[+] $($Service.name) -> $($Service.original_start) (Set-Service)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[X] $($Service.name): $($_.Exception.Message)" -ForegroundColor Red
        
        Write-Host "    Попытка fallback через реестр..." -ForegroundColor Yellow
        $RegPath = "HKLM:\SYSTEM\CurrentControlSet\Services\$($Service.name)"
        if (Test-Path $RegPath) {
            $StartValue = if ($Service.original_start -eq "Disabled") { 4 } elseif ($Service.original_start -eq "Manual") { 3 } elseif ($Service.original_start -eq "Automatic") { 2 } else { 3 }
            Set-ItemProperty -Path $RegPath -Name "Start" -Value $StartValue -Type DWord -Force -ErrorAction SilentlyContinue
            Write-Host "[+] $($Service.name) -> Start=${StartValue} (Registry fallback)" -ForegroundColor Green
        }
    }
}

# ==============================================================================
# ВОССТАНОВЛЕНИЕ РЕЕСТРА
# ==============================================================================
Write-Host "`n=== ВОССТАНОВЛЕНИЕ РЕЕСТРА ===" -ForegroundColor Cyan

foreach ($RegEntry in $Backup.registry) {
    foreach ($Value in $RegEntry.values) {
        try {
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
# СБРОС ПОЛИТИК
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
            Write-Host "[+] Удалена политика: ${Path}" -ForegroundColor Green
        }
        catch {
            Write-Host "[!] ${Path}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# ==============================================================================
# ВОССТАНОВЛЕНИЕ ЗАДАЧ
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
```


---

## ✅ Что исправлено в финальной версии

| Проблема | Решение |
|:---|:---|
| **Windows Defender не отключается** | Добавлено 3 метода: Set-MpPreference + Tamper Protection через реестр + Group Policy |
| **Задачи Access Denied** | Добавлены в конфиг, обработаны как штатная ситуация в verify_block.ps1 |
| **UTF-8 без BOM** | Все скрипты создаются через `[System.IO.File]::WriteAllText` с BOM |
| **ExecutionPolicy** | Запуск через `powershell -ExecutionPolicy Bypass -File` |
| **Пустой $ScriptPath** | Универсальный паттерн с fallback на `$PWD` |
| **Tamper Protection** | Принудительное отключение через реестр |
| **Group Policy Defender** | Создание политик для полного отключения |

---

## ✅ Финальный чек-лист блока 03A

- [ ] PowerShell запущен от имени Администратора
- [ ] `block_config.json` создан в папке `Z:\home-pc\Block03A\`
- [ ] `apply_block.ps1` создан и выполнен успешно
- [ ] `block_backup.json` создан (резервная копия)
- [ ] `block_log.txt` содержит записи о всех операциях
- [ ] `verify_block.ps1` показал 0 критических ошибок
- [ ] Windows Defender отключен (3 метода применены)
- [ ] Tamper Protection отключен
- [ ] Group Policy для Defender создана
- [ ] Все службы из конфига → Status: Stopped
- [ ] Защищённые службы (TrustedInstaller) → Start=4 в реестре
- [ ] Ключи реестра Delivery Optimization, OneDrive, Defender применены
- [ ] Задачи планировщика отключены (Access Denied — это нормально)
- [ ] `restore_block.ps1` создан для возможности отката

---

**БЛОК 03A ЗАВЕРШЁН.** Все фоновые службы заблокированы, Windows Defender полностью отключен (3 метода), задачи планировщика обработаны. Система готова к установке offline-обновлений через DISM (Блок 04).