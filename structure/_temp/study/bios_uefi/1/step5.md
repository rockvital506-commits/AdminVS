
# Дополнительный контекст
- диагностика | оптимизация | ремонт ПК/ноутбуков

# Цель:
- понимать суть/последовательность/алгоритм: набора действий для извлечения/замены драйверов и загрузчиков без распаковки на диск | процессов(и их переменных/констант/атрибутов) инициализированных каждым действием из набора действий
- научиться извлекать/заменять драйверы и загрузчики без распаковки на диск

# Задания:
- проведи исследования на темы: `wimlib-imagex mount` для `.wim` | `dism /get-imageinfo` для `.esd` | Ventoy: автоматический маппинг ISO→EFI bootmenu
- проведи исследования на тему: почему прямое редактирование `.iso` ломает подпись/структуру, а монтирование + `imagex` сохраняет целостность
- придумай 2 направления исследований в контексте цели и проведи такие исследования
- проанализируй результаты всех проведенных исследований в контексте цели и: необходимость для реального применения | логическая последовательность( освоения информации, инициализации процессов, реального применения)
- систематизируй результаты проведенных анализов
- создай подробный теоретический гайд в контексте цели
- визуализируй: фазы извлечения/замены драйверов и загрузчиков без распаковки на диск, процессы происходящие в каждой фазе, переменные/константы/атрибуты каждого участвующего процесса
- создай подробный гайд по практическому применению знаний из полученного теоретического гайда






[MAIN] 📊 Анализ & Систематизация

| Критерий | Оценка | Обоснование |
|----------|--------|-------------|
| **Необходимость для реального применения** | 🔴 Критична | 90% проблем с установкой Win11 на новые чипсеты (VMD, NVMe, Wi-Fi 6E) решаются offline-инъекцией драйверов. Замена загрузчиков нужна для мультизагрузки и кастомных recovery-сценариев. |
| **Логика последовательности освоения** | `Формат → Overlay → Injection → Validation → Deploy` | Нарушение порядка ведет к битым образам. Сначала пойми chunk-store, затем overlay, затем модификацию, затем подпись/проверку, затем запись на Ventoy. |
| **Процессная инициализация** | `Mount() → LoadMetadata() → CreateOverlay() → PatchRegistry/ReplaceEFi() → RecalculateHash() → Unmount/Commit()` | Каждый шаг инициализирует конкретный набор переменных и валидирует целостность перед переходом. |

**Главный вывод**: Работа без распаковки возможна благодаря **виртуальным overlay-файловым системам** и **потоковому chunk-доступу**. Прямое редактирование ломает статические указатели, а инструменты (`wimlib`, `dism`, Ventoy) работают на уровне метаданных, сохраняя целостность и позволяя безопасно патчить драйверы/загрузчики.

---

[MAIN] 📘 Теоретический гайд: Извлечение/замена без распаковки

1. **Архитектура образа**: WIM/ESD хранят файлы в виде компрессированных блоков (`chunks`). Метаданные (пути, ACL, время) вынесены в XML. При `mount` создается **виртуальный view**: ядро читает метаданные, запрашивает чанки по требованию, пишет изменения в `delta`-директорию.
2. **Overlay-механизм**: FUSE/WinFSP перехватывает `read/write/syscalls`. `Read` → декомпрессия чанка в RAM. `Write` → сохранение в `overlay`. Файловая система видит результат как единый диск, физически образ не распакован.
3. **Модификация драйверов**: DISM/wimlib грузят offline-registry. Инжект `.inf` обновляет `DriverStore` и `SetupState`. При коммите `delta` применяется к основному `.wim`, пересчитываются хеши, XML обновляется.
4. **Замена загрузчика**: В `boot.wim` или ISO-структуре заменяется `.efi`. `wimlib` обновляет `BootFlags`, `Ventoy` при старте читает `El Torito` → маппит `bootx64.efi` в `BlockIo` → UEFI передает управление.
5. **Целостность**: Прямое редактирование ломает LBA/BootCatalog. `mount+imagex` сохраняет chunk-alignment, пересчитывает SHA256, позволяет перевыпустить подпись.

---

[VISUAL] 🗺️ Визуализация: Фазы, процессы, атрибуты

```
[PHASE 1] DETECT & PREP
  ├─ Процесс: ImageType Detection, Header Parse
  ├─ Переменные: FILE_SIG="MSWIM"/ISO9660, WIM_VER, COMPRESSION_TYPE
  ├─ Константы: WIM_MAGIC="WIM", ISO9660_PVD_SIZE=2048
  └─ Атрибуты: READ_ONLY=TRUE/FALSE, ENCRYPTED=BOOL

[PHASE 2] MOUNT (Overlay Init)
  ├─ Процесс: FUSE/WinFSP Attach, Metadata Load, Lazy-Chunk Cache
  ├─ Переменные: MOUNT_POINT="/mnt/wim", OVERLAY_DIR="/tmp/delta", PAGE_CACHE_SIZE
  ├─ Константы: MAX_CHUNK_SIZE=32MB, FUSE_VERSION=3.x
  └─ Атрибуты: MOUNT_TYPE=RW/RO, CACHE_POLICY=LRU, STREAM_REF_MAP

[PHASE 3] MODIFY (Inject/Replace)
  ├─ Процесс: Driver Inf-Parse, Registry Hive Load, EFI-Sign Check, Delta Write
  ├─ Переменные: INF_PATH, BOOT_CRITICAL=1/0, NEW_EFI_HASH, REG_HIVE_LOAD_STATUS
  ├─ Константы: DRIVER_STORE_PATH="\System32\DriverStore", EFI_SIG_SIZE=256
  └─ Атрибуты: OVERWRITE=TRUE, VERIFY_SIG=TRUE, PATCH_MODE=INPLACE

[PHASE 4] VALIDATE & COMMIT
  ├─ Процесс: SHA256 Recalc, XML Update, Delta Merge, Unmount
  ├─ Переменные: CALCULATED_HASH, COMMIT_STATUS=0xC0000000, MERGE_PERCENT
  ├─ Константы: XML_SCHEMA_VER=1.0, WIM_ALIGNMENT=8KB
  └─ Атрибуты: INTEGRITY_CHECK=PASS/FAIL, SIGN_APPLIED=BOOL

[PHASE 5] DEPLOY (Ventoy/UEFI)
  ├─ Процесс: ISO/IMG Write, ElTorito Parse, BlockIo2 Register, BootMenu Update
  ├─ Переменные: VTOY_MAP_ID, BOOT_MENU_ENTRY, EFI_DEVICE_PATH_LEN
  ├─ Константы: BLOCK_SIZE=512/4096, VTOY_BOOT_TIMEOUT=5
  └─ Атрибуты: VIRTUAL_CD=TRUE, SECURE_BOOT_COMPAT=TRUE
```

---

[MAIN] 🛠️ Практический гайд: Безопасная замена/инжект без распаковки

### Шаг 1: Подготовка и анализ образа
- **Как**: `dism /get-imageinfo /imagefile:C:\iso\sources\install.esd` или `wimlib-imagex info C:\image.wim`
- **Для чего**: Определить индекс образа, версию, сжатие, read-only флаг.
- **Переменные/Результат**: `IMAGE_INDEX=1`, `COMPRESSION=LZMS`. Запиши индекс для следующих команд.

### Шаг 2: Монтирование (Overlay)
- **Как (Win)**: `mkdir C:\mnt\wim && dism /mount-wim /wimfile:C:\image.wim /index:1 /mountdir:C:\mnt\wim /readonly`
- **Как (WSL2/Linux)**: `wimlib-imagex mount C:\image.wim /mnt/wim --compress=LZMS --readonly`
- **Для чего**: Создать виртуальный RW/RO view без распаковки.
- **Активируемые процессы**: `Metadata Parse` → `Chunk Cache Init` → `Overlay Dir Create`.
- **✅ Ожидаемо**: `The operation completed successfully`. В `C:\mnt\wim` видна структура Windows.
- **❌ Неожиданно**: `Access Denied` → Запусти от `System` (PsExec -s) или проверь, не смонтирован ли образ в другом процессе.

### Шаг 3: Инъекция драйверов / Замена загрузчика
- **Драйверы**:
  ```cmd
  dism /image:C:\mnt\wim /add-driver /driver:C:\drivers\RST\ /recurse /forceunsigned
  ```
  - *Процесс*: `INF Parse` → `DriverStore Copy` → `Registry Hive Update` (`OfflineSYSTEM`, `OfflineSOFTWARE`).
  - *Переменные*: `DRIVER_STORE_COUNT++`, `BOOT_START=1`.
- **Загрузчик**:
  ```powershell
  # Замена bootx64.efi внутри смонтированного образа
  Copy-Item -Path C:\custom\bootx64.efi -Destination "C:\mnt\wim\EFI\Boot\bootx64.efi" -Force
  ```
  - *Процесс*: `File Replace` → `Chunk Split` → `Delta Write`.
  - *Переменные*: `OVERLAY_DIR\EFI\Boot\bootx64.efi.delta`, `STREAM_ID=NEW`.
- **✅ Ожидаемо**: Файлы появились в overlay. Registry хайвы обновлены.
- **❌ Неожиданно**: `Driver not compatible` → Добавь `/forceunsigned`, проверь `.inf` синтаксис, сверь архитектуру (`x64` vs `arm64`).

### Шаг 4: Валидация и Commit
- **Как**: `dism /unmount-wim /mountdir:C:\mnt\wim /commit` (или `wimlib-imagex unmount /mnt/wim --commit`)
- **Для чего**: Слить `delta` в основной образ, пересчитать XML и хеши.
- **Процесс**: `Chunk Merge` → `SHA256 Recalc` → `XML Write` → `Overlay Cleanup`.
- **✅ Ожидаемо**: `The operation completed successfully`. Размер `.wim` изменен незначительно (+Delta).
- **❌ Неожиданно**: `Corrupted image` → Ошибка на этапе merge. Не повторяй. Сделай бэкап оригинала, проверь `sfc /scannow` в хосте, повтори с `wimlib-imagex`.

### Шаг 5: Деплой через Ventoy
- **Как**: Скопируй модифицированный `.iso`/`.wim` на Ventoy-раздел. Загрузись. Ventoy автоматически распознает `El Torito` → маппит в UEFI `BlockIo` → покажет в меню.
- **Процесс**: `ISO9660 Scan` → `BootCatalog Ptr Resolve` → `BlockIo2 Reg` → `BootMenu Update`.
- **Переменные**: `VTOY_MOUNT_STATUS=OK`, `EFI_BOOT_PATH="\EFI\BOOT\BOOTX64.EFI"`.
- **✅ Ожидаемо**: Меню Ventoy видит кастомный образ, загрузка стартует.
- **❌ Неожиданно**: `Secure Boot Violation` → Переподпиши `.efi` или отключи SB временно. Ventoy не маунтит → проверь `ISO9660` структуру через `isoinfo -l -i image.iso`.

---

[IF SOFT] 🎓 Ментор: пояснения для beginner
- `Без распаковки` ≠ `без использования места`. Overlay использует RAM и временную папку. Не удаляй её до `commit`.
- `DISM vs wimlib`: DISM — нативный для Windows, но ограничен PRO/ENT версиями и ESD. `wimlib` — кроссплатформенный, быстрее, лучше работает с LZMS/overlay. Для диагностики используй оба.
- `Ловушка`: Никогда не коммить образ, если `DISM` вернул `WARNING` или `ERROR 0x800F081F`. Это значит, что метаданные не согласованы → образ станет "кирпичом".
- `Почему не hex-edit ISO?`: Представь книгу с алфавитным указателем в конце. Если вырвать 2 страницы и вклеить новые, указатель укажет на пустоту. `mount` переписывает указатели автоматически.
- `Масштабирование`: После освоения шагов перейди к `dism /optimize-image` и `sbsign` для автоматической подписи кастомных `.efi` перед деплоем.

[RECOMMEND]
1. Создай скрипт `inject_and_commit.bat` с переменными `IMAGE_PATH`, `DRIVER_PATH`, `MOUNT_DIR`. Это уберет ручной ввод ошибок.
2. Всегда держи `wimlib-imagex` и `dism` в `PATH`. Тестируй модификации на копии `.wim` перед записью на Ventoy.

[ANTICIPATE]
- "Как проверить, что драйвер действительно внедрен, не монтируя снова?" → `dism /get-imageinfo /imagefile:modified.wim /index:1` покажет измененный размер и дату. Глубже: `wimlib-imagex extract modified.wim 1 Windows\System32\DriverStore\FileRepository --dest=C:\verify`.
- "Ventoy не видит модифицированный `.wim`?" → Ventoy работает с `.iso`/`.img`/`.vhd`. Для `.wim` конвертируй в bootable ISO через `oscdimg` (`oscdimg -b"boot\etfsboot.com" -u2 -h -m C:\mnt\iso output.iso`).







=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================

- напиши шпаргалку на тему возможные ситуации в контексте извлечение/замена драйверов и загрузчиков без распаковки на диск: подробно опиши 5-15 ситуаций с большой вероятностью возникновения → рекомендуемые действия(на что стоит обратить внимание, алгоритм выбора инструмента/утилиты/драйвера/настройки, какой результат хотим получить) → инициализация действия → какие сущности активируются в результате произведенного действия → возможные действия в случае получения ожидаемого и неожиданного результата






[MAIN] 📋 Шпаргалка: Ситуации при извлечении/замене драйверов и загрузчиков без распаковки

### 🔹 Ситуация 1: «Mount fails: Access denied / File in use»
**Симптомы**: `dism /mount-wim` или `wimlib-imagex mount` возвращает `0xC1510111`, `Access denied` или `Device or resource busy`.
**Причина**: Образ уже смонтирован другим процессом, FUSE/WinFSP драйвер не загружен, или файл заблокирован антивирусом/индексатором.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `wimlib-imagex info image.wim` → проверка статуса → 2. `tasklist /m wimmount.sys` → 3. Очистка `%TEMP%` и перезапуск сервиса FUSE. |
| **⚙️ Рекомендуемые действия** | Закрой все окна проводника в target-папке. Отключи实时-сканер AV. Убедись, что переменная `WIMLIB_TEMP_DIR` указывает на свободный том. |
| **🚀 Инициализация действия** | Вызов mount → проверка хэндла файла → аллокация RAM-cache → создание FUSE/overlay точки монтирования. |
| **⚙️ Активируемые сущности** | `WimMount Driver` → `FUSE/WinFSP Layer` → `Overlay Metadata Parser` → `LOCK_STATUS=UNLOCKED`, `MOUNT_FLAGS=RW/RO`, `CACHE_SIZE=512MB`. |
| **✅ Ожидаемый результат** | Папка mount доступна, структура Windows видна без распаковки.<br>→ **Действия**: Переход к инъекции/замене. |
| **❌ Неожиданный результат** | Ошибка `Invalid Image` или `CRC mismatch`.<br>→ **Действия**: 1) `wimlib-imagex verify image.wim`; 2) Сделай локальную копию; 3) Попробуй `dism` вместо `wimlib` (обратная совместимость). |

---

### 🔹 Ситуация 2: «Commit fails: 0x800F081F (Metadata hash mismatch)»
**Симптомы**: Драйвер добавляется успешно, но `/commit` падает с ошибкой хеша или несоответствия XML.
**Причина**: ESD/LZMS образ помечен как `READ_ONLY`, или изменилась структура chunk-таблицы без пересчета дескриптора.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `dism /get-imageinfo` → проверка `Read-only` → 2. Конвертация в `.wim` (`/export`) → 3. Повторный commit с `--check`. |
| **⚙️ Рекомендуемые действия** | Для `.esd` сначала сделай `dism /export-image` в `.wim`. При LZMS используй `wimlib` с флагом `--compress=LZX` на время правки. |
| **🚀 Инициализация действия** | Запуск commit → слияние delta-overlay → пересчет SHA256 chunk-ов → запись обновленного XML-дескриптора. |
| **⚙️ Активируемые сущности** | `Delta Merger` → `XML Metadata Writer` → `SHA256_CHECKSUM=RECALC`, `WIM_VER=1`, `COMMIT_STATE=IN_PROGRESS`, `ALIGNMENT=8KB`. |
| **✅ Ожидаемый результат** | Коммит успешен, overlay очищен, размер образа вырос незначительно (+delta).<br>→ **Действия**: Проверка через `dism /get-imageinfo`. |
| **❌ Неожиданный результат** | Образ помечен как corrupted, commit откатывается.<br>→ **Действия**: 1) Восстанови из бэкапа; 2) `wimlib-imagex optimize image.wim`; 3) Откажись от inline-правки, используй `/apply` + `/capture`. |

---

### 🔹 Ситуация 3: «Secure Boot Violation после замены bootloader.efi»
**Симптомы**: Заменен `bootx64.efi` в `boot.wim`, после загрузки Ventoy выдает `Security violation / Invalid signature`.
**Причина**: UEFI проверяет подпись нового `.efi`. Файл не подписан ключом MS/KEK или хеш в `dbx`.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `sbsign`/`osslsigncode` → подпись → 2. Временное `SecureBoot=Disabled` → 3. Импорт ключа в `MOK`/`db`. |
| **⚙️ Рекомендуемые действия** | Подписывай кастомные `.efi` перед коммитом. Для тестов отключи SB. В продакшене обнови `SetupMode=1` и импортируй сертификат. |
| **🚀 Инициализация действия** | UEFI BDS загружает `.efi` → Security Driver читает PE-заголовок → валидация PKCS#7 → сравнение с NVRAM-ключами. |
| **⚙️ Активируемые сущности** | `PE/COFF Parser` → `Authenticode Verifier` → `NVRAM_KEY_DB={PK,KEK,db,dbx}`, `PKCS7_SIG_SIZE=256`, `TPM_PCR=EXTEND`. |
| **✅ Ожидаемый результат** | Подпись валидна, загрузчик выполняется, цепочка передана `winload.efi`.<br>→ **Действия**: Включить Secure Boot обратно. |
| **❌ Неожиданный результат** | Ошибка сохраняется даже после подписи.<br>→ **Действия**: 1) Проверь цепочку CA; 2) Очисти `dbx` от блокирующих хешей; 3) `sbverify --list file.efi` для аудита. |

---

### 🔹 Ситуация 4: «Ventoy не видит модифицированный .iso / Boot failed»
**Симптомы**: Файл не появляется в меню или выбор приводит к `File not found`.
**Причина**: Нарушена структура El Torito Boot Catalog, ISO9660 путь изменен, или Ventoy не распознал `BlockIo2` device.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `isoinfo -l -i image.iso` → проверка структуры → 2. Пересборка через `oscdimg` с `-b` → 3. `vtoyupdate`. |
| **⚙️ Рекомендуемые действия** | Не редактируй `.iso` архиваторами. Используй `oscdimg` с явным указанием `efisys.bin`. Проверь пути в `boot.cat`. |
| **🚀 Инициализация действия** | Ventoy сканирует USB → парсит ISO9660 PVD → читает El Torito каталог → регистрирует виртуальный `BlockIo2`. |
| **⚙️ Активируемые сущности** | `ISO9660 Parser` → `ElTorito_CATALOG_PTR`, `BLOCK_SIZE=2048`, `UEFI_BlockIo2_Protocol`, `BOOT_PATH="\EFI\BOOT\BOOTX64.EFI"`. |
| **✅ Ожидаемый результат** | Образ виден в меню, загрузка стартует через кастомный `.efi`.<br>→ **Действия**: Тест на целевом железе. |
| **❌ Неожиданный результат** | Меню показывает файл, но загрузка висит на `Loading...`.<br>→ **Действия**: 1) Проверь выравнивание секторов (`isoinfo -d`); 2) Убедись, что `bcd` лежит в `\EFI\Microsoft\Boot\`; 3) Режим `ISO Mode` (прямой маппинг). |

---

### 🔹 Ситуация 5: «Driver не загружается (Boot Critical / Registry)»
**Симптомы**: Драйвер добавлен в `DriverStore`, но при старте Windows игнорируется, устройство не определяется.
**Причина**: В offline-реестре не установлен `BootCritical=1` или `Start=0`, либо `.inf` не указывает раннюю группу загрузки.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `reg load HKLM\OFF_SYSTEM mount\Windows\System32\config\SYSTEM` → 2. Проверка `Services\<Drv>` → 3. Коррекция `Start`/`Group` → `reg unload`. |
| **⚙️ Рекомендуемые действия** | `Start`: `0=Boot`, `1=System`, `2=Auto`. Для NVMe/Storage используй `Boot Bus Extender` или `SCSI Miniport` group. |
| **🚀 Инициализация действия** | PnP Manager читает `SYSTEM` hive → фильтрует `Start<=1` → загружает `.sys` → вызывает `DriverEntry`. |
| **⚙️ Активируемые сущности** | `Offline Registry Loader` → `PnP_Manager`, `BOOT_CRITICAL_FLAG=0x0001`, `SERVICE_START_TYPE=0/1`, `CLASS_GUID={4d36e97b-e325-11ce-bfc1-08002be10318}`. |
| **✅ Ожидаемый результат** | Устройство появляется на раннем этапе, драйвер активен.<br>→ **Действия**: Фиксация в `ntbtlog.txt`. |
| **❌ Неожиданный результат** | BSOD `0x7B` или `CRITICAL_PROCESS_DIED`.<br>→ **Действия**: 1) `dism /remove-driver`; 2) Проверь архитектуру (`x64` vs `ARM64`); 3) Убедись, что зависимости внедрены. |

---

### 🔹 Ситуация 6: «ESD Read-Only Block»
**Симптомы**: `dism /add-driver` на `.esd` возвращает `The image is read-only. Changes cannot be saved.`
**Причина**: Формат ESD имеет флаг `WIM_FLAG_READONLY` и использует LZMS, не поддерживающий inline-delta.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `dism /export-image` → `.wim` → 2. Работа с `.wim` → 3. Обратная конвертация (опционально). |
| **⚙️ Рекомендуемые действия** | Никогда не редактируй `.esd` напрямую. Конвертируй в `.wim` с `LZX` для правки. Сохраняй индексы. |
| **🚀 Инициализация действия** | Экспорт → декомпрессия LZMS → перекодировка в LZX → сброс флага `READ_ONLY`. |
| **⚙️ Активируемые сущности** | `ESD_Decoder` → `COMPRESSION_ENGINE=LZMS→LZX`, `WIM_FLAGS=RW`, `IMAGE_INDEX=1..N`, `READ_ONLY_STATE=FALSE`. |
| **✅ Ожидаемый результат** | Получен `.wim` с `Read-Write` атрибутом, готов к pipeline.<br>→ **Действия**: Стандартная инъекция. |
| **❌ Неожиданный результат** | Конвертация теряет метаданные/индексы.<br>→ **Действия**: 1) `wimlib-imagex export --boot`; 2) Сверь `dism /get-imageinfo` до/после; 3) Не удаляй исходник. |

---

### 🔹 Ситуация 7: «Overlay Cache Exhaustion / Temp Dir Full»
**Симптомы**: Ошибка `Not enough disk space` или `FUSE layer error` при mount/inject, хотя на основном диске место есть.
**Причина**: Overlay использует `%TEMP%` или RAM-disk. Кэш delta-файлов превышает лимит тома.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `set WIMLIB_TEMP_DIR=D:\WimTemp` → 2. Очистка `%TEMP%` → 3. `dism /scratchdir:` |
| **⚙️ Рекомендуемые действия** | Создай папку с 50+ ГБ. Укажи её через env-переменную. Отключи AV на время commit. |
| **🚀 Инициализация действия** | Инициализация overlay → выделение temp-директории → маппинг write-ops в delta-files → мониторинг места. |
| **⚙️ Активируемые сущности** | `Temp Dir Manager` → `DELTA_ALLOCATOR`, `DISK_FREE_LIMIT=10GB`, `FUSE_WRITE_PROXY`, `CACHE_POLICY=LRU`. |
| **✅ Ожидаемый результат** | Операции стабильны, temp-файлы растут предсказуемо.<br>→ **Действия**: Мониторинг через `Resource Monitor`. |
| **❌ Неожиданный результат** | `IO Error` на середине commit, образ поврежден.<br>→ **Действия**: 1) Перезагрузи хост (сброс FUSE); 2) Восстанови бэкап; 3) Увеличь `pagefile.sys` или используй внешний SSD для temp. |

---

### 🔹 Ситуация 8: «Boot Menu Duplication / Path Mismatch»
**Симптомы**: После замены загрузчика в `boot.wim` меню показывает два пункта `Windows Setup`, один грузит старый, другой новый.
**Причина**: В `bcd` внутри образа остались ссылки на старый `bootmgr.efi`, или `boot.sdi` путь не совпадает с `Device Path`.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `bcdedit /store C:\mnt\wim\boot\bcd` → проверка `device` → 2. `bcdboot` или ручная правка → 3. Очистка cache. |
| **⚙️ Рекомендуемые действия** | Проверяй `bcd` после инъекции. `bcdedit /enum all` для дубликатов. Синхронизируй `osdevice` и `device`. |
| **🚀 Инициализация действия** | Загрузка BCD → парсинг `{default}`/`{setup}` → резолв `DevicePath` → генерация меню. |
| **⚙️ Активируемые сущности** | `BCD Store Parser` → `DEVICE_PATH="\Device\HarddiskVolume1"`, `OSLOADER_PATH="\Windows\System32\winload.efi"`, `ENTRY_ID={GUID}`. |
| **✅ Ожидаемый результат** | Один пункт меню, корректная загрузка нового `.efi`.<br>→ **Действия**: Удаление старых записей `bcdedit /delete`. |
| **❌ Неожиданный результат** | Дубликаты сохраняются, загрузка падает в `Bootrec`.<br>→ **Действия**: 1) Удали `bcd`, пересоздай `bcdboot`; 2) Проверь `boot.sdi`; 3) Убедись, что `wimboot` опции не конфликтуют. |

---

[IF SOFT] 🎓 Ментор: как читать и применять
- `Переменные vs Константы`: В пайплайне без распаковки всё строится на **атрибутах** (`READ_ONLY`, `BOOT_CRITICAL`), **хешах** (`SHA256`, `PKCS7`) и **указателях** (`EL_TORITO_CATALOG_PTR`, `DEVICE_PATH`). Не меняй константы, меняй только переменные через API.
- `Ловушка inline-правки`: Прямое редактирование бинарников внутри смонтированного образа без commit ломает chunk-alignment. Всегда используй `dism /add-driver` или `Copy-Item` → `commit`.
- `Масштабирование`: После освоения этих 8 сценариев автоматизируй пайплайн в PowerShell: `Mount → Inject → Sign → Commit → Verify → Deploy to Ventoy`. Логирование каждого этапа сократит время ремонта на 70%.

[RECOMMEND]
1. Создай `wim_pipeline.ps1` с параметрами `$Image`, `$DriverPath`, `$TempDir`. Это исключит ручные ошибки `0x800F081F`.
2. Храни эталонные `.wim` и подписанные `.efi` на отдельном NTFS-томе (W:), чтобы быстро сравнивать хеши до и после правок.

[ANTICIPATE]
- "Как проверить, что драйвер точно внедрен, не монтируя снова?" → `dism /get-imageinfo` покажет измененный размер/дату. Глубже: `wimlib-imagex extract image.wim 1 Windows\System32\DriverStore --dest=.\verify`.
- "Почему Ventoy иногда игнорирует мой `.iso`?" → Проверяй `isoinfo -d -i image.iso`. Если `Logical block size != 2048` или `El Torito` отсутствует, Ventoy fallback-ит в legacy. Используй `oscdimg -b` для генерации корректного каталога.
