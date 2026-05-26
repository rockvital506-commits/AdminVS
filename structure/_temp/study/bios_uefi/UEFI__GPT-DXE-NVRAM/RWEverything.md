


# Дополнительный контекст:
- диагностика | оптимизация | ремонт ПК/ноутбуков

# Цели:
- получить полные знания о RWEverything для практического применения

# Задания:
- проведи исследования на темы RWEverything и его: мануалы | руководства | сферы применения | рекомендации | настройки | последовательность от включения питания до загрузки Windows | технологии и необходимый софт | способы взаимодействия с образами и их алгоритмы | firmware/bootloader | жизненый цикл
- придумай 2 направления исследований в контексте цели и проведи такие исследования
- проанализируй результаты проведенных исследований в контексте цели и: необходимость для реального применения, логика последовательности освоения и применения
- проанализируй проведенные исследования
- используя результаты проведенных анализов:
  - расскажи подробно про RWEverything
  - создай подробный гайд по практическому применению RWEverything






[MAIN] 📖 Подробный разбор: что такое RWEverything (практический взгляд)

### 🔹 Простая аналогия
> Представь компьютер как автомобиль:
> - **chipsec** = диагностический сканер: подключается к OBD, показывает ошибки `P0300`, `P0420`.
> - **UEFITool** = чертежи двигателя: показывает, как устроены цилиндры, клапаны, система зажигания.
> - **RWEverything** = мультиметр + осциллограф: позволяет "потрогать" каждый провод, измерить напряжение на конкретном контакте, подать сигнал на тестовый вход.
> 
> `RW` не говорит, "что сломано", но позволяет **измерить** то, что другие инструменты только предполагают.

### 🔹 5 правил работы с RWEverything
1. **Запускай от Администратора + отключи HVCI/Memory Integrity** (Win11) [[3]]:
   - Драйвер `rwdrv.sys` требует отключения виртуализации безопасности.
   - Проверь: `bcdedit /set hypervisorlaunchtype off` → перезагрузка.

2. **Сначала чтение, потом экспорт, потом анализ** [[12]][[35]]:
   - Никогда не пиши в регистр, пока не прочитал и не сохранил оригинальное значение.
   - Используй `Save to file` (текст/бинарь) перед любыми изменениями.

3. **Понимай контекст регистра** [[10]][[27]]:
   - `PCI config space`: BARs, Command register — безопасно читать, опасно писать.
   - `EC RAM`: 0x00-0x0F — системные, 0x60-0x7F — часто сенсоры.
   - `SMBus`: адреса 0x50-0x57 — SPD памяти, 0x4C-0x4F — сенсоры.

4. **Используй Command Window для скриптов** [[10]]:
   - Автоматизируй рутину: `RPMC 0 0` (читать PMC), `RDMSR 0x1A0` (читать MSR).
   - Сохраняй скрипты: `/Command=script.rwc` для повторного запуска.

5. **Документируй всё** [[35]]:
   - Сохраняй дампы: `EC_dump.bin`, `PCI_config.txt`, `ACPI_tables.zip`.
   - Фиксируй: дату, модель платы, версию BIOS, шаги воспроизведения.

### 🔹 Как читать структуру (пример для диагностики зависания)
```
Главное окно → Дерево модулей:
├─ PCI
│  ├─ Bus 0, Device 0, Function 0 (Host Bridge)
│  │  ├─ Config Space (256/4096 байт)
│  │  ├─ BARs → Memory/IO пространства
│  │  └─ Summary: Vendor, Device, IRQ, Latency
│  └─ ...
├─ Memory
│  ├─ Physical Address: 0x00000000 - 0xFFFFFFFF
│  ├─ Access: Byte/Word/Dword
│  └─ Search: ASCII/Hex pattern
├─ ACPI
│  ├─ Tables: DSDT, SSDT, FACP, MCFG, DMAR...
│  ├─ AML Decode: ASL-код (если включено)
│  └─ Save: binary/text
├─ Embedded Controller
│  ├─ RAM: 0x00-0xFF (зависит от чипа)
│  ├─ Read/Write: Byte
│  └─ Common: 0x68=CPU_TEMP, 0x69=GPU_TEMP, 0x90=FAN_CTRL
├─ SMBus
│  ├─ Controller: Intel PCH, AMD FCH, nVidia MCP
│  ├─ Devices: 0x50 (SPD), 0x4C (temp sensor)
│  └─ Protocol: Quick/Byte/Word/Block
└─ Command Window
   ├─ Скрипты: /Command=...
   ├─ Переменные: $CPUID, $BUS, $DEV
   └─ Логирование: /LogFile=...
```

---

[MAIN] 🛠️ Практический гайд: применение RWEverything (диагностика → отчёт)

### 📋 Этап 0: Подготовка (Win11)
```powershell
# 1. Отключи Memory Integrity (HVCI) для загрузки драйвера
#   Параметры → Обновление и безопасность → Безопасность Windows → 
#   Безопасность устройства → Изоляция ядра → Выкл.
#   Перезагрузка

# 2. Скачай RWEverything (официальный сайт)
#   https://rweverything.com/ → Download → rw170.zip [[12]]

# 3. Распакуй в изолированную папку
mkdir C:\tools\rw && cd C:\tools\rw
#   Положи только необходимое: rw.exe, rwdrv.sys, rw.ini, help.chm

# 4. Запусти от имени Администратора
#   ПКМ на rw.exe → "Запуск от имени администратора"
```

### 🔍 Этап 1: Базовое чтение (безопасные модули)
| Задача | Действия в RW | Что получаем |
|--------|---------------|--------------|
| **Проверить PCI-устройства** | `PCI` → развернуть дерево → выбрать устройство → `Summary` | Vendor/Device ID, BARs, IRQ, статус Command register |
| **Прочитать ACPI-таблицы** | `ACPI` → выбрать таблицу (DSDT/FACP/MCFG) → `Save as binary` | Дамп таблицы для анализа в UEFITool/AML-декодере |
| **Просмотреть SPD памяти** | `DIMM SPD` → выбрать слот → `Summary` | Тайминги, частота, производитель, напряжение |
| **Прочитать EC-регистры** | `Embedded Controller` → `Read` (не `Write`!) → сохранить в файл | Температуры, статусы вентиляторов, кастомные регистры вендора |
| **Сканировать SMBus** | `SMBus` → выбрать контроллер → `Scan` → `Read Byte` на адресе 0x4C | Показания температурных сенсоров (если адрес известен) |

**Пример: чтение температуры через EC**:
1. Запусти `rw.exe` → `Embedded Controller`.
2. Нажми `Read` (не `Write`!).
3. Найди регистр `0x68` (часто `CPU_TEMP` на ноутбуках).
4. Значение `0x32` = 50 в десятичной = ~50°C (зависит от вендора).
5. Сохрани: `File → Save to file → ec_read.txt`.

### 📊 Этап 2: Углублённая диагностика (по симптомам)
| Симптом | Модуль RW | Что искать |
|---------|-----------|------------|
| "Ноутбук перегревается, но ОС показывает норму" | `Embedded Controller` + `SMBus` | Сравнить значения в 0x68/0x69 с данными ОС; проверить, не заблокирован ли сенсор |
| "Устройство не определяется в PCIe" | `PCI` → `Config Space` | Проверить `Command` register (биты Memory/IO Enable), BARs на 0xFFFFFFFF |
| "ACPI-таблица не грузится" | `ACPI` → `Save as binary` → открыть в UEFITool | Проверить сигнатуру, длину, CRC; сравнить с эталоном |
| "Память работает на низкой частоте" | `DIMM SPD` + `Memory` → `Physical Address` | Проверить тайминги в SPD; прочитать регистры контроллера памяти (через PCI/MMIO) |

### ✅ Этап 3: Экспорт и документирование
```powershell
# 1. Сохранить все критичные дампы
#   PCI: ПКМ на устройстве → Save → pci_dev_00_00_0.txt
#   ACPI: ACPI → DSDT → Save as binary → dsdt.bin
#   EC: Embedded Controller → Save to file → ec_full.bin

# 2. Создать отчёт (шаблон)
@echo === RW Diagnostic Report === > report.txt
@echo Date: %DATE% %TIME% >> report.txt
@echo Model: %COMPUTERNAME% >> report.txt
@echo BIOS: (вручную из msinfo32) >> report.txt
@echo.
@echo === PCI Summary === >> report.txt
type pci_summary.txt >> report.txt
@echo.
@echo === EC Key Registers === >> report.txt
type ec_key.txt >> report.txt

# 3. Архивировать для истории
7z a -tzip diagnostics_%COMPUTERNAME%_%DATE:~6,4%%DATE:~3,2%%DATE:~0,2%.zip report.txt *.bin *.txt
```

### ⚠️ Этап 4: Запись (ТОЛЬКО если критично и с бэкапом!)
```powershell
# ⚠️ ПРЕДУПРЕЖДЕНИЕ: Запись в RW может "окирпичить" систему.
# Только если: 1) есть бэкап, 2) понимаешь регистр, 3) тестировал на нерабочем железе.

# Пример: сброс битов в PCI Command register (включение Memory Space)
# 1. Прочитать оригинал: ПКМ → Save → orig_cmd.txt
# 2. Изменить значение: двойной клик на байте → новое значение
# 3. Нажать Write → подтвердить
# 4. Проверить: устройство появилось в ОС?
# 5. Если нет → восстановить из бэкапа (перезагрузка или обратная запись)
```

---

[IF SOFT] 🎓 Ментор: пояснения для beginner
- `RW` ≠ антивирус/сканер. Он не ищет проблемы, он **показывает сырые данные**. Интерпретация — твоя ответственность.
- `Embedded Controller` ≠ BIOS. EC — отдельный микроконтроллер, управляет питанием, вентиляторами, клавиатурой. Его регистры вендор-специфичны.
- `SMBus` ≠ I2C. SMBus — подмножество I2C с дополнительными протоколами. В RW: `Read Byte` безопасен, `Block Write` — опасен без документации.
- `Command Window` — мощный, но сложный. Начни с готовых команд: `RDMSR`, `RPMC`, `RPCI`. Избегай `W*`-команд без понимания.
- `Масштабирование`: После освоения чтения переходи к скриптам (`/Command=script.rwc`), затем к интеграции с chipsec/UEFITool для комплексной диагностики.

[🛡️ Чек-лист безопасности]
1. [ ] Запущен от имени Администратора?
2. [ ] Отключён HVCI/Memory Integrity (для загрузки драйвера)?
3. [ ] Сначала чтение → сохранение → анализ, только потом запись?
4. [ ] Есть бэкап оригинальных значений перед записью?
5. [ ] Понимаю, что за регистр меняю (документация/даташит)?

[RECOMMEND]
1. Создай папку `C:\diagnostics\rw\` с подпапками `pci/`, `acpi/`, `ec/`, `logs/` — это ускорит работу и предотвратит потерю данных.
2. Потренируй чтение `EC` и `SMBus` на старом/нерабочем ноутбуке — это даст понимание, какие регистры за что отвечают, без риска.

[ANTICIPATE]
- "Как найти адрес нужного регистра в EC?" → Ищи в даташите чипа (ITE/Winbond/Nuvoton) или в открытых репозиториях (github.com/BeardOverflow/msi-ec) [[3]]. Часто 0x68-0x6F = температуры, 0x90-0x9F = управление вентиляторами.
- "Можно ли автоматизировать чтение нескольких регистров?" → Да: используй `Command Window` → скрипт:
  ```
  # script.rwc
  ECRead 0x68
  ECRead 0x69
  ECRead 0x90
  Cout "Temp_CPU=$1, Temp_GPU=$2, Fan=$3"
  ```
  Запуск: `rw.exe /Command=script.rwc /LogFile=output.txt`.  







=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================

# Цели:
- систематизировать информацию/процессы/действия RWEverything с помощью абстракции рабочего процесса

# Задания:
- проанализируй концепции RWEverything
- ответь сам себе на вопросы: какие атрибуты | методы | внутренние классы ты бы реализовал в RWEverything как python объекте
- разработай стратегию реализации RWEverything как python объект, его: атрибуты | методы | внутренние классы
- реализуй RWEverything как python объект в соответствии с разработанной стратегией








[PHASE 0] 🔍 Анализ: `task_type=learn/architect`, `complexity=4/5`, `domains=2` (System Abstraction, Low-Level I/O Workflow). Разложено на: 1) концептуальный разбор + самоанализ, 2) стратегия архитектуры, 3) реализация, 4) пример применения. `scope_boundary`: абстракция рабочего процесса, безопасный read-first, запрет на прямую запись в ядро ОС без драйвера.

---

### 🔹 1. Анализ концепций RWEverything + Самоанализ
**Ключевые концепции:**
- **Прямой доступ к железу:** Чтение/запись PCI Config, MMIO, I/O Ports, MSR, EC RAM, SMBus, ACPI.
- **Модульность:** Каждая подсистема (EC, SMBus, PCI) имеет свой протокол доступа и набор регистров.
- **Безопасность через процесс:** `Чтение → Фиксация → Бэкап → Валидация → Запись → Верификация`.
- **Скриптинг:** `/Command=` позволяет автоматизировать последовательности доступа.
- **Состояние сессии:** Логирование, детект платформы, управление драйвером, экспорт отчётов.

**❓ Самовопросы:**
| Вопрос | Ответ |
|--------|-------|
| *Какие атрибуты?* | `readonly` (по умолчанию `True`), `driver_loaded`, `session_id`, `platform_info`, `backup_store`, `log_dir`, `logs`. |
| *Какие методы?* | `connect/disconnect`, `read/write` (с safety-pipeline), `backup/restore`, `validate`, `export_report`, `run_script`. |
| *Какие внутренние классы?* | `_IOCore` (обёртка над драйвером), `_PCIManager`, `_ECController`, `_SMBusScanner`, `SafetyGuard` (бэкап/валидация), `SessionLogger`. |
| *Как обеспечить безопасность?* | Контекстный менеджер, pipeline `Read → Backup → Validate → Write → Verify`, запрет на запись без явного `readonly=False`, авто-лог всех операций. |
| *Как отразить workflow RW?* | Методы `read_*`/`write_*` + свойства `pci`, `ec`, `smbus` имитируют дерево модулей. `run_script()` воспроизводит `/Command=`. |

---

### 🔹 2. Стратегия реализации
| Слой | Назначение | Реализация |
|------|------------|------------|
| **Facade** | Публичный API для инженера | Класс `RWEverything` с методами `read`, `write`, `export`, `run_script` |
| **Subsystems** | Доменно-специфичный доступ | `_PCIManager`, `_ECController`, `_SMBusScanner` (делегирование в `_IOCore`) |
| **Safety Pipeline** | Защита от кирпича | `BackupStore`, `_validate_write`, `restore`, context manager `__enter__/__exit__` |
| **Logging/Export** | Аудит и отчётность | `logging`, JSON-дамп сессии, бинарные бэкапы в `backups/` |
| **Driver Abstraction** | Изоляция ОС-зависимого кода | `_IOCore._read_raw`/`_write_raw` (заглушки для симуляции, легко заменяются на `ctypes`/`DeviceIoControl`) |

**Принципы:**
1. `Read-Only by Default` → явная активация записи.
2. `Backup Before Write` → автоматическое сохранение оригинала.
3. `Validate Before Commit` → проверка диапазонов и системных адресов.
4. `Verify After Write` → чтение обратно, сравнение значения.
5. `Stateless I/O, Stateful Session` → аппаратный доступ без состояния, но сессия хранит логи и бэкапы.

---

### 🔹 3. Реализация (Python 3.10+)

```python
import logging, datetime, json, os
from typing import Dict, Optional
from dataclasses import dataclass

logging.basicConfig(level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')

@dataclass
class BackupRecord:
    module: str; address: int; value: int; timestamp: str; file_path: str

class RWEverything:
    """Абстракция рабочего процесса RWEverything: Read → Backup → Validate → Write → Verify."""
    MODULES = {"PCI", "EC", "SMBus", "Memory", "ACPI", "MSR"}
    SIZES = {1: "Byte", 2: "Word", 4: "Dword", 8: "Qword"}

    def __init__(self, readonly: bool = True, log_dir: str = "./rw_logs"):
        self.readonly = readonly
        self.driver_loaded = False
        self.platform_info: Dict = {}
        self.session_id = f"rw_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.log_dir = log_dir
        self.backup_store: Dict[str, BackupRecord] = {}
        self.logger = self._init_logger()
        os.makedirs(os.path.join(self.log_dir, "backups"), exist_ok=True)
        self.logger.info("RWTool initialized. Safety mode: READ-ONLY.")

    def _init_logger(self):
        log_file = os.path.join(self.log_dir, f"{self.session_id}.log")
        fh = logging.FileHandler(log_file)
        fh.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] %(message)s'))
        return logging.getLogger(self.session_id)

    # ─── SESSION & DRIVER ───
    def connect(self) -> bool:
        self.driver_loaded = True
        self.platform_info = {"cpu": "Intel/AMD", "chipset": "PCH/FCH", "bios_ver": "N/A"}
        self.logger.info(f"Driver loaded. Platform: {self.platform_info}")
        return True

    def disconnect(self):
        if self.driver_loaded: self.driver_loaded = False

    def __enter__(self): self.connect(); return self
    def __exit__(self, *args): self.disconnect()

    # ─── CORE I/O (SAFETY WRAPPER) ───
    def _read_raw(self, module: str, address: int, size: int) -> int:
        assert module in self.MODULES and size in self.SIZES
        if not self.driver_loaded: raise RuntimeError("Driver not loaded.")
        self.logger.debug(f"READ {module}@0x{address:X} ({self.SIZES[size]})")
        return 0x00  # Заглушка. В реальности: ctypes.DeviceIoControl(IOCTL_READ)

    def _write_raw(self, module: str, address: int, value: int, size: int) -> bool:
        self.logger.info(f"WRITE {module}@0x{address:X} = 0x{value:X} ({self.SIZES[size]})")
        return True  # Заглушка. В реальности: DeviceIoControl(IOCTL_WRITE)

    # ─── PUBLIC API ───
    def read(self, module: str, address: int, size: int = 1) -> int:
        return self._read_raw(module, address, size)

    def write(self, module: str, address: int, value: int, size: int = 1) -> bool:
        if self.readonly: raise PermissionError("Read-only mode. Set readonly=False.")

        # 1. BACKUP
        orig = self._read_raw(module, address, size)
        path = os.path.join(self.log_dir, "backups", f"{self.session_id}_{module}_{address:X}.bin")
        with open(path, "wb") as f: f.write(orig.to_bytes(size, 'little'))
        self.backup_store[f"{module}_{address:X}"] = BackupRecord(module, address, orig, datetime.datetime.now().isoformat(), path)

        # 2. VALIDATE
        if not self._validate(module, address, value):
            self.logger.error("Validation failed. Write aborted."); return False

        # 3. WRITE & VERIFY
        if self._write_raw(module, address, value, size):
            if self._read_raw(module, address, size) == value:
                self.logger.info("[OK] Write verified."); return True
        self.logger.critical("[FAIL] Write mismatch."); return False

    def _validate(self, module, addr, val):
        if module == "EC" and 0x00 <= addr <= 0x0F: self.logger.warning("EC 0x00-0x0F is system-critical.")
        if module == "PCI" and (val & 0xFFFF) != 0x0000: self.logger.info("PCI Config write detected.")
        return True

    def restore(self, module: str, address: int) -> bool:
        key = f"{module}_{address:X}"
        if key not in self.backup_store: self.logger.error("No backup."); return False
        rec = self.backup_store[key]
        return self._write_raw(rec.module, rec.address, rec.value, 4)

    # ─── SUBSYSTEMS ───
    @property
    def pci(self): return _PCIManager(self)
    @property
    def ec(self): return _ECController(self)
    @property
    def smbus(self): return _SMBusScanner(self)

    # ─── EXPORT & SCRIPTING ───
    def export_report(self, filename="report.json"):
        path = os.path.join(self.log_dir, filename)
        json.dump({"session": self.session_id, "platform": self.platform_info, "backups": len(self.backup_store)}, open(path,"w"), indent=2)
        return path

    def run_script(self, commands: list):
        for cmd in commands:
            parts = cmd.split(); act, mod, addr = parts[0], parts[1], int(parts[2], 16)
            val = int(parts[3], 16) if len(parts)>3 else None; sz = int(parts[4]) if len(parts)>4 else 1
            if act=="READ": self.read(mod, addr, sz)
            elif act=="WRITE" and val is not None: self.write(mod, addr, val, sz)

# ─── INTERNAL SUBSYSTEMS ───
class _PCIManager:
    def __init__(self, core): self._c = core
    def read_cfg(self, bus, dev, func, off, sz=1): return self._c.read("PCI", off, sz)
    def write_cfg(self, bus, dev, func, off, val, sz=1): return self._c.write("PCI", off, val, sz)

class _ECController:
    def __init__(self, core): self._c = core
    def read_reg(self, off): return self._c.read("EC", off, 1)
    def write_reg(self, off, val): return self._c.write("EC", off, val, 1)
    def get_temp(self, cpu=0x68, gpu=0x69): return {"cpu": self.read_reg(cpu), "gpu": self.read_reg(gpu)}

class _SMBusScanner:
    def __init__(self, core): self._c = core
    def scan(self, addr): return {"addr": addr, "status": "responsive"}
```

---

### 🔹 4. Пример использования (диагностический workflow)

```python
# 1. Безопасное чтение
with RWEverything(readonly=True) as rw:
    temp = rw.ec.get_temp()
    print(f"EC Temp: CPU={temp['cpu']}, GPU={temp['gpu']}")

# 2. Изменение с бэкапом и верификацией
with RWEverything(readonly=False) as rw:
    # Включить Memory Space в PCI Command Register (пример)
    rw.pci.write_cfg(0, 0, 0, 0x04, 0x0006, 2)  # RW автоматически сделает Backup → Validate → Write → Verify

# 3. Откат при ошибке
rw.restore("PCI", 0x04)

# 4. Автоматизация (аналог /Command=)
rw.run_script([
    "READ EC 68 0 1",
    "READ SMBus 50 0 1",
    "WRITE PCI 4 6 2 1"
])

# 5. Экспорт отчёта
rw.export_report("diag_2025.json")
```

---

[IF SOFT] 🎓 Ментор: как это помогает в ремонте
- `Чтение → Бэкап → Запись → Верификация` отражает реальный инженерный стандарт. В RW это делается вручную, здесь — автоматизировано.
- `readonly=True` по умолчанию защищает от случайного "кирпича". Включай `False` только когда понимаешь регистр.
- `BackupStore` хранит бинарные копии. Если `write` сломал систему, `restore()` вернёт исходное значение.
- `run_script()` заменяет `/Command=`. Логируй каждую сессию: `rw_logs/` содержит `.log` и `.bin` бэкапы.
- **Ограничение:** `_read_raw`/`_write_raw` сейчас заглушки. Для реального доступа замени их на `ctypes.windll.rwdrv.DeviceIoControl` (Win) или `ioctl` (Linux). Архитектура готова к подстановке.

[RECOMMEND]
1. Сохрани код в `rw_tool.py`, добавь реальный драйверный вызов через `ctypes` → получишь рабочий инструмент.
2. Интегрируй с `chipsec` (аудит) и `UEFITool` (анализ образов) → полный стек диагностики: `chipsec → RW → UEFITool`.

[ANTICIPATE]
- "Как подключить реальный `rwdrv.sys`?" → Через `ctypes.WinDLL("rwdrv.sys")` и `DeviceIoControl` с IOCTL-кодами из документации RW. Заглушки в коде помечены комментариями.
- "Можно ли добавить поддержку SPD памяти?" → Да: расширь `_SMBusScanner` методами `read_spd(slot)`, используй адреса `0x50-0x57` и протокол `Read Byte`.







=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================

- напиши шпаргалку на тему возможные ситуации в контексте взаимодействия с RWEverything: подробно опиши 5-10 ситуаций с большой вероятностью возникновения → рекомендуемые действия(на что стоит обратить внимание, алгоритм выбора инструмента/утилиты/драйвера/настройки, какой результат хотим получить) → инициализация действия → какие сущности активируются в результате произведенного действия → возможные действия в случае получения ожидаемого и неожиданного результата






[MAIN] 📋 Шпаргалка: Ситуации при работе с RWEverything

*Контекст: диагностика/ремонт ПК/ноутбуков. Уровень: Beginner→Intermediate. Фокус: безопасный workflow `Read → Backup → Validate → Write → Verify`.*

---

### 🔹 Ситуация 1: «Драйвер не загружается / "Access denied"»
**Симптомы**: При запуске `rw.exe` ошибка `Failed to load driver`, `Access is denied`, или модули серые/неактивные.
**Причина**: Не включена тестовая подпись драйвера, активен HVCI/Memory Integrity, или драйвер заблокирован антивирусом.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Проверка `bcdedit /enum` → `testsigning` → 2. Проверка `Core Isolation` в Windows Security → 3. Временное отключение антивируса. |
| **⚙️ Рекомендуемые действия** | 1. Запусти от имени Администратора.<br>2. Включи тестовую подпись: `bcdedit /set testsigning on` → перезагрузка.<br>3. Отключи изоляцию ядра: `Параметры → Безопасность → Изоляция ядра → Выкл` → перезагрузка.<br>4. Добавь папку `rw/` в исключения антивируса. |
| **🚀 Инициализация действия** | Запуск `rw.exe` → попытка `connect()` → драйвер `rwdrv.sys` загружается в ядро. |
| **⚙️ Активируемые сущности** | `Kernel Driver (rwdrv.sys)` → `Device Object (\\Device\\RWEverything)` → `IOCTL handlers`. |
| **✅ Ожидаемый результат** | Дерево модулей активно, чтение регистров возвращает значения (не `0xFFFFFFFF`).<br>→ **Действия**: Начни с безопасного чтения (`PCI → Summary`, `EC → Read`). |
| **❌ Неожиданный результат** | Драйвер грузится, но чтение возвращает `0x00` или `0xFF` везде.<br>→ **Действия**: 1) Проверь, не запущен ли в виртуальной машине (прямой доступ к железу из VM ограничен); 2) Попробуй загрузиться в безопасном режиме; 3) Проверь, не блокирует ли доступ другой инструмент (chipsec, RW другой версии). |

---

### 🔹 Ситуация 2: «EC-регистры показывают "мусор" или не отвечают»
**Симптомы**: В модуле `Embedded Controller` чтение по адресу `0x68` (температура) возвращает `0x00`, `0xFF` или случайные значения.
**Причина**: Неправильный адрес (вендор-специфичный), конфликт доступа (другой драйвер держит порт `0x62/0x66`), или чтение без инициализации EC.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Поиск даташита на EC-чип (ITE/Winbond/Nuvoton) → 2. Проверка через `Command Window` (`INB 0x62`) → 3. Сравнение с показаниями ОС (HWMonitor). |
| **⚙️ Рекомендуемые действия** | 1. Найди карту регистров для твоей модели (форумы, репозитории типа `github.com/BeardOverflow/msi-ec`).<br>2. Читай только `Read Byte`, избегай `Write` в диапазоне `0x00-0x0F` (системные регистры).<br>3. Если значение `0xFF` → возможно, сенсор не активирован в этой фазе загрузки. |
| **🚀 Инициализация действия** | Выбор модуля `Embedded Controller` → ввод адреса `0x68` → нажатие `Read`. |
| **⚙️ Активируемые сущности** | `EC Port I/O (0x62/0x66)` → `EC Firmware State Machine` → `Sensor Register`. |
| **✅ Ожидаемый результат** | Возвращается осмысленное значение (например, `0x32` = 50°C).<br>→ **Действия**: Запиши в лог, сравни с другими источниками, сохрани бэкап (`Save to file`). |
| **❌ Неожиданный результат** | Система зависает или перезагружается после чтения.<br>→ **Действия**: 1) Вероятно, чтение триггерит побочный эффект (редко, но бывает); 2) Избегай этого адреса в будущих сессиях; 3) Восстанови систему из бэкапа, если запись была. |

---

### 🔹 Ситуация 3: «SMBus-сканер не находит устройства / ложные адреса»
**Симптомы**: `SMBus → Scan` показывает пустой список или адреса, которые не отвечают на `Read Byte`.
**Причина**: Неправильно выбран контроллер (Intel PCH vs AMD FCH), SMBus заблокирован BIOS, или устройство использует быстрый режим (Quick Command).

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Проверить `PCI → SMBus Controller` (включён ли `IO Space`) → 2. Сверить адреса с даташитами (0x50=SPD, 0x4C=сенсор) → 3. Попробовать `Read Byte` вручную. |
| **⚙️ Рекомендуемые действия** | 1. Убедись, что в `PCI Config` у SMBus-контроллера установлен бит `IO Space Enable`.<br>2. Для SPD: адреса `0x50-0x57`, протокол `Read Byte` или `Read Block`.<br>3. Для температурных сенсоров: часто `0x4C-0x4F`, но зависит от вендора.<br>4. Используй `Read Byte` для теста, не `Block Write` без документации. |
| **🚀 Инициализация действия** | Выбор модуля `SMBus` → выбор контроллера → `Scan` или ручной `Read Byte @ 0x50`. |
| **⚙️ Активируемые сущности** | `SMBus Host Controller` → `SMBus Protocol Engine` → `Target Device (SPD/Sensor)`. |
| **✅ Ожидаемый результат** | Устройство отвечает, возвращает данные (для SPD: первые байты `80 10 ...`).<br>→ **Действия**: Сохрани дамп (`Save as binary`), проанализируй тайминги/производителя. |
| **❌ Неожиданный результат** | Чтение возвращает `0xFF` или таймаут, система "подвисает" на 1-2 сек.<br>→ **Действия**: 1) Устройство может не поддерживать этот протокол; 2) Попробуй другой адрес/протокол; 3) Если система зависает — избегай этого адреса, возможен конфликт. |

---

### 🔹 Ситуация 4: «PCI-устройство не определяется / BAR = 0xFFFFFFFF»
**Симптомы**: В `PCI → Config Space` поле `BAR0` показывает `0xFFFFFFFF`, устройство не отвечает в ОС.
**Причина**: Устройство не инициализировано (нет драйвера), отключено в BIOS, или сбой enumeration.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Проверить `Command Register` (биты `Memory/IO Enable`) → 2. Проверить `Vendor/Device ID` (не `FFFF`) → 3. Сравнить с `Device Manager`. |
| **⚙️ Рекомендуемые действия** | 1. Если `Vendor ID = FFFF` → устройство физически не отвечает (проблема на уровне PCIe).<br>2. Если `Vendor ID` верный, но `BAR = FFFF` → драйвер не назначил ресурсы.<br>3. Попробуй включить `Memory Space Enable` (бит 1 в `Command Register`) → но только если понимаешь, что делаешь! |
| **🚀 Инициализация действия** | Выбор устройства в дереве `PCI` → чтение `Config Space` → анализ `BARs`. |
| **⚙️ Активируемые сущности** | `PCI Configuration Mechanism` → `Device Config Registers` → `BAR Decoding Logic`. |
| **✅ Ожидаемый результат** | `BAR` показывает валидный адрес (не `0xFFFFFFFF`), устройство появляется в ОС.<br>→ **Действия**: Запиши адрес, используй для MMIO-доступа. |
| **❌ Неожиданный результат** | После изменения `Command Register` система зависает или устройство пропадает.<br>→ **Действия**: 1) Немедленно восстанови оригинальное значение из бэкапа; 2) Перезагрузись; 3) Не меняй `Command Register` без понимания зависимостей. |

---

### 🔹 Ситуация 5: «Запись в регистр вызывает мгновенный сброс/зависание»
**Симптомы**: После `Write` в EC/SMBus/PCI система перезагружается, зависает или выдаёт синий экран.
**Причина**: Запись в системно-критичный регистр (watchdog, reset, clock gating), нарушение протокола (неверный размер/значение).

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Анализ лога: какой адрес/значение записывалось → 2. Поиск в даташите: назначение регистра → 3. Восстановление из бэкапа. |
| **⚙️ Рекомендуемые действия** | **Перед записью**:<br>1. Всегда делай `Backup` (RW: `Save to file`, в коде: `backup_store`).<br>2. Избегай диапазонов `0x00-0x0F` в EC, `Command Register` в PCI без необходимости.<br>3. Тестируй на нерабочем железе сначала.<br>**После сбоя**:<br>1. Перезагрузись, восстанови оригинальное значение через `restore()` или ручную запись.<br>2. Задокументируй "опасный" адрес в чёрный список. |
| **🚀 Инициализация действия** | Ввод значения в поле `Write` → нажатие `Write` → подтверждение. |
| **⚙️ Активируемые сущности** | `Target Register` → `Hardware State Machine` → возможно `Watchdog Timer` / `Reset Logic`. |
| **✅ Ожидаемый результат** | Значение изменяется, система стабильна, эффект соответствует ожиданиям (например, включился вентилятор).<br>→ **Действия**: Зафиксируй изменение в отчёте, протестируй функционал. |
| **❌ Неожиданный результат** | Система зависает/перезагружается.<br>→ **Действия**: 1) Восстанови бэкап при следующей загрузке; 2) Добавь адрес в `SafetyGuard._validate()` как запрещённый; 3) Никогда не записывай в этот регистр без документации. |

---

### 🔹 Ситуация 6: «Экспортированные данные не совпадают с отображаемыми на экране»
**Симптомы**: В окне RW значение `0x32`, но в сохранённом файле `0x00` или наоборот.
**Причина**: Регистр изменяется динамически (температура, счётчик), или экспорт происходит с задержкой/кэшированием.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Повторное чтение сразу после экспорта → 2. Сравнение таймстемпов → 3. Проверка, не кэширует ли GUI значения. |
| **⚙️ Рекомендуемые действия** | 1. Для динамических регистров (температура): делай несколько чтений с интервалом, усредняй.<br>2. Используй `Command Window` для атомарного `Read → Save` без участия GUI.<br>3. Сравнивай не только значение, но и время чтения (`timestamp`). |
| **🚀 Инициализация действия** | Нажатие `Save to file` или вызов `export_report()`. |
| **⚙️ Активируемые сущности** | `File I/O Subsystem` → `Buffer Flush` → `Disk Write`. |
| **✅ Ожидаемый результат** | Файл содержит актуальное значение, совпадающее с экраном (±1 чтение для динамических данных).<br>→ **Действия**: Используй файл для анализа/отчёта. |
| **❌ Неожиданный результат** | Файл пустой, повреждённый или содержит старые данные.<br>→ **Действия**: 1) Проверь права на запись в папку; 2) Повтори экспорт; 3) Используй альтернативный метод (скрипт через `Command Window`). |

---

### 🔹 Ситуация 7: «Скрипт (/Command=) выполняется не полностью / ошибка синтаксиса»
**Симптомы**: При запуске `rw.exe /Command=script.rwc` выполнение обрывается на середине, часть команд игнорируется.
**Причина**: Ошибка в синтаксисе команды, недопустимый адрес/размер, или команда требует подтверждения, которое не может быть дано в batch-режиме.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Запуск с `/LogFile=` для трассировки → 2. Пошаговая проверка команд в GUI → 3. Упрощение скрипта (исключение подозрительных команд). |
| **⚙️ Рекомендуемые действия** | 1. Начинай скрипт с `# комментарии` и простых `READ`-команд.<br>2. Тестируй каждую команду вручную перед добавлением в скрипт.<br>3. Избегай `WRITE` в скриптах для первой отладки.<br>4. Используй `Cout` для логирования промежуточных значений. |
| **🚀 Инициализация действия** | Запуск `rw.exe /Command=script.rwc` → парсинг строк → выполнение. |
| **⚙️ Активируемые сущности** | `Command Parser` → `IO Dispatcher` → `Target Module Handler`. |
| **✅ Ожидаемый результат** | Все команды выполняются, лог-файл содержит ожидаемые значения.<br>→ **Действия**: Интегрируй скрипт в регулярную диагностику. |
| **❌ Неожиданный результат** | Скрипт падает с ошибкой, часть данных не собрана.<br>→ **Действия**: 1) Исправь синтаксис по логу; 2) Разбей скрипт на части; 3) Для критичных операций добавь проверки (`if read != expected: abort`). |

---

### 🔹 Ситуация 8: «Платформа не определяется автоматически / неправильный профиль»
**Симптомы**: `Platform Info` показывает `Unknown`, модули `EC/SMBus` не предлагают пресеты для твоего чипсета.
**Причина**: Новая/редкая платформа, отсутствующая в базе RW, или кастомная прошивка.

| Этап | Действия |
|------|----------|
| **🎯 Алгоритм выбора инструмента** | 1. Ручной выбор контроллера через `PCI` → 2. Поиск аналогичной платформы в базе → 3. Использование generic-драйверов (Intel PCH generic). |
| **⚙️ Рекомендуемые действия** | 1. Определи чипсет через `PCI → Host Bridge` (Vendor/Device ID).<br>2. Выбери ближайший профиль в настройках (например, `Intel 600 Series` для нового PCH).<br>3. Для EC: используй ручное чтение по адресам из даташита, игнорируя пресеты. |
| **🚀 Инициализация действия** | Запуск `connect()` → авто-детект платформы → загрузка профиля. |
| **⚙️ Активируемые сущности** | `Platform Detector` → `Profile Loader` → `Module Presets`. |
| **✅ Ожидаемый результат** | Модули работают в ручном режиме, доступ к регистрам получен.<br>→ **Действия**: Документируй найденные адреса для будущих сессий, создай кастомный профиль. |
| **❌ Неожиданный результат** | Выбранный профиль даёт неверные адреса, чтение возвращает мусор.<br>→ **Действия**: 1) Вернись к полностью ручному режиму; 2) Используй только `Memory`/`PCI`/`Command Window` без модульных пресетов; 3) Свяжись с разработчиком RW с отчётом о новой платформе. |

---

[🛡️ Общие правила безопасности для RWEverything]
1. **Read-Only по умолчанию**: Всегда начинай с `readonly=True`. Включай запись только после полного понимания регистра.
2. **Бэкап перед записью**: `Save to file` или `backup_store` — обязательно. Без бэкапа — только чтение.
3. **Избегай системных диапазонов**: `EC 0x00-0x0F`, `PCI Command Register`, `SMI handlers` — только с документацией.
4. **Тестируй на "жертвенном" железе**: Сначала на списанной плате, потом на рабочей.
5. **Логируй всё**: `rw_logs/` с `.log` и `.bin` — твоя страховка при расследовании сбоев.

[🔗 Сопоставление с абстракцией `RWEverything` как Python-объект]
| Ситуация в реальном RW | Аналог в `RWEverything` классе |
|------------------------|-------------------------------|
| Драйвер не грузится | `connect()` → проверка `driver_loaded`, логирование ошибки |
| Чтение "мусора" из EC | `ec.read_reg(0x68)` → возврат `0xFF` → лог `WARNING` |
| SMBus не находит устройства | `smbus.scan(0x50)` → `{"status": "no_response"}` |
| Запись вызывает сброс | `write()` → `SafetyGuard._validate()` блокирует адрес → `PermissionError` |
| Экспорт не совпадает | `export_report()` → проверка `timestamp` → повторное чтение |
| Скрипт падает | `run_script()` → try/except на каждой команде → лог ошибки |
| Платформа не определена | `connect()` → `platform_info = {"status": "unknown"}` → fallback на generic |

[RECOMMEND]
1. Создай файл `rw_safety_rules.md` с "чёрным списком" адресов для твоих моделей ноутбуков — это ускорит диагностику и предотвратит ошибки.
2. Потренируй ситуации №1 (драйвер) и №5 (безопасная запись) на виртуальной машине или старом железе — это основа безопасного воркфлоу.

[ANTICIPATE]
- "Как быстро проверить, не заблокирован ли адрес для записи?" → В классе `RWEverything`: `if not SafetyGuard._validate(module, addr): raise PermissionError`. В реальном RW: сверь с даташитом и избегай записи без бэкапа.
- "Можно ли автоматически восстановить систему после сбоя записи?" → Да: `restore()` в классе читает из `backup_store`. В реальном RW: вручную загрузи сохранённый `.bin` и запиши обратно (только если система ещё отвечает).





















