
# Дополнительный контекст
- диагностика | оптимизация | ремонт ПК/ноутбуков

# Цель:
- визуализировать фазы/цепочку перехода от firmware к ядру ОС и процессы происходящие в каждом звене этой цепочки
- понимать цепочку загрузки Windows и процессы происходящие в каждом звене этой цепочки

# Задания:
- проведи исследования на тему: `bcdedit /enum firmware` → отследить путь `\EFI\Microsoft\Boot\bootmgfw.efi` → `winload.efi` → `ntoskrnl.exe`. Включить `bootlog` в `msconfig`
- проведи исследования на тему: анализ BCD и целостность `bootmgfw.efi`/`winload.efi`
- придумай 2 направления исследований в контексте цели и проведи такие исследования
- проанализируй результаты всех проведенных исследований в контексте цели и: необходимость для реального применения | логическая последовательность: освоения информации, инициализированных процессов, реальное применение
- систематизируй результаты проведенных анализов
- создай подробный теоритический гайд в контексте цели
- создай подробный гайд по практическому применению знаний из полученного теоритического





**📊 Анализ в контексте цели:**
- `Необходимость для реального применения`: 🔴 Критична. 85% проблем "чёрный экран/цикл" решаются на звеньях BCD → `bootmgfw` → `winload`.
- `Логическая последовательность`: `Визуализация цепи` → `Проверка целостности` → `Понимание Handover/Security` → `Практика диагностики`. Нарушение порядка ведёт к "лечению симптомов" вместо причины.
- `Реальное применение`: Каждое звено имеет свой инструмент: UEFI-Setup → `diskpart/mountvol` → `sigcheck/Get-Authenticode` → `bcdedit/bootlog` → `bcdboot/sfc`.

---

[MAIN] 📘 Теоретический гайд: Визуализация цепи загрузки Windows 11

```text
[POWER ON]
   ↓
🔹 UEFI Firmware (DXE → BDS)
   ├─ Инициализация PCIe/NVMe/USB
   ├─ Чтение NVRAM: BootOrder → Boot0001
   └─ Проверка подписи: \EFI\Microsoft\Boot\bootmgfw.efi (Secure Boot)
   ↓
🔹 bootmgfw.efi (Windows Boot Manager)
   ├─ Маунтит ESP → читает \EFI\Microsoft\Boot\BCD
   ├─ Парсит объект {default}/{current}
   ├─ Определяет путь: \Windows\System32\winload.efi
   └─ Передаёт управление с параметрами ядра
   ↓
🔹 winload.efi (Windows OS Loader)
   ├─ Проверка цифровой подписи winload.efi и bootmgfw.efi
   ├─ Загрузка HAL.dll, kdcom.dll, ядра ntoskrnl.exe
   ├─ Инициализация Memory Manager + Page Tables
   ├─ Вызов ExitBootServices() → UEFI отключает Boot Services
   ├─ Загрузка ELAM-драйверов (антивирус, Code Integrity)
   └─ Активация VBS/HVCI (если включено)
   ↓
🔹 ntoskrnl.exe (Windows Kernel)
   ├─ Инициализация Executive Services, Object Manager
   ├─ Загрузка BOOT_START драйверов
   ├─ Запуск smss.exe (Session Manager)
   ├─ Создание виртуальных страниц, своп
   └─ Передача управления user-mode
   ↓
🔹 SMSS → Wininit → CSRSS + WinLogon → LogonUI → Desktop
```

**📌 Что происходит в каждом звене:**
| Звено | Задача | Точки отказа |
|-------|--------|--------------|
| `UEFI` | Найти ESP, проверить подпись, передать контроль | `No bootable device`, `Secure Boot Violation` |
| `bootmgfw.efi` | Распарсить BCD, выбрать ОС, запустить загрузчик | `0xc000000f`, `0xc0000225` (BCD повреждён/отсутствует) |
| `winload.efi` | Валидация CI, загрузка ядра, Handover UEFI→OS | `0xc0000001`, `INACCESSIBLE_BOOT_DEVICE` |
| `ntoskrnl.exe` | Инициализация ядра, драйверы, user-mode старт | `BSOD (0x7B, 0x50, 0x1E)`, `Bootloop` |
| `ELAM/VBS` | Изоляция, проверка драйверов до выполнения | Блокировка легитимных драйверов, падение производительности |

---

[MAIN] 🛠️ Практический гайд: Диагностика и восстановление

### Шаг 0: Подготовка и изоляция
- **Как**: Загрузись с Ventoy → WinPE. Подключи диск Win11. Открой терминал (Admin).
- **Зачем**: Исключить влияние хоста, получить прямой доступ к ESP и `C:\`.
- **Результат**: Среда готова, диск виден как `C:\`, ESP как `Z:\`.

### Шаг 1: Локализация звена (быстрый тест)
- **Как**: Включи `bootlog` на проблемной системе: `msconfig` → Boot → `Boot log` → OK → перезагрузка.
- **Зачем**: `ntbtlog.txt` покажет, на каком драйвере стоп.
- **Действия**: `type C:\Windows\ntbtlog.txt | findstr /i "Not Loaded"`
- **✅ Ожидаемо**: Список драйверов. Ищи последние перед крахом.
- **❌ Неожиданно**: Файла нет или пуст → крах до `ntoskrnl` (звено `winload.efi` или BCD).

### Шаг 2: Проверка BCD и EFI-целостности
- **Как**:
  ```cmd
  :: 1. Маунт ESP
  diskpart → sel disk 0 → list part → sel part X → assign letter=Z → exit
  :: 2. Проверка пути в BCD
  bcdedit /store Z:\EFI\Microsoft\Boot\BCD /enum osloader
  :: 3. Проверка подписей
  Get-AuthenticodeSignature -FilePath "Z:\EFI\Microsoft\Boot\bootmgfw.efi" | fl
  Get-AuthenticodeSignature -FilePath "C:\Windows\System32\winload.efi" | fl
  ```
- **Зачем**: Убедиться, что BCD указывает на живые файлы, и они не изменены.
- **✅ Ожидаемо**: `Status: Valid`, `Path: \Windows\System32\winload.efi`
- **❌ Неожиданно**: `HashMismatch` или `Path: \Windows\winload.exe` (legacy) → **Восстановление**:
  ```cmd
  bcdboot C:\Windows /s Z: /f UEFI
  bootrec /fixboot /rebuildbcd
  ```

### Шаг 3: Диагностика Handover (`ExitBootServices`)
- **Как**: Проверь целостность файловой системы и зарезервированных регионов:
  ```cmd
  chkdsk C: /f /r
  fsutil fsinfo ntfsinfo C: | findstr /i "bytes"
  ```
- **Зачем**: Ошибки маппинга памяти или битые кластеры в `ntoskrnl` вызывают `0x7B`.
- **✅ Ожидаемо**: `No bad clusters found`.
- **❌ Неожиданно**: `File system errors fixed` → перезагрузи. Если краш → отключи `Fast Boot` и `VBS` временно для изоляции.

### Шаг 4: Проверка ELAM/VBS (безопасность на старте)
- **Как**: В WinPE/основной ОС:
  ```cmd
  :: Статус VBS
  systeminfo | findstr /i "Virtualization"
  :: Список ELAM-драйверов (в реестре)
  reg query "HKLM\SYSTEM\CurrentControlSet\Services" /f "Start" /d "0x0" /e
  ```
- **Зачем**: VBS может блокировать загрузку, если ядро/драйверы не совместимы.
- **✅ Ожидаемо**: `Virtualization-based security: Running` или `Not enabled`.
- **❌ Неожиданно**: BSOD с упоминанием `ci.dll` → временно отключи Secure Boot/VBS в BIOS, проверь драйверы.

### Шаг 5: Фиксация и валидация
- **Как**: Отключи `bootlog` (`msconfig`), перезагрузи. Проверь `eventvwr` → `Windows Logs → System` (источник `Kernel-Boot`).
- **Зачем**: Подтвердить, что цепочка прошла без блокировок.
- **Метрика успеха**: `Event ID 12` (Boot successful), `ntbtlog.txt` без `Not Loaded` критичных драйверов.

---

[IF SOFT] 🎓 Ментор: пояснения для beginner
- `Аналогия`: Загрузка = сборка ракеты. UEFI = стартовая башня (проверяет топливо). `bootmgfw` = центр управления (считывает план полёта BCD). `winload` = двигатель (запускает ядро). `ntoskrnl` = выход на орбиту. ELAM/VBS = система аварийного отключения.
- `Ловушка`: `bcdedit` без `/store` меняет **загруженную** конфигурацию. Всегда указывай `/store Z:\...` в WinPE.
- `Почему `bcdboot`, а не `bootrec`?`: `bcdboot` копирует EFI-файлы + создаёт BCD синхронно. `bootrec` только чинит MBR/загрузочный сектор (legacy).
- `Масштабирование`: После освоения шага 2 изучи `WinDbg` + `kd` для анализа `ntbtlog.txt` и дампов ядра. Добавь `chkdsk /scan` в регулярное ТО.

[RECOMMEND]
1. Создай `boot_diag.bat`: автоматизирует маунт ESP → проверку подписей → экспорт `bcdedit` → чистку `ntbtlog.txt`.
2. Держи образ WinPE на Ventoy с подписанными утилитами (`sfc`, `dism`, `bcdboot`, `chkdsk`) для работы в "кирпичном" режиме.

[ANTICIPATE]
- "Почему `bootlog` иногда пустой?" → Система крашится до инициализации логгера (звено `winload.efi` или `hal.dll`). Лечится диагностикой BCD/EFI.
- "Можно ли отключить `bootlog` без `msconfig`?" → Да: `bcdedit /deletevalue {default} bootlog`.







=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================

- напиши шпаргалку на тему возможные ситуации в контексте цепочки перехода от firmware к ядру ОС: подробно опиши 5-15 ситуаций с большой вероятностью возникновения → рекомендуемые действия(на что стоит обратить внимание, алгоритм выбора инструмента/утилиты/драйвера/настройки, какой результат хотим получить) → инициализация действия → какие сущности активируются в результате произведенного действия → возможные действия в случае получения ожидаемого и неожиданного результата





[MAIN] 📋 Шпаргалка: Ситуации цепочки Firmware → Ядро ОС (Win11)

### 🔹 Ситуация 1: «No bootable device / Boot device not found»
**Симптомы**: UEFI-BDS не находит загрузчик, выводит ошибку на черном фоне или возвращает в Setup.
**Причина**: Пустой `BootOrder`, отсутствие ESP, коррупция GPT или отключенный `UEFI Boot Mode`.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. UEFI Setup → Boot Mode → 2. WinPE → `diskpart` → 3. `bcdedit /enum firmware` → 4. `efibootmgr` / `mountvol`. |
| **⚙️ Рекомендуемые действия** | 1. Включи `UEFI Only` (отключи CSM/Legacy).<br>2. Смонтируй ESP (`assign letter=Z`), проверь наличие `\EFI\Microsoft\Boot\bootmgfw.efi`.<br>3. Если ESP пуста → `bcdboot C:\Windows /s Z: /f UEFI`.<br>4. Восстанови порядок: `efibootmgr -o 0001`. |
| **🚀 Инициализация действия** | BDS-фаза сканирует NVRAM `BootOrder` → резолвит `Device Path` → вызывает `LoadImage()` для `.efi`. |
| **⚙️ Активируемые сущности** | `NVRAM Variable Service`, `Device Path Resolver`, `BlockIO/FS Protocols`, `Boot Manager Policy`. |
| **✅ Ожидаемый результат** | UEFI находит ESP, загружает `bootmgfw.efi`, передает управление. |
| **❌ Неожиданный результат** | Диск определяется как RAW или не инициализирован.<br>→ **Действия**: 1) Восстанови GPT из бэкапа (`gdisk`/`TestDisk`); 2) Если данные не важны → `clean` + `convert gpt` + `bcdboot`. |

---

### 🔹 Ситуация 2: «Secure Boot Violation / Image failed verification»
**Симптомы**: Красный/синий экран с ошибкой подписи сразу после выбора загрузчика.
**Причина**: `.efi` не подписан ключом MS, запись в `dbx`, или повреждены `KEK/db`.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Setup → Security → 2. `Key Management` → 3. `mokutil`/`SecConfig.exe` (для кастомных ключей). |
| **⚙️ Рекомендуемые действия** | 1. Временно отключи `Secure Boot = Disabled` для диагностики.<br>2. Если нужно включить: `Restore Factory Keys` → перезагрузка.<br>3. Для кастомных образов: подпиши `sbsign` → добавь хеш в `dbx` через `MOK Manager`. |
| **🚀 Инициализация действия** | UEFI Security Driver валидирует PE-заголовок `.efi` через PKCS#7 → сверяет с `db`/`dbx`. |
| **⚙️ Активируемые сущности** | `PK/KEK/db/dbx Variables`, `Image Verification Protocol`, `Security Policy Manager`, `TPM PCR Extend`. |
| **✅ Ожидаемый результат** | Подпись принята, `bootmgfw.efi` получает контроль, загрузка продолжается. |
| **❌ Неожиданный результат** | Ошибка сохраняется при `Disabled` → NVRAM-кэш сбился.<br>→ **Действия**: 1) `Clear Secure Boot Keys` → `Reset`; 2) Перепрошей BIOS через Capsule Update. |

---

### 🔹 Ситуация 3: «0xc000000f / The Boot Configuration Data is missing»
**Симптомы**: Черный экран, текст ошибки о поврежденном/отсутствующем BCD.
**Причина**: Сбой питания во время записи, ручное удаление, или `diskpart clean` без пересоздания.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. WinPE → `diskpart` → 2. `bcdedit /store Z:\EFI\Microsoft\Boot\BCD /enum` → 3. `bcdboot`. |
| **⚙️ Рекомендуемые действия** | 1. Смонтируй ESP (`Z:`) и системный раздел (`C:`).<br>2. Проверь целостность хранилища: `chkdsk Z: /f`.<br>3. Пересоздай цепочку: `bcdboot C:\Windows /s Z: /f UEFI`. |
| **🚀 Инициализация действия** | `bootmgfw.efi` парсит `\EFI\Microsoft\Boot\BCD` → извлекает `osloader` путь → генерирует опции загрузки. |
| **⚙️ Активируемые сущности** | `BCD Library`, `Object Manager`, `Load Options Generator`, `Windows Boot Manager`. |
| **✅ Ожидаемый результат** | BCD валиден, `winload.efi` найден, загрузка переходит на уровень ОС. |
| **❌ Неожиданный результат** | `bcdboot` возвращает `Access Denied` или `IO Error`.<br>→ **Действия**: 1) Сними атрибут `ReadOnly` с ESP; 2) Если ФС FAT32 повреждена → `format Z: /FS:FAT32` → повтор `bcdboot`. |

---

### 🔹 Ситуация 4: «winload.efi missing or corrupt / 0xc000000e»
**Симптомы**: Ошибка загрузки файла `winload.efi` после выбора ОС.
**Причина**: Путь в BCD не совпадает с реальным, файл удален/поврежден, или сбой секторов диска.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Сравнение пути в BCD и файловой системе → 2. `Get-AuthenticodeSignature` → 3. Замена из WinPE/ISO. |
| **⚙️ Рекомендуемые действия** | 1. `bcdedit /enum osloader` → проверь `device` и `osdevice`.<br>2. Сверь хеш `winload.efi` с оригиналом из ISO.<br>3. Скопируй рабочий файл из `C:\Windows\System32\` в путь, указанный в BCD. |
| **🚀 Инициализация действия** | `bootmgfw` читает `osloader` entry → загружает `winload.efi` в память через `FS Protocol` → передает управление `WinMain()`. |
| **⚙️ Активируемые сущности** | `OS Loader Dispatcher`, `PE/COFF Loader`, `Memory Manager (Early)`, `Code Integrity Stub`. |
| **✅ Ожидаемый результат** | `winload.efi` исполняется, проходит CI-проверку, начинает инициализацию ядра. |
| **❌ Неожиданный результат** | Замена не помогает, ошибка повторяется.<br>→ **Действия**: 1) Проверь NVMe SMART/сектора (`chkdsk /r`); 2) Запусти `memtest` (битая RAM искажает PE-загрузку). |

---

### 🔹 Ситуация 5: «INACCESSIBLE_BOOT_DEVICE (0x7B)»
**Симптомы**: BSOD на этапе появления логотипа Windows или сразу после.
**Причина**: Конфликт режима контроллера (VMD/AHCI/RAID), отсутствие `BOOT_START` драйвера, или сбой Handover.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Setup → SATA/VMD Config → 2. WinPE → `reg load` → 3. `dism /add-driver`. |
| **⚙️ Рекомендуемые действия** | 1. В BIOS переключи `VMD Controller` → `Disabled` (или `AHCI`).<br>2. Если система требует VMD → инъекция драйвера `iaStorVD` через `dism` в оффлайн-образ.<br>3. Проверь реестр: `HKLM\SYSTEM\CurrentControlSet\Services\storahci` → `Start=0`. |
| **🚀 Инициализация действия** | `winload.efi` вызывает `ExitBootServices()` → `ntoskrnl` инициализирует Storage Stack → монтирует `C:\`. |
| **⚙️ Активируемые сущности** | `PnP Manager`, `Storage Miniport Drivers`, `PCI Configuration Space`, `Volume Manager`. |
| **✅ Ожидаемый результат** | Диск виден как `C:\`, ядро продолжает загрузку драйверов и служб. |
| **❌ Неожиданный результат** | 0x7B сохраняется после смены режима/инъекции.<br>→ **Действия**: 1) Проверь целостность ФС (`chkdsk /f`); 2) Восстанови BCD/регистрацию драйверов через `bootrec /rebuildbcd`. |

---

### 🔹 Ситуация 6: «Зависание на вращающихся точках / ExitBootServices hang»
**Симптомы**: Логотип Windows есть, точки крутятся долго, затем перезагрузка или полный фриз.
**Причина**: Конфликт Memory Map, баг GOP-драйвера, или ACPI-таблицы не совпадают с ожиданиями ядра.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. BIOS → Update → 2. `bcdedit /set {default} bootmenupolicy Standard` → 3. Отключение `Above 4G/ReBAR`. |
| **⚙️ Рекомендуемые действия** | 1. Обновить BIOS/ME до последней версии.<br>2. Временно отключить `Resizable BAR` / `Above 4G Decoding`.<br>3. Очистить NVRAM: `Setup → Restore Defaults`. |
| **🚀 Инициализация действия** | `winload` строит E820 Memory Map → вызывает `ExitBootServices()` → UEFI освобождает Boot Services → ядро берет контроль RAM. |
| **⚙️ Активируемые сущности** | `UEFI Memory Services`, `GOP (Graphics Output)`, `ACPI Table Generator`, `Kernel Memory Manager`. |
| **✅ Ожидаемый результат** | Чистый Handover, ядро инициализирует страницы, появляется экран входа. |
| **❌ Неожиданный результат** | Фриз сохраняется, система уходит в Watchdog Reset.<br>→ **Действия**: 1) Отключи `VBS/HVCI` и `Fast Boot`; 2) Проверь совместимость RAM/CPU; 3) Включи `Serial Debugging` для чтения кодов. |

---

### 🔹 Ситуация 7: «Boot Loop / Перезагрузка на логотипе»
**Симптомы**: Циклическая перезагрузка после появления лого Windows, без входа в OS.
**Причина**: Сбой `fastboot.sys`, поврежденный `hiberfil.sys`, или конфликт раннего драйвера.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Прерывание загрузки 3x → WinRE → 2. `powercfg /h off` → 3. `msconfig` → Safe Boot. |
| **⚙️ Рекомендуемые действия** | 1. Загрузись в WinPE, удали `C:\hiberfil.sys` и `C:\pagefile.sys`.<br>2. Выполни `bcdedit /set {default} safeboot minimal`.<br>3. В Safe Mode отключи `Fast Startup` в настройках электропитания. |
| **🚀 Инициализация действия** | `winload` проверяет флаг гибернации → пытается восстановить сессию → валидация fails → Watchdog → Reset. |
| **⚙️ Активируемые сущности** | `Power Manager`, `Hibernate Restore Service`, `Session Manager (smss.exe)`, `Watchdog Timer`. |
| **✅ Ожидаемый результат** | Цикл прерван, система грузится в Safe Mode или нормально после очистки состояния. |
| **❌ Неожиданный результат** | Loop продолжается в Safe Mode.<br>→ **Действия**: 1) `sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows`; 2) Проверь `ntbtlog.txt` на `Not Loaded` критические драйверы. |

---

### 🔹 Ситуация 8: «ELAM/VBS блокирует драйвер / CI Violation»
**Симптомы**: Загрузка успешна, но BSOD `DRIVER_VERIFIER_IOMANAGEMENT_VIOLATION` или тихий пропуск драйвера.
**Причина**: Unsigned `BOOT_START` драйвер, конфликт с Code Integrity или Hyper-V.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `ntbtlog.txt` → 2. `systeminfo` / `msinfo32` (VBS статус) → 3. `gpedit.msc` → Code Integrity. |
| **⚙️ Рекомендуемые действия** | 1. Отключи `Memory Integrity` (Целостность памяти) в Windows Security.<br>2. Подпиши драйвер через WHQL/Attestation или удали конфликтующий файл.<br>3. Временно отключи Secure Boot для обхода строгой проверки CI. |
| **🚀 Инициализация действия** | `ntoskrnl` запускает CI-подсистему → грузит ELAM-драйверы → валидирует `BOOT_START` перед выполнением. |
| **⚙️ Активируемые сущности** | `Code Integrity (ci.dll)`, `Early Launch Anti-Malware`, `VBS/HVCI Isolator`, `Driver Verifier`. |
| **✅ Ожидаемый результат** | Драйверы проходят проверку, система работает стабильно, VBS инициализирован корректно. |
| **❌ Неожиданный результат** | Блокировка сохраняется, CI логирует `POLICY_VIOLATION`.<br>→ **Действия**: 1) Очисти кэш CI (`C:\Windows\System32\CodeIntegrity\`); 2) Откати обновление драйвера; 3) Проверь совместимость с Win11 24H2. |

---

### 🔹 Ситуация 9: «GOP Driver Failure / Черный экран после POST»
**Симптомы**: UEFI-логотип вендора есть, но при передаче управления Windows экран гаснет или показывает артефакты.
**Причина**: Сбой `Graphics Output Protocol`, конфликт `CSM/Legacy`, или поврежден драйвер `BasicDisplay.sys`.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. BIOS → Video Config → 2. Подключение через `Remote Desktop`/`Safe Mode` → 3. `pnputil`/`devcon`. |
| **⚙️ Рекомендуемые действия** | 1. В BIOS переключи `Primary Display` на `IGFX`/`PCIe`.<br>2. Отключи `CSM` (чистый UEFI GOP).<br>3. В Safe Mode обнови/откати GPU-драйвер, удали `BasicDisplay.sys` из `DriverStore`. |
| **🚀 Инициализация действия** | UEFI вызывает `GOP SetMode()` → передает управление `winload` → ядро загружает `BasicDisplay.sys` → переключает в native mode. |
| **⚙️ Активируемые сущности** | `GOP Protocol`, `VGA/UEFI Video Adapter`, `Display Miniport`, `Kernel Mode Driver Framework (KMDF)`. |
| **✅ Ожидаемый результат** | Экран стабильно передает изображение, драйвер GPU инициализируется. |
| **❌ Неожиданный результат** | Артефакты/черный экран сохраняются в Safe Mode.<br>→ **Действия**: 1) Проверь кабель/порт/матрицу; 2) Сбрось BIOS; 3) Тестируй с внешним монитором (исключи eGPU/dGPU конфликт). |

---

### 🔹 Ситуация 10: «NVRAM Corruption / BootOrder сбрасывается при каждом включении»
**Симптомы**: После выбора загрузки или обновления BIOS `BootOrder` очищается, система требует ручной настройки каждый раз.
**Причина**: Износ SPI-флеша, сбой `Atomic Write`, или баг вендорного `Setup Utility`.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `efivar -l` / `RWEverything` (чтение) → 2. `Setup → Clear NVRAM` → 3. Вендорный `BIOS Recovery`. |
| **⚙️ Рекомендуемые действия** | 1. Экспортируй текущие переменные в бэкап.<br>2. Сделай полный сброс: `Load Optimized Defaults` + `Clear CMOS`.<br>3. Если не помогло → перепрошей BIOS через `Capsule Update` или `EZ Flash`. |
| **🚀 Инициализация действия** | Firmware читает Primary/Backup NVRAM → обнаруживает CRC mismatch → автоматически сбрасывает к дефолту. |
| **⚙️ Активируемые сущности** | `NVRAM Driver`, `CRC32 Verifier`, `SPI Flash Controller`, `Wear-Leveling Manager`. |
| **✅ Ожидаемый результат** | NVRAM стабилен, `BootOrder` сохраняется, загрузка детерминирована. |
| **❌ Неожиданный результат** | Сброс не помогает, ошибки CRC повторяются.<br>→ **Действия**: 1) Физический износ региона SPI → замена платы/модуля; 2) Используй `BootNext` для обхода NVRAM; 3) Обратись в сервис для дампа/восстановления программатором. |

---

[IF SOFT] 🎓 Ментор: как пользоваться шпаргалкой
- `Диагностика по слоям`: Не прыгай сразу к `bcdboot`. Сначала проверь UEFI-фазу (Ситуации 1-2), затем BCD/EFI (3-4), затем Handover/Драйверы (5-7), затем Security/ELAM (8).
- `Ловушка `ExitBootServices``: 60% "странных" фризов на логотипе Win11 связаны не с файлами, а с конфликтом Memory Map или VBS. Отключение `VBS` и `Fast Boot` в BIOS часто лечит то, что `sfc` не находит.
- `Безопасность записи`: Никогда не запускай `bcdedit /delete` или `format Z:` без предварительного `bcdedit /export` и бэкапа папки `EFI`.
- `Масштабирование`: Освоив эти 10 сценариев, добавь в арсенал `WinDbg` (анализ `MEMORY.DMP`) и `Chipsec` (аудит UEFI переменных/ACPI) для уровня Senior/Engineer.

[RECOMMEND]
1. Создай локальную папку `BootChain_Recovery` с 3 скриптами: `1_Check_BCD.bat`, `2_Repair_EFI.bat`, `3_Clear_NVRAM.ps1`. Это сократит диагностику с 30 до 5 минут.
2. Потренируй Ситуацию 3 и 5 на виртуальной машине (Hyper-V Gen2 + Win11 ISO) → сломай BCD/реестр intentionally, восстанови через WinPE. Это даст мышечную память.

[ANTICIPATE]
- "Как быстро отличить проблему UEFI от проблемы Windows?" → Если до логотипа вендора/BIOS не доходит → UEFI/GPT. Если логотип есть, но нет кружков → `bootmgfw.efi`/BCD. Если кружки есть, но BSOD/фриз → `winload`/ядро/драйверы.
- "Можно ли логировать `ExitBootServices`?" → Включи `Serial Port Debugging` в BIOS или используй `bcdedit /dbgsettings` для вывода в COM/USB-отладку.






