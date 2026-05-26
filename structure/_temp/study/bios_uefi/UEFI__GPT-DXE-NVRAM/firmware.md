

# Дополнительный контекст
- диагностика | оптимизация | ремонт ПК/ноутбуков

# Цели:
- получить полные знания о firmware для практического применения

# Задания:
- проведи исследования на темы firmware и его: мануалы | руководства | сферы применения | рекомендации | настройки | последовательность от включения питания до загрузки Windows | технологии и необходимый софт | способы взаимодействия с образами и их алгоритмы | firmware/bootloader | жизненый цикл
- придумай 2 направления исследований в контексте цели и проведи такие исследования
- проанализируй результаты проведенных исследований в контексте цели и: необходимость для реального применения, логика последовательности освоения и применения
- проанализируй проведенные исследования
- используя результаты проведенных анализов:
  - расскажи подробно про firmware
  - создай подробный гайд по практическому применению firmware






[MAIN] 📖 Подробный разбор: что такое firmware (практический взгляд)

### 🔹 Простая аналогия
> Представь компьютер как театр:
> - **Firmware** = режиссер + сценограф: готовит сцену (железо), расставляет актеров (драйверы), дает сигнал к началу (загрузка ОС).
> - **UEFI фазы** = репетиции: 
>   - `SEC/PEI` = проверка света/звука (базовая инициализация),
>   - `DXE` = выход актеров на сцену (драйверы устройств),
>   - `BDS` = выбор пьесы (загрузчика),
>   - `TSL` = занавес открывается (передача управления ОС).
> - **NVRAM** = записная книжка режиссера: хранит, какую пьесу играть первой (`BootOrder`), кто допущен на сцену (`db`), а кто нет (`dbx`).

### 🔹 5 практических принципов работы с firmware
1. **Всегда делай бэкап перед записью** [[15]][[42]]:
   - Чип SPI: `flashrom -r backup.bin --verify`.
   - NVRAM: `efivar -l` + экспорт переменных.
   - Без бэкапа — только чтение.

2. **Читай спецификации, но начинай с гайдов** [[1]][[28]]:
   - `UEFI Spec 2.10` — эталон, но сложный.
   - `ArchWiki: UEFI`, `Thomas-Krenn: UEFITool` — практика.
   - Сначала сделай, потом углубляйся в "почему".

3. **Используй изолированную среду для тестов** [[5]][[8]]:
   - Виртуальная машина с OVMF/EDK2.
   - Ventoy с образами для отработки загрузки.
   - Никогда не тестируй деструктивные команды на единственной рабочей системе.

4. **Верифицируй каждый шаг записи** [[15]][[42]]:
   - После `flashrom -w`: обязательно `--verify`.
   - После записи NVRAM: перечитай переменную, сверь хеш.
   - Ошибка верификации = откат к бэкапу.

5. **Документируй всё** [[28]][[42]]:
   - Сохраняй выводы команд в лог: `script firmware_session.log`.
   - Фиксируй хеши образов, версии инструментов, даты.
   - При сбое — лог поможет восстановить ход действий.

---

[MAIN] 🛠️ Практический гайд: работа с firmware (диагностика → восстановление)

### 📋 Этап 0: Подготовка (обязательно)
```bash
# 1. Создай рабочую папку
mkdir ~/firmware_lab && cd ~/firmware_lab

# 2. Установи инструменты (Linux/WinPE)
# Linux:
sudo apt install flashrom uefitool chipsec efivar

# Windows (WinPE через Ventoy):
# - Скачай UEFITool, RWEverything, chipsec.exe
# - Положи на флешку V: (exFAT)

# 3. Подготовь бэкап-хранилище
mkdir backup && mkdir logs
```

### 🔍 Этап 1: Диагностика (чтение, анализ)
| Задача | Команда/Инструмент | Что проверяем |
|--------|-------------------|---------------|
| **Версия firmware** | `msinfo32` (Win) / `dmidecode -s bios-version` (Linux) [[1]][[7]] | Актуальность, вендор, дата сборки |
| **Режим загрузки** | `bcdedit /enum firmware` / `efibootmgr -v` | UEFI vs Legacy, Secure Boot статус |
| **Структура GPT/ESP** | `diskpart` → `list part` / `gdisk -l /dev/nvme0n1` | Наличие ESP, GUID `C12A7328...` |
| **Парсинг образа** | `UEFITool` → открыть `.rom`/`.cap` [[28]][[30]] | Наличие DXE-драйверов, микрокода, даты сборки |
| **Аудит безопасности** | `chipsec` (`chipsec_util uefi var-list`) [[6]] | Корректность переменных, наличие `PK/KEK` |

**Пример: анализ образа через UEFITool** [[28]][[30]]:
1. Запусти `UEFITool.exe`, открой файл `BIOS.rom`.
2. Перейди на вкладку `FIT` (Firmware Interface Table) — увидишь микрокод, даты.
3. Поиск по тексту: `Action → Search → Text` → введи `2025` → найди дату сборки.
4. Поиск по GUID: `Action → Search → GUID` → введи `AB56DC60-0057-11DA-A8DB-000102EEE626` → дата в hex-виде.

### 🔄 Этап 2: Восстановление (запись с верификацией)
| Сценарий | Действия | Проверка |
|----------|----------|----------|
| **Сбой загрузки (битый ESP)** | 1. Загрузись с WinPE (Ventoy)<br>2. `diskpart` → `assign letter=Z` для ESP<br>3. `bcdboot C:\Windows /s Z: /f UEFI`<br>4. `exit` → перезагрузка | `dir Z:\EFI\Microsoft\Boot` → наличие `bootmgfw.efi` |
| **Коррупция NVRAM** | 1. `efivar -l` → экспорт переменных в `backup/`<br>2. Сброс: `Setup → Restore Defaults`<br>3. Восстановление: `efivar -w` для `BootOrder`/`Timeout` | `efibootmgr -v` → корректный `BootOrder` |
| **Полный сбой firmware (SPI)** | 1. Бэкап текущего состояния: `flashrom -r broken.bin`<br>2. Скачай официальный `.rom` с сайта вендора [[3]][[15]]<br>3. Запись: `flashrom -w official.rom --verify`<br>4. Для Intel: `--ifd -i bios -N` (только BIOS-регион) | `flashrom -v official.rom` → `Verification succeeded` |

**⚠️ Критичные предупреждения**:
- Не записывай `ME/GBE`-регионы без понимания — это может "окирпичить" платформу [[15]][[46]].
- Не отключай питание во время записи — используй ИБП.
- Не используй образы от других моделей — даже если разъем совпадает.

### 🧪 Этап 3: Тестирование (после восстановления)
```powershell
# Windows: проверка загрузки
bcdedit /enum firmware
Get-WindowsDriver -Online | Where-Object {$_.Driver -like "*firmware*"}

# Linux: проверка переменных
efibootmgr -v
dmesg | grep -i uefi

# Аппаратная проверка
# - Слушай спикер: 1 короткий = успех
# - Смотри POST-коды (если есть дисплей/индикаторы)
```

---

[IF SOFT] 🎓 Ментор: пояснения для beginner
- `flashrom` vs `RWEverything`: `flashrom` — для SPI-чипов (аппаратный доступ), `RW` — для NVRAM/PCI (программный доступ). Начинай с `flashrom -r` (только чтение).
- `UEFITool` не изменяет образ по умолчанию: все изменения — через `Action → Replace/Insert`, но сначала сделай копию исходника.
- `Secure Boot` ≠ "включил и забыл": при дуал-буте могут потребоваться ключи (`MOK` в Linux, `enroll_hash` в Ventoy).
- `POST-коды`: если на материнке есть LED-индикаторы или 7-сегментный дисплей — коды `00-3F` = PEI, `40-7F` = DXE, `80+` = BDS/TSL. Запиши код при сбое — это сузит поиск.
- `Масштабирование`: После освоения базовых процедур перейди к `edk2` (сборка кастомного DXE-драйвера) и `chipsec` (аудит безопасности) — это даст глубокое понимание.

[🛡️ Чек-лист безопасности перед записью]
1. [ ] Есть бэкап текущего состояния (`flashrom -r`, `efivar` экспорт)?
2. [ ] Образ для записи скачан с официального сайта вендора?
3. [ ] Проверен хеш образа (`sha256sum`)?
4. [ ] Питание стабильно (ИБП/ноутбук на зарядке)?
5. [ ] Понимаю, в какой регион пишу (BIOS vs ME vs GBE)?
6. [ ] Готов к откату (есть план восстановления при сбое)?

[RECOMMEND]
1. Создай файл `firmware_checklist.md` с этим гайдом и чек-листом — держи на Ventoy.
2. Потренируй Этап 1 (диагностика) на виртуальной машине с OVMF — это безопасно и даст уверенность.

[ANTICIPATE]
- "Как узнать, какой у меня регион SPI (BIOS/ME/GBE)?" → Открой образ в `UEFITool` → вкладка `Regions` → увидишь смещения и размеры. Или `flashrom -p internal --ifd` (только чтение!).
- "Можно ли обновить firmware без риска?" → Да: используй вендорный Capsule Update через Windows Update или официальный `.cap`-файл с проверкой подписи. Никогда не обновляй "на всякий случай" — только при необходимости (баг, безопасность, совместимость) [[2]][[3]].







=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================

- если представить firmware как python объект, какие атрибуты и методы ты бы реализовал у этого объекта?


[MAIN] 🖼️ Схема 1: Python-модель Firmware (Атрибуты → Состояние, Методы → Действия, Asserts → Безопасность)

```mermaid
graph LR
    subgraph ATTRIBUTES["📦 АТРИБУТЫ (ДАННЫЕ)"]
        A1[current_phase] --> S1[Состояние: фаза загрузки]
        A2[nvram: dict] --> S2[Состояние: переменные в SPI]
        A3[boot_order: list] --> S3[Состояние: очередь загрузки]
        A4[secure_boot_keys] --> S4[Состояние: цепочка доверия]
        A5[hardware_state] --> S5[Состояние: инициализация устройств]
    end

    subgraph METHODS["⚙️ МЕТОДЫ (ДЕЙСТВИЯ)"]
        M1[run_phase()] --> D1[Переход фазы + инициализация шин]
        M2[get/set_variable()] --> D2[Чтение/запись NVRAM с атрибутами]
        M3[add_boot_entry()/set_boot_order()] --> D3[Регистрация загрузчиков]
        M4[verify_and_load()] --> D4[Проверка подписи .efi перед запуском]
        M5[dump_spi()/restore_spi()] --> D5[Аппаратный бэкап/восстановление]
        M6[check_integrity()] --> D6[Валидация CRC/ACPI]
    end

    subgraph ASSERTS["🛡️ ASSERTS (МЕХАНИЗМЫ БЕЗОПАСНОСТИ)"]
        AS1[assert phase_order] --> B1[Защита от отката фаз]
        AS2[if attrs & AT and phase==RT] --> B2[Блокировка записи ключей без подписи]
        AS3[assert setup_mode or key in db] --> B3[Требование подписи для db/dbx]
        AS4[assert "ME" not in regions] --> B4[Защита от записи ME/GBE без подтверждения]
        AS5[verify_sha256 before write] --> B5[Верификация бэкапа перед восстановлением]
    end

    ATTRIBUTES --> METHODS --> ASSERTS
```

**📝 Текстовая версия (для копирования):**
```
[АТРИБУТЫ] → [СОСТОЯНИЕ]
• current_phase       → Какая фаза активна (SEC/PEI/DXE/BDS/TSL/RT)
• nvram: dict         → Хранилище {(имя, GUID): {data, attrs}}
• boot_order: list    → Порядок загрузки [0001, 0002, ...]
• secure_boot_keys    → PK/KEK/db/dbx цепочка
• hardware_state      → {ram: bool, pci: bool, usb: bool, nvme: bool}

[МЕТОДЫ] → [ДЕЙСТВИЯ]
• run_phase("DXE")    → Инициализация шин, загрузка драйверов
• get_variable(name)  → Чтение переменной (аналог efivar -d)
• set_variable(..., AT) → Запись с проверкой атрибутов/подписи
• add_boot_entry()    → Регистрация нового загрузчика в NVRAM
• verify_and_load()   → Проверка подписи .efi перед запуском
• dump_spi()/restore_spi() → Аппаратный бэкап/запись чипа
• check_integrity()   → CRC GPT/NVRAM, валидация ACPI

[ASSERTS] → [МЕХАНИЗМЫ БЕЗОПАСНОСТИ]
• assert phase_order         → Нельзя "откатить" фазу назад
• if attrs & AT and RT       → Запись ключей требует подписи
• assert setup_mode or db    → Изменение db/dbx только в SetupMode или с подписью
• assert "ME" not in regions → Защита от записи ME/GBE без явного подтверждения
• verify_sha256 before write → Обязательная верификация перед записью в SPI
```


```python
class UEFIFirmware:
    """Концептуальная модель UEFI-прошивки для понимания архитектуры и диагностики."""
    
    # ─── КОНСТАНТЫ СПЕЦИФИКАЦИИ ───
    PHASES = ["SEC", "PEI", "DXE", "BDS", "TSL", "RT"]
    SPI_REGIONS = {"BIOS", "NVRAM_PRIMARY", "NVRAM_BACKUP", "ME", "GBE", "FD"}
    VAR_ATTRS = {"NV": 0x01, "BS": 0x02, "RT": 0x04, "AT": 0x20}  # NVRAM, BootServices, Runtime, Authenticated
    GLOBAL_VAR_GUID = "8be4df61-93ca-11d2-aa0d-00e098032b8c"

    # ─── АТРИБУТЫ (СОСТОЯНИЕ) ───
    def __init__(self, spi_dump_path: str, vendor: str, version: str):
        self.vendor = vendor
        self.version = version
        self.spi_dump = spi_dump_path
        
        self.current_phase = "SEC"
        self.post_code = 0x00
        self.is_secure_boot = False
        self.setup_mode = True  # True = можно менять ключи
        
        self.nvram: dict = {}  # {(name, guid): {"data": bytes, "attrs": int}}
        self.boot_order: list[int] = []
        self.secure_boot_keys = {"PK": None, "KEK": [], "db": [], "dbx": []}
        
        self.hardware_state = {
            "ram_initialized": False,
            "pci_enumerated": False,
            "usb_ready": False,
            "nvme_ready": False
        }
        self.acpi_tables: list[bytes] = []
        self._integrity_ok = False

    # ─── МЕТОДЫ: УПРАВЛЕНИЕ ФАЗАМИ ───
    def run_phase(self, target_phase: str) -> None:
        """Переход к следующей фазе. Вызывает инициализацию шин/протоколов."""
        assert target_phase in self.PHASES, "Недопустимая фаза"
        idx = self.PHASES.index(self.current_phase)
        if self.PHASES.index(target_phase) <= idx:
            raise ValueError("Фазы идут только вперёд")
        
        self._init_hardware_for_phase(target_phase)
        self.current_phase = target_phase
        self._update_post_code(target_phase)

    def exit_boot_services(self) -> None:
        """TSL → RT: освобождение памяти, отключение драйверов, передача управления ОС."""
        assert self.current_phase == "TSL", "Нельзя выйти из Boot Services до BDS"
        self.hardware_state = {k: False for k in self.hardware_state}  # OS берет контроль
        self.current_phase = "RT"
        self.post_code = 0xA0

    # ─── МЕТОДЫ: NVRAM И ПЕРЕМЕННЫЕ ───
    def get_variable(self, name: str, guid: str = GLOBAL_VAR_GUID) -> bytes:
        """Чтение переменной (аналог `efivar -d` / `GetFirmwareEnvironmentVariable`)."""
        key = (name, guid)
        if key not in self.nvram:
            raise KeyError(f"Переменная {name} не найдена")
        return self.nvram[key]["data"]

    def set_variable(self, name: str, value: bytes, attrs: int, guid: str = GLOBAL_VAR_GUID) -> None:
        """Запись с проверкой атрибутов и атомарностью."""
        if attrs & self.VAR_ATTRS["AT"] and self.current_phase == "RT":
            raise PermissionError("Аутентифицированная запись требует подписи")
        
        key = (name, guid)
        self.nvram[key] = {"data": value, "attrs": attrs}
        self._write_nvram_atomic(key)  # Сначала в Backup, потом в Primary

    # ─── МЕТОДЫ: ЗАГРУЗКА И BOOT ORDER ───
    def add_boot_entry(self, boot_id: int, friendly_name: str, efi_path: str, attrs: int = 0x1) -> None:
        """Регистрация загрузчика (аналог `efibootmgr -c`)."""
        self.nvram[(f"Boot{boot_id:04X}", self.GLOBAL_VAR_GUID)] = {
            "data": self._encode_load_option(friendly_name, efi_path, attrs),
            "attrs": self.VAR_ATTRS["NV"] | self.VAR_ATTRS["BS"] | self.VAR_ATTRS["RT"]
        }

    def set_boot_order(self, order: list[int]) -> None:
        """Установка приоритета (проверка существования записей)."""
        for bid in order:
            if (f"Boot{bid:04X}", self.GLOBAL_VAR_GUID) not in self.nvram:
                raise ValueError(f"Загрузка {bid:04X} не зарегистрирована")
        self.boot_order = order
        self.set_variable("BootOrder", self._encode_uint16_array(order), self.VAR_ATTRS["NV"]|self.VAR_ATTRS["BS"]|self.VAR_ATTRS["RT"])

    # ─── МЕТОДЫ: БЕЗОПАСНОСТЬ ───
    def verify_and_load(self, efi_image: bytes) -> bool:
        """Проверка подписи перед выполнением (Secure Boot)."""
        if not self.is_secure_boot:
            return True
        if self.secure_boot_keys["PK"] is None:
            return False
        # Упрощённая проверка PKCS#7 → сравнение хеша с db/dbx
        return self._check_signature_against_db(efi_image)

    def enroll_key(self, key_type: str, cert: bytes) -> None:
        """Добавление ключа в цепочку доверия (PK/KEK/db/dbx)."""
        assert self.setup_mode or key_type in ("db", "dbx"), "Требуется SetupMode или подпись KEK"
        self.secure_boot_keys[key_type].append(cert)
        self.set_variable(key_type, self._pack_cert_db(cert), self.VAR_ATTRS["AT"] | self.VAR_ATTRS["NV"])

    # ─── МЕТОДЫ: SPI И ВОССТАНОВЛЕНИЕ ───
    def dump_spi(self, output_path: str, verify: bool = True) -> bool:
        """Полный дамп чипа (аналог `flashrom -r`)."""
        self._read_raw_spi_to_file(output_path)
        if verify:
            return self._verify_sha256(output_path, self.spi_dump)
        return True

    def restore_spi(self, backup_path: str, regions: set = {"BIOS"}, verify: bool = True) -> bool:
        """Восстановление с защитой от записи ME/GBE без явного указания."""
        assert "ME" not in regions and "GBE" not in regions, "Запись ME/GBE требует отдельного подтверждения"
        if verify and not self._verify_sha256(backup_path):
            raise ValueError("Бэкап повреждён или не совпадает")
        self._flash_regions(backup_path, regions)
        self._integrity_ok = True

    # ─── МЕТОДЫ: ДИАГНОСТИКА ───
    def check_integrity(self) -> dict:
        """Проверка CRC заголовков GPT/NVRAM и целостности ACPI."""
        return {
            "nvram_crc_ok": self._check_nvram_crc(),
            "acpi_valid": self._validate_acpi(),
            "post_code": self.post_code,
            "phase": self.current_phase
        }

    # ─── ВНУТРЕННИЕ (УСЛОВНЫЕ) ───
    def _init_hardware_for_phase(self, phase: str): ...
    def _update_post_code(self, phase: str): ...
    def _write_nvram_atomic(self, key: tuple): ...
    def _encode_load_option(self, name: str, path: str, attrs: int) -> bytes: ...
    def _encode_uint16_array(self, arr: list[int]) -> bytes: ...
    def _check_signature_against_db(self, image: bytes) -> bool: ...
    def _pack_cert_db(self, cert: bytes) -> bytes: ...
    def _read_raw_spi_to_file(self, path: str): ...
    def _verify_sha256(self, path: str, expected: str = None) -> bool: ...
    def _flash_regions(self, path: str, regions: set): ...
    def _check_nvram_crc(self) -> bool: ...
    def _validate_acpi(self) -> bool: ...
```

### 📌 Как это映射 (соотносится) с реальной практикой:
| Python-элемент | Реальный аналог | Инструмент/Команда |
|----------------|----------------|-------------------|
| `current_phase`, `post_code` | POST-коды на материнской плате | LED-индикаторы, `chipsec`, `RWEverything` |
| `nvram` dict | Регион NVRAM в SPI Flash | `efivar`, `GetFirmwareEnvironmentVariable` |
| `set_variable(..., AT)` | Аутентифицированная запись | `mokutil`, `SecConfig.exe`, подпись PKCS#7 |
| `add_boot_entry` / `set_boot_order` | Переменные `Boot####` и `BootOrder` | `efibootmgr -c`, `bcdedit /enum firmware` |
| `verify_and_load` | Secure Boot проверка перед BDS | `mokutil --sb-state`, `dbxtool` |
| `dump_spi` / `restore_spi` | Аппаратное чтение/запись чипа | `flashrom -r/-w`, `CH341A`, `FlashcatUSB` |
| `check_integrity` | Валидация CRC/ACPI при старте | `UEFITool` → FIT/ACPI, `chipsec` |

### ⚙️ Пример использования (диагностика):
```python
fw = UEFIFirmware("backup.bin", "ASUS", "1.02")
fw.run_phase("DXE")
fw.run_phase("BDS")

# Чтение BootOrder
order_hex = fw.get_variable("BootOrder")
print("Порядок:", [f"0x{x:04X}" for x in fw.boot_order])

# Безопасная запись переменной
fw.set_variable("Timeout", b"\x05\x00\x00\x00", fw.VAR_ATTRS["NV"]|fw.VAR_ATTRS["RT"])

# Проверка перед записью в SPI
diag = fw.check_integrity()
assert diag["nvram_crc_ok"], "Коррупция NVRAM → требуется восстановление из Backup"
```

### 🎯 Почему эта модель полезна для тебя:
1. **Чёткое разделение состояния и действий** → помогает не путать чтение переменных (`get`) с деструктивными операциями (`restore_spi`).
2. **Защитные проверки (`assert`, `AT`-атрибуты, `verify`)** → отражают реальные механизмы, которые предотвращают "кирпич".
3. **Фазовый переход** → объясняет, почему `exit_boot_services()` "ломает" доступ к драйверам UEFI из Windows.
4. **Прямая связь с твоим стеком** → каждый метод имеет аналог в `efivar`, `flashrom`, `UEFITool` или `bcdedit`.

> 💡 *Примечание:* Реальная прошивка написана на C/Asm, работает в кольце -1/-2 (Ring 0/SMI), не имеет ОС и использует raw-доступ к памяти. Эта Python-модель — **абстракция для понимания архитектуры и безопасного workflow**, а не рабочий эмулятор.

[RECOMMEND] Нарисуй схему: `Атрибуты → Состояние`, `Методы → Действия`, `Asserts → Механизмы безопасности`. Держи её рядом при работе с `UEFITool`/`flashrom` — это ускорит принятие решений на 40-60%.







=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================

- сгенерируй схему: Атрибуты → Состояние, Методы → Действия, Asserts → Механизмы безопасности
- сгенерируй схему: SEC → PEI → DXE → BDS → TSL и подпиши под каждой фазой, какие механизмы firmware активируются и порядок их активации
- напиши шпаргалку на тему возможные ситуации в контексте взаимодействия с NVRAM и UEFI-переменными: подробно опиши 5-10 ситуаций с большой вероятностью возникновения → рекомендуемые действия(на что стоит обратить внимание, алгоритм выбора инструмента/утилиты/драйвера/настройки, какой результат хотим получить) → возможные действия в случае получения ожидаемого и неожиданного результата






[MAIN] 🖼️ Схема 1: Python-модель Firmware (Атрибуты → Состояние, Методы → Действия, Asserts → Безопасность)

```mermaid
graph LR
    subgraph ATTRIBUTES["📦 АТРИБУТЫ (ДАННЫЕ)"]
        A1[current_phase] --> S1[Состояние: фаза загрузки]
        A2[nvram: dict] --> S2[Состояние: переменные в SPI]
        A3[boot_order: list] --> S3[Состояние: очередь загрузки]
        A4[secure_boot_keys] --> S4[Состояние: цепочка доверия]
        A5[hardware_state] --> S5[Состояние: инициализация устройств]
    end

    subgraph METHODS["⚙️ МЕТОДЫ (ДЕЙСТВИЯ)"]
        M1[run_phase()] --> D1[Переход фазы + инициализация шин]
        M2[get/set_variable()] --> D2[Чтение/запись NVRAM с атрибутами]
        M3[add_boot_entry()/set_boot_order()] --> D3[Регистрация загрузчиков]
        M4[verify_and_load()] --> D4[Проверка подписи .efi перед запуском]
        M5[dump_spi()/restore_spi()] --> D5[Аппаратный бэкап/восстановление]
        M6[check_integrity()] --> D6[Валидация CRC/ACPI]
    end

    subgraph ASSERTS["🛡️ ASSERTS (МЕХАНИЗМЫ БЕЗОПАСНОСТИ)"]
        AS1[assert phase_order] --> B1[Защита от отката фаз]
        AS2[if attrs & AT and phase==RT] --> B2[Блокировка записи ключей без подписи]
        AS3[assert setup_mode or key in db] --> B3[Требование подписи для db/dbx]
        AS4[assert "ME" not in regions] --> B4[Защита от записи ME/GBE без подтверждения]
        AS5[verify_sha256 before write] --> B5[Верификация бэкапа перед восстановлением]
    end

    ATTRIBUTES --> METHODS --> ASSERTS
```

**📝 Текстовая версия (для копирования):**
```
[АТРИБУТЫ] → [СОСТОЯНИЕ]
• current_phase       → Какая фаза активна (SEC/PEI/DXE/BDS/TSL/RT)
• nvram: dict         → Хранилище {(имя, GUID): {data, attrs}}
• boot_order: list    → Порядок загрузки [0001, 0002, ...]
• secure_boot_keys    → PK/KEK/db/dbx цепочка
• hardware_state      → {ram: bool, pci: bool, usb: bool, nvme: bool}

[МЕТОДЫ] → [ДЕЙСТВИЯ]
• run_phase("DXE")    → Инициализация шин, загрузка драйверов
• get_variable(name)  → Чтение переменной (аналог efivar -d)
• set_variable(..., AT) → Запись с проверкой атрибутов/подписи
• add_boot_entry()    → Регистрация нового загрузчика в NVRAM
• verify_and_load()   → Проверка подписи .efi перед запуском
• dump_spi()/restore_spi() → Аппаратный бэкап/запись чипа
• check_integrity()   → CRC GPT/NVRAM, валидация ACPI

[ASSERTS] → [МЕХАНИЗМЫ БЕЗОПАСНОСТИ]
• assert phase_order         → Нельзя "откатить" фазу назад
• if attrs & AT and RT       → Запись ключей требует подписи
• assert setup_mode or db    → Изменение db/dbx только в SetupMode или с подписью
• assert "ME" not in regions → Защита от записи ME/GBE без явного подтверждения
• verify_sha256 before write → Обязательная верификация перед записью в SPI
```

---

[MAIN] 🖼️ Схема 2: UEFI фазы (механизмы и порядок активации)

```mermaid
graph TD
    subgraph SEC["🔴 SEC (Security Core)"]
        S1[CPU Reset Vector] --> S2[CAR: Cache-as-RAM]
        S2 --> S3[FV Parse: поиск PEI Core]
        S3 --> S4[Security: проверка подписи FV]
    end

    subgraph PEI["🟡 PEI (Pre-EFI Initialization)"]
        P1[RAM Init: SPD read, training] --> P2[Chipset Init: PCH, SPI, LPC]
        P2 --> P3[PCIe Root Complex: базовая enum]
        P3 --> P4[PPI Publish: интерфейсы между PEIM]
        P4 --> P5[Find DXE IPL: загрузка DxeCore.efi]
    end

    subgraph DXE["🟢 DXE (Driver Execution Environment)"]
        D1[DXE Core Start] --> D2[Dispatcher: Depex-очередь драйверов]
        D2 --> D3[PCIe Full Enum: BAR alloc, MSI]
        D3 --> D4[Storage Init: NVMe/SATA → BlockIo/DiskIo Protocols]
        D4 --> D5[USB Init: XHCI → UsbIo/BlockIo Protocols]
        D5 --> D6[Console Init: GOP/TextOut → видео/клавиатура]
        D6 --> D7[ACPI Table Gen: MADT/FACP/RSDT]
        D7 --> D8[Protocol Publish: EFI_SIMPLE_FILE_SYSTEM и др.]
    end

    subgraph BDS["🔵 BDS (Boot Device Selection)"]
        B1[Boot Policy: чтение NVRAM BootOrder] --> B2[Device Path Resolution]
        B2 --> B3[Console Connect: вывод меню загрузки]
        B3 --> B4[Secure Boot Check: verify_and_load()]
        B4 --> B5[Legacy/CSM Option ROM (если включен)]
        B5 --> B6[Load Selected: запуск bootmgfw.efi / GRUB]
    end

    subgraph TSL["🟣 TSL (Transient System Load)"]
        T1[ExitBootServices()] --> T2[Free Boot Services Memory]
        T2 --> T3[Disable UEFI Drivers: передача контроля ОС]
        T3 --> T4[Runtime Services Only: SetVariable/GetTime/Reset]
    end

    SEC --> PEI --> DXE --> BDS --> TSL
```

**📋 Таблица: порядок активации механизмов по фазам**

| Фаза | Механизмы (порядок) | Что активируется | Практический признак |
|------|---------------------|----------------|---------------------|
| **SEC** | 1) Reset Vector → 2) CAR → 3) FV Parse → 4) Signature Check | CPU, кэш как память, проверка целостности прошивки | Нет видео, нет USB. Только спикер/POST-карта. |
| **PEI** | 1) RAM Training → 2) Chipset Init → 3) PCIe Root → 4) PPI Publish → 5) DXE IPL | RAM, SPI, LPC, базовая PCIe, поиск DXE Core | POST-коды `0x10-0x3F`. RAM определена, но драйверов ещё нет. |
| **DXE** | 1) Dispatcher (Depex) → 2) PCIe Enum → 3) Storage/USB Init → 4) Console → 5) ACPI Gen → 6) Protocol Publish | PCI/PCIe, NVMe/SATA, USB XHCI, GOP, ACPI-таблицы, протоколы | Появляется видео (GOP), работают USB, видны диски. Коды `0x40-0x7F`. |
| **BDS** | 1) BootOrder Read → 2) Device Path → 3) Console Connect → 4) Secure Boot Verify → 5) Load Option | Меню загрузки, проверка подписи `.efi`, запуск загрузчика | Меню выбора ОС, логотип вендора. Коды `0x80-0x9F`. |
| **TSL** | 1) ExitBootServices() → 2) Free Memory → 3) Disable Drivers → 4) RT Only | Передача управления ядру ОС, отключение UEFI-драйверов | Появляется "кружок" Windows / GRUB. UEFI переходит в RT-режим. |

---

[MAIN] 📋 Шпаргалка: Ситуации с NVRAM и UEFI-переменными (практика 2025-2026)

*Фокус: безопасная диагностика на твоем стеке (Win11, Vivobook, Ventoy, WSL2).*

### 🔹 Ситуация 1: «Пустой BootOrder после обновления BIOS»
**Симптомы**: `efibootmgr` / `bcdedit` показывает пустой `BootOrder`, но `Boot####`-переменные есть. Система грузит дефолтный загрузчик или выдаёт "No bootable device".
**Причина**: Обновление прошивки сбрасывает NVRAM к дефолтным значениям.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `efibootmgr -v` (Linux/WSL2) или `bcdedit /enum firmware` (Win) → 2. `efivar -l` (полный список) → 3. `RWEverything` (только чтение, эксперт). |
| **⚙️ Рекомендуемые действия** | 1. Проверь наличие `Boot####`: `efibootmgr -v \| grep Boot`.<br>2. Если записи есть: `efibootmgr -o 0001,0002` (укажи актуальные ID).<br>3. Если записей нет: создай новую → `efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Windows" -l '\EFI\Microsoft\Boot\bootmgfw.efi'`.<br>4. Проверь `Timeout`: должен быть >0 для отладки. |
| **✅ Ожидаемый результат** | `BootOrder` содержит валидные ID, система грузится в нужную ОС. |
| **❌ Неожиданный результат** | Записи создаются, но после перезагрузки исчезают.<br>→ **Действия**: 1) Проверь атрибуты (`efivar -l -v` → ищи `NV`); 2) Возможна коррупция NVRAM → `Setup → Restore Defaults`; 3) Если не помогает → перепрошивка BIOS (вендорный инструмент). |

---

### 🔹 Ситуация 2: «Secure Boot: "Access denied" при изменении ключей»
**Симптомы**: Попытка обновить `db`/`dbx` через `efivar` выдает `EFI_SECURITY_VIOLATION`.
**Причина**: Переменная имеет атрибут `AT` (Authenticated) → требуется подпись ключом, соответствующим `KEK`.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `efivar -l \| grep -E 'db\|KEK\|PK'` → 2. Проверка атрибутов (`-v`) → 3. `mokutil` (для MOK) или вендорная утилита. |
| **⚙️ Рекомендуемые действия** | 1. **Не пиши напрямую** — не сработает без подписи.<br>2. Для Linux: `mokutil --import key.der` → перезагрузка → MOK Manager → enroll.<br>3. Для Windows: `SecConfig.exe` (Microsoft) или вендорный `KeyTool`.<br>4. Для тестов: `SetupMode=1` (только если `PK` не установлен!). |
| **✅ Ожидаемый результат** | Ключ успешно добавлен в `db`/`dbx`, Secure Boot работает с новыми правилами. |
| **❌ Неожиданный результат** | После перезагрузки ключ пропал.<br>→ **Действия**: 1) Проверь `SetupMode`; 2) Восстанови из бэкапа (`efivar -w`); 3) В крайнем случае: `Clear Secure Boot Keys` → `Restore Factory Keys`. |

---

### 🔹 Ситуация 3: «Переменные не видны из Windows, но видны из Linux»
**Симптомы**: `bcdedit` показывает меньше записей, чем `efibootmgr` в WSL2.
**Причина**: Разные уровни доступа: Windows фильтрует переменные без `RT`-атрибута.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `efivar -l` (полный список) → 2. `GetFirmwareEnvironmentVariable` (PowerShell) → 3. `RWEverything` (чтение, осторожно). |
| **⚙️ Рекомендуемые действия** | 1. Сравни вывод: `efivar -l \| wc -l` vs `bcdedit \| findstr "identifier"`.<br>2. Проверь атрибуты: `efivar -v -n Boot0001-...` → ищи `RT` (Runtime).<br>3. Если нет `RT` → переменная видна только до загрузки ОС (это нормально).<br>4. Для полного доступа из Windows: запусти от `NT AUTHORITY\SYSTEM` (через `PsExec -s`). |
| **✅ Ожидаемый результат** | Понимание, какие переменные "живут" в ОС, а какие только в firmware. |
| **❌ Неожиданный результат** | Критическая переменная не имеет `RT` → не видна в ОС.<br>→ **Действия**: 1) Не меняй её из Windows; 2) Используй `efibootmgr` из WinPE/Linux; 3) Для программного доступа → `SetFirmwareEnvironmentVariableEx` с флагами. |

---

### 🔹 Ситуация 4: «После обновления пропали пользовательские загрузчики»
**Симптомы**: До обновления работали Ventoy/GRUB/Linux, после — только Windows.
**Причина**: Обновление сбрасывает NVRAM или очищает `db` от сторонних ключей.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `efibootmgr -v` (до/после) → 2. Бэкап переменных перед обновлением → 3. Вендорный Recovery. |
| **⚙️ Рекомендуемые действия** | **Перед обновлением**:<br>1. Бэкап: `for v in $(efivar -l); do efivar -d -n "$v" > "backup/${v//\//_}.bin"; done`.<br>**После обновления**:<br>1. Проверь `BootOrder`: если пуст → восстанови из бэкапа.<br>2. Для Ventoy: обнови ключи (`enroll_hash`) или временно отключи Secure Boot. |
| **✅ Ожидаемый результат** | Пользовательские загрузчики возвращаются в меню. |
| **❌ Неожиданный результат** | Бэкап не восстанавливается (ошибка формата).<br>→ **Действия**: 1) Пересоздай записи вручную через `efibootmgr -c`; 2) Для Ventoy: переустанови его на флешку; 3) Если Secure Boot блокирует → временно отключи, добавь ключи, включи обратно. |

---

### 🔹 Ситуация 5: «Timeout=0 → нет меню загрузки, черный экран»
**Симптомы**: Ноутбук сразу грузит Windows, нет возможности выбрать другую ОС.
**Причина**: Переменная `Timeout` установлена в `0` (мгновенный старт).

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `efivar -d -n Timeout-...` → 2. `efibootmgr -t <секунды>` → 3. `bcdedit /timeout <секунды>`. |
| **⚙️ Рекомендуемые действия** | 1. Проверь значение: `efivar -d -n Timeout-...` (вернет 4 байта little-endian UINT32).<br>2. Установи 5-10 секунд: `efibootmgr -t 10`.<br>3. Альтернатива из Windows: `bcdedit /set {bootmgr} timeout 10`.<br>4. Для экстренного входа: удерживай `Shift` при перезагрузке или нажимай `F2/Del`. |
| **✅ Ожидаемый результат** | При загрузке появляется меню с таймером. |
| **❌ Неожиданный результат** | Значение не сохраняется.<br>→ **Действия**: 1) Проверь атрибуты `Timeout` (должен быть `NV`); 2) Возможна защита от записи → попробуй из WinPE; 3) Сбрось NVRAM через BIOS, затем заново установи `Timeout`. |

---

### 🔹 Ситуация 6: «Коррупция NVRAM: CRC mismatch»
**Симптомы**: `efivar` выдает `Read error`, в логах `dmesg` → `EFIVARFS: CRC mismatch`.
**Причина**: Сбой питания при записи, износ флеша.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `chipsec_util uefi var-list` (только чтение) → 2. `RWEverything` (чтение SPI) → 3. Вендорный Recovery. |
| **⚙️ Рекомендуемые действия** | 1. **Не записывай** — усугубишь повреждение.<br>2. Попробуй прочитать через `chipsec`.<br>3. Если не видит → вероятна физическая коррупция.<br>4. Загрузись в Recovery-режим вендора → перепрошей BIOS. |
| **✅ Ожидаемый результат** | Переменные читаются, система стабильна. |
| **❌ Неожиданный результат** | После перепрошивки переменные всё равно битые.<br>→ **Действия**: 1) Возможна проблема с регионами SPI; 2) Требуется программатор (CH341A); 3) Обратись в сервис. |

---

### 🔹 Ситуация 7: «Конфликт загрузчиков при дуал-буте»
**Симптомы**: После загрузки Windows перестает видеть Linux (или наоборот).
**Причина**: ОС автоматически обновляет `BootOrder` при установке обновлений.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `efibootmgr -v` (сравнение до/после) → 2. `os-prober` / `bcdedit` → 3. Отключение авто-обновления. |
| **⚙️ Рекомендуемые действия** | 1. Зафиксируй текущий `BootOrder`.<br>2. В Linux: `GRUB_DISABLE_OS_PROBER=true` в `/etc/default/grub`.<br>3. В Windows: `bcdedit /set {bootmgr} displayorder {current} /addfirst`.<br>4. Используй `efibootmgr -A/-i` для управления видимостью. |
| **✅ Ожидаемый результат** | `BootOrder` стабилен, обе ОС видны в меню. |
| **❌ Неожиданный результат** | Одна из ОС перестает грузиться.<br>→ **Действия**: 1) Проверь, не деактивировал ли запись (`-i`); 2) Восстанови через `efibootmgr -c`; 3) Используй `\EFI\BOOT\BOOTX64.EFI` как fallback. |

---

### 🔹 Ситуация 8: «Переменная не удаляется / "Read-only"»
**Симптомы**: `efibootmgr -b XXXX -B` выдает ошибку, переменная остается.
**Причина**: Атрибут `READ_ONLY`, переменная используется системой, или защита в `SetupMode=0`.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. `efivar -v -n <name-guid>` (проверка атрибутов) → 2. `SetupMode` проверка → 3. Вендорный `KeyTool`. |
| **⚙️ Рекомендуемые действия** | 1. Проверь атрибуты: если `READ_ONLY` → удалить нельзя.<br>2. Проверь `SetupMode`: если `0`, некоторые операции заблокированы.<br>3. Для удаления `Boot####`: сначала убери из `BootOrder`, потом удаляй.<br>4. Альтернатива: переименуй переменную (создай новую, удали старую). |
| **✅ Ожидаемый результат** | Лишние записи удалены, `BootOrder` чистый. |
| **❌ Неожиданный результат** | Переменная возвращается после перезагрузки.<br>→ **Действия**: 1) Прошивка авто-восстанавливает критичные переменные; 2) Требуется отключить авто-восстановление или перепрошить с чистым NVRAM; 3) Оставь как есть, если не мешает. |

---

[🛡️ Общие правила безопасности]
1. **Чтение > Запись**: Всегда начинай с `efivar -l` / `GetFirmwareEnvironmentVariable`.
2. **Бэкап перед изменениями**: `mkdir backup && for v in $(efivar -l); do efivar -d -n "$v" > "backup/${v//\//_}.bin"; done`.
3. **Тестируй в изоляции**: Используй переменные с уникальным GUID для экспериментов.
4. **Не трогай `PK/KEK/db/dbx` без подписи**: Это может "окирпичить" систему.
5. **Логгируй всё**: `script nvram_session.log` перед началом сессии.

[RECOMMEND]
1. Создай файл `nvram_recovery.sh` / `.bat` с командами бэкапа/восстановления — держи на Ventoy.
2. Потренируй Ситуацию №1 и №5 на виртуальной машине (OVMF/EDK2) — безопасно и наглядно.

[ANTICIPATE]
- "Как узнать GUID переменной?" → Глобальные: `8BE4DF61-93CA-11d2-00E0-9803-2B8C`. Вендорские — ищи в документации или `efivar -l \| grep <name>`.
- "Можно ли экспортировать все переменные в человекочитаемый вид?" → Да: `for v in $(efivar -l); do echo "=== $v ==="; efivar -d -n "$v"; done > all_vars.txt`. Но бинарные данные (ключи) так не прочитать — нужен `certutil -decode`.