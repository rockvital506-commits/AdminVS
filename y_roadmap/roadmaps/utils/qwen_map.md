
# 📦 ИНЖЕНЕРНЫЙ АРСЕНАЛ: ПОЛНЫЙ СПИСОК УТИЛИТ ПО КАТЕГОРИЯМ

## 🌳 Древовидная структура (по назначению)

```
🔧 ИНЖЕНЕРНЫЙ КОМПЛЕКС (Ventoy + WTG)
├── 🖥️ LIVE-ПЛАТФОРМЫ (загрузочные среды)
│   ├── WinPE Sergei Strelec (Windows-реанимация)
│   ├── Rescuezilla (Linux-бэкапы/клонирование)
│   └── SystemRescue (Linux-диагностика)
│
├── 💾 ДИСКОВЫЕ ОПЕРАЦИИ
│   ├── 🔍 Диагностика: DiskGenius, CrystalDiskInfo, Victoria
│   ├── ♻️ Восстановление: DMDE, TestDisk, PhotoRec, R-Studio
│   ├── 📦 Бэкап/Клонирование: Hasleo Backup, Clonezilla, AOMEI
│   └── 🧹 Оптимизация: FastCopy, FreeFileSync
│
├── 🔬 АППАРАТНЫЙ АУДИТ
│   ├── Система: HWiNFO64, CPU-Z, AIDA64
│   ├── USB/Flash: ChipGenius, Flash Drive Info Extractor, UsbTreeView
│   ├── SSD/NVMe: vlo flash_id утилиты
│   └── Экстрим: RW-Everything (регистры/ACPI)
│
├── 🧠 ПАМЯТЬ И ПРОЦЕССОР
│   ├── Тесты ОЗУ: MemTest86+
│   ├── Стресс-тесты: Prime95, FurMark
│   └── Тюнинг CPU: ThrottleStop
│
├── 🪛 ДРАЙВЕРЫ И СИСТЕМА
│   ├── Установка: SDIO (Origin), Microsoft Update Catalog
│   ├── Очистка: DDU, DriverStore Explorer, DeviceCleanup
│   ├── Аудит: DriverView, ServiWin, DUMo
│   └── Бэкап: Double Driver, Export-WindowsDriver (PS)
│
├── 🛡️ БЕЗОПАСНОСТЬ (WinPE-совместимые)
│   ├── Сканирование: Dr.Web CureIt!, KVRT, EEK
│   ├── Ручной аудит: FRST, Autoruns (Offline)
│   └── Специализированные: AdwCleaner, TDSSKiller
│
├── 🌐 СЕТЕВАЯ ДИАГНОСТИКА
│   ├── Сканирование: Advanced IP Scanner, Angry IP Scanner
│   ├── Wi-Fi: WirelessNetView, NetSpot
│   ├── Трафик: WinMTR, iPerf3, Wireshark, TCPView
│   └── Модификация: TMAC, Mitmproxy
│
├── ⚙️ МОДИФИКАЦИЯ ОБРАЗОВ И СИСТЕМ
│   ├── Windows-образы: DISM++, MSMG Toolkit, AnyBurn
│   ├── Виртуальные диски: DiskGenius (VHDX), ImDisk
│   ├── Загрузчики: Bootice, Rufus
│   └── Конфиги: Notepad++, 7-Zip, Cubic (Linux ISO)
│
└── 🔧 ТВИКИ И ОПТИМИЗАЦИЯ
    ├── Система: Winaero Tweaker, InControl
    └── Мониторинг: Sysinternals (ProcMon, RAMMap, Autoruns)
```

---

## 📊 ТАБЛИЦА УТИЛИТ ПО КАТЕГОРИЯМ

### 🔹 Категория: Дисковые операции / Partition & Recovery

| Утилита | Функция | Описание | Надёжность | Аналоги |
|---------|---------|----------|------------|---------|
| **DiskGenius Free** [[2]] | Partition Manager | Создание/изменение разделов, MBR/GPT, 4K выравнивание, клонирование, HEX-редактор | ★★★★★ | MiniTool Partition Wizard Free, AOMEI Partition Assistant |
| | Data Recovery | Восстановление файлов по сигнатурам, работа с RAW-разделами | ★★★★☆ | DMDE, R-Studio, TestDisk |
| | Virtual Disk | Монтирование/редактирование VHDX/VDI/VMDK как физических дисков | ★★★★★ | ImDisk, OSFMount |
| | Surface Scan | Проверка поверхности на битые сектора, ремэппинг | ★★★★☆ | Victoria, HD Tune |
| **CrystalDiskInfo** [[52]] | SMART Monitor | Чтение атрибутов здоровья диска, температура, износ, время работы | ★★★★★ | HD Tune, Hard Disk Sentinel Free |
| **Victoria SSD/HDD** [[65]] | Low-level Test | PIO-режим, APM/AAM управление, HPA-область, детальная карта задержек | ★★★★☆ | MHDD (DOS), HDDScan |
| **DMDE Free** [[21]] | FS Reconstruction | Ручное восстановление таблиц MBR/GPT, HEX-редактор секторов, безлимитное восстановление структуры | ★★★★★ | R-Studio, UFS Explorer |
| | File Recovery | Восстановление до 4000 файлов из текущей папки за операцию (free) | ★★★☆☆ | Recuva, PhotoRec |
| **TestDisk** [[78]] | Partition Repair | Восстановление удалённых разделов, загрузочных секторов, таблиц разделов | ★★★★★ | DMDE (частично), GParted |
| **PhotoRec** [[74]] | File Carving | Извлечение файлов по заголовкам из RAW-секторов (игнорирует ФС) | ★★★★☆ | R-Undelete, Recuva Deep Scan |
| **Hasleo Backup Free** [[12]] | System Clone | Клонирование системы "на горячую" (VSS), экспорт в VHDX, шифрование | ★★★★★ | Macrium Reflect Free, Clonezilla |
| | Backup/Restore | Полный/инкрементальный бэкап, сжатие, расписание | ★★★★☆ | AOMEI Backupper Standard, Veeam Agent Free |
| **Clonezilla** [[71]] | Sector-by-Sector | Побитовое клонирование вне ОС (Linux-based), работа с любыми ФС | ★★★★★ | dd (Linux), Redo Backup |

---

### 🔹 Категория: Аппаратный аудит / Hardware Info

| Утилита | Функция | Описание | Надёжность | Аналоги |
|---------|---------|----------|------------|---------|
| **HWiNFO64 Portable** [[85]] | Sensor Monitoring | Температуры, вольтажи, частоты, троттлинг, SMART в реальном времени | ★★★★★ | Open Hardware Monitor, HWMonitor |
| | Hardware Report | Детальный отчёт по чипам, ACPI, ревизиям плат, контроллерам | ★★★★★ | AIDA64 (платная), CPU-Z |
| **CPU-Z Portable** | CPU/RAM Info | Быстрая проверка характеристик процессора, таймингов памяти, чипсета | ★★★★★ | HWiNFO (частично), Speccy |
| **ChipGenius** [[3]] | USB Controller ID | Определение контроллеров флешек, хабов, картридеров по VID/PID | ★★★★☆ | Flash Drive Info Extractor, ChipEasy |
| **Flash Drive Info Extractor** [[5]] | Direct Flash Query | Прямой опрос контроллера флешки, получение Flash ID (без догадок) | ★★★★★ | ChipGenius (менее точный) |
| **vlo flash_id утилиты** | SSD NAND Info | Чтение паспорта NVMe/SATA SSD: тип памяти, каналы, заводские битые блоки | ★★★★★ | Нет прямых аналогов (специализированные) |
| **UsbTreeView** | USB Topology | Визуализация дерева портов, проверка UASP, протоколов, питания порта | ★★★★★ | USBDeview (NirSoft), Device Manager |
| **RW-Everything Portable** [[117]] | Register Access | Прямое чтение/запись в регистры чипсета, ACPI, PCI, EC, SMBus | ★★★★☆ | Нет аналогов (уникальный инструмент) |

---

### 🔹 Категория: Драйверы / Driver Management

| Утилита | Функция | Описание | Надёжность | Аналоги |
|---------|---------|----------|------------|---------|
| **SDIO Origin** [[35]] | Offline Install | Автоматическая установка драйверов из оффлайн-базы по HWID | ★★★★★ | DriverPack (не рекомендуется), IObit (не рекомендуется) |
| | Driver Packs | Модульные пакеты (LAN, WLAN, MassStorage) для экономии места | ★★★★☆ | Собственные базы вендоров |
| **DDU Portable** | GPU Clean Uninstall | Полное удаление драйверов видеокарт из безопасного режима | ★★★★★ | AMD Cleanup Utility, NVIDIA Clean Install |
| **DriverStore Explorer** | Driver Store Cleanup | Удаление дубликатов и старых версий из FileRepository | ★★★★★ | PNPCleaner, встроенная очистка диска |
| **Double Driver Portable** | Driver Backup | Экспорт сторонних драйверов в структурированные папки | ★★★★☆ | DriverBackup!, Export-WindowsDriver (PS) |
| **DriverView (NirSoft)** | Loaded Driver Audit | Мониторинг загруженных .sys драйверов: адрес, версия, производитель | ★★★★☆ | Process Explorer (частично), Autoruns |
| **DeviceCleanup** | Phantom Device Remove | Удаление "фантомных" устройств из реестра (старая периферия) | ★★★★☆ | Нет прямых аналогов |

---

### 🔹 Категория: Сеть / Network Analysis

| Утилита | Функция | Описание | Надёжность | Аналоги |
|---------|---------|----------|------------|---------|
| **Advanced IP Scanner** [[155]] | LAN Discovery | Быстрое сканирование сети, определение устройств, доступ к ресурсам | ★★★★★ | Angry IP Scanner, Nmap (консоль) |
| **WirelessNetView** [[3]] | Wi-Fi Monitor | Таблица доступных сетей: сигнал (dBm/%), канал, шифрование, BSSID | ★★★★☆ | inSSIDer Free, Acrylic Wi-Fi Home |
| **WinMTR** | Path Analysis | Гибрид ping+traceroute: потери и задержки на каждом хопе | ★★★★★ | PathPing (встроен), WinRoute |
| **iPerf3** | Throughput Test | Измерение реальной пропускной способности (TCP/UDP/SCTP) | ★★★★★ | NetPerf, LAN Speed Test |
| **Wireshark Portable** [[145]] | Packet Analysis | Глубокий разбор сетевых пакетов, фильтрация, декодирование протоколов | ★★★★★ | tcpdump (CLI), Microsoft Message Analyzer |
| **TCPView (Sysinternals)** | Process Network | Сетевые соединения в реальном времени с привязкой к процессам | ★★★★★ | NetStat, CurrPorts |
| **TMAC Portable** | MAC Spoofing | Смена MAC-адреса в обход ограничений драйверов | ★★★★☆ | Technitium MAC Changer, SMAC |

---

### 🔹 Категория: Безопасность / Antivirus (WinPE)

| Утилита | Функция | Описание | Надёжность | Аналоги |
|---------|---------|----------|------------|---------|
| **Dr.Web CureIt!** [[175]] | On-demand Scan | Автономное сканирование и лечение системных файлов, руткитов | ★★★★★ | KVRT, EEK |
| **KVRT** [[182]] | Malware Removal | Глубокое сканирование на трояны, майнеры, бэкдоры (оффлайн-базы) | ★★★★★ | Dr.Web CureIt!, EEK |
| **Emsisoft EEK** | Dual-Engine Scan | Два движка (собственный + Bitdefender), акцент на PUP/Adware | ★★★★☆ | Malwarebytes AdwCleaner, HitmanPro |
| **FRST (Farbar)** | Manual Audit | Генерация текстовых логов автозапуска/служб + скрипты fixlist.txt | ★★★★★ | Нет аналогов (уникальный формат) |
| **Autoruns Offline** | Registry Audit | Анализ автозапуска неактивной ОС (File → Analyze Offline System) | ★★★★★ | FRST (частично), manual regedit |
| **TDSSKiller** | Bootkit Removal | Удаление руткитов из MBR/загрузочных секторов | ★★★★☆ | KVRT (частично), MBAR |

---

### 🔹 Категория: Модификация образов / Image Tools

| Утилита | Функция | Описание | Надёжность | Аналоги |
|---------|---------|----------|------------|---------|
| **DISM++ Portable** [[107]] | WIM/ESD Mount | Монтирование образов Windows, инжекция драйверов, очистка, твики | ★★★★★ | оригинальный DISM (CLI), NTLite (платный) |
| | Driver Management | Управление драйверами в оффлайн-системе: добавление/удаление | ★★★★★ | DISM CLI, PnPUtil |
| **Bootice Portable** | Boot Sector Edit | Редактирование MBR/PBR, BCD, GRUB, syslinux конфигураций | ★★★★☆ | EasyBCD (платный), bcdedit (CLI) |
| **AnyBurn Portable** | ISO Manipulation | Извлечение/добавление файлов в ISO, замена boot-сектора | ★★★★☆ | UltraISO (платный), PowerISO |
| **ImDisk Portable** | RAM Disk Mount | Монтирование образов в ОЗУ или как физических устройств | ★★★★☆ | OSFMount, WinCDEmu |
| **7-Zip Portable** | Archive/ISO Open | Открытие структуры образов, извлечение файлов, редактирование конфигов | ★★★★★ | PeaZip, WinRAR |

---

## 🎯 Меню утилит по назначению (быстрый доступ)

| Меню | Назначение | Ключевые утилиты |
|------|------------|-----------------|
| **🔍 Диагностика диска** | Проверка здоровья, поверхности, разделов | DiskGenius, CrystalDiskInfo, Victoria |
| **♻️ Восстановление данных** | Возврат файлов, разделов, структуры ФС | DMDE, TestDisk, PhotoRec, R-Studio |
| **📦 Бэкап системы** | Создание образов, клонирование в VHDX | Hasleo Backup, Clonezilla, AOMEI |
| **🔬 Аудит железа** | Информация о компонентах, датчиках, чипах | HWiNFO64, CPU-Z, ChipGenius, RW-Everything |
| **🧠 Тесты стабильности** | Нагрузка на CPU, GPU, RAM | Prime95, FurMark, MemTest86+ |
| **🪛 Драйверы** | Установка, бэкап, очистка драйверов | SDIO, DDU, DriverStore Explorer, Double Driver |
| **🛡️ Антивирус (WinPE)** | Сканирование неактивной ОС | Dr.Web CureIt!, KVRT, FRST, Autoruns Offline |
| **🌐 Сеть** | Сканирование, трафик, туннели | Advanced IP Scanner, Wireshark, WinMTR, iPerf3 |
| **⚙️ Твики системы** | Оптимизация, отключение телеметрии | Winaero Tweaker, DISM++, InControl |
| **💾 Работа с образами** | Модификация ISO, VHDX, загрузчиков | DISM++, Bootice, AnyBurn, ImDisk |

---

## ⚠️ Классификация функций по уровню риска

### ✅ Безопасные (только чтение / без изменений)
- Просмотр SMART (CrystalDiskInfo, HWiNFO)
- Сканирование сети (Advanced IP Scanner, WirelessNetView)
- Анализ процессов (Process Explorer, DriverView)
- Чтение регистров (RW-Everything в режиме read-only)
- Просмотр структуры образов (7-Zip, DiskGenius в режиме просмотра)

### ⚠️ С изменениями (требуют подтверждения / бэкапа)
- Изменение разделов (DiskGenius → Resize/Create)
- Установка драйверов (SDIO, Dism++ → Add Driver)
- Очистка драйверов (DriverStore Explorer → Force Delete)
- Модификация образов (DISM++ → Add/Remove, Bootice → Edit BCD)
- Твики реестра (Winaero Tweaker, Autoruns)

### 🔴 Критичные (возможна потеря данных / кирпич)
- Запись в регистры (RW-Everything → Write)
- Прошивка BIOS (FPT/Flashrom → Flash)
- Низкоуровневое форматирование (Victoria → Erase, DiskGenius → Format)
- HEX-редактирование секторов (DMDE, DiskGenius → Write Sector)
- Удаление разделов (DiskGenius → Delete Partition)

> ⚠️ **Правило**: Перед операциями из категории 🔴 всегда создавайте бэкап через Hasleo Backup или Double Driver.

---

## 📚 План обучения: Уровни освоения (0 → 5)

### 🔹 Уровень 0: Базовая навигация (Неделя 1)
- [ ] Запуск утилит из папки Tools\ без установки
- [ ] Понимание разницы: Portable ≠ Installed
- [ ] Безопасное извлечение накопителей (политика записи)
- [ ] Работа с буквами дисков в WinPE (C: ≠ C:)

### 🔹 Уровень 1: Диагностика (Недели 2-3)
- [ ] Чтение SMART в CrystalDiskInfo: интерпретация атрибутов
- [ ] Запуск HWiNFO64: мониторинг температур, троттлинга
- [ ] Сканирование диска в DiskGenius: поиск битых секторов
- [ ] Проверка ОЗУ: запуск MemTest86+ через Ventoy

### 🔹 Уровень 2: Восстановление данных (Недели 4-5)
- [ ] Восстановление файлов в DMDE: навигация по панелям, лимит 4000 файлов
- [ ] Возврат раздела через TestDisk: анализ логов, запись таблицы
- [ ] Клонирование в Hasleo: System Clone → Export to VHDX (Fixed Size)
- [ ] Синхронизация папок: FreeFileSync (сравнение по содержимому)

### 🔹 Уровень 3: Драйверы и система (Недели 6-7)
- [ ] Работа с SDIO: фильтрация, установка пакетами, создание точки восстановления
- [ ] Очистка DriverStore через RAPR: поиск дубликатов, безопасное удаление
- [ ] Автономный аудит: Autoruns → Analyze Offline System, FRST → Fixlist
- [ ] Бэкап драйверов: Double Driver → Export, восстановление через Диспетчер устройств

### 🔹 Уровень 4: Низкоуровневые операции (Недели 8-9)
- [ ] RW-Everything: чтение регистров чипсета, запрет на запись без понимания
- [ ] DISM++: инжекция драйверов в оффлайн-образ, очистка обновлений
- [ ] Bootice: редактирование BCD, понимание загрузочной цепочки
- [ ] ThrottleStop: андервольтинг, мониторинг стабильности

### 🔹 Уровень 5: Интеграция и автоматизация (Недели 10+)
- [ ] Создание скриптов .bat для авто-бэкапа (Export-WindowsDriver + SDIO)
- [ ] Настройка структуры папок Tools\ под свой рабочий процесс
- [ ] Оптимизация кластеров: когда 4 КБ, когда 64/128 КБ, почему exFAT для больших файлов
- [ ] Документирование: ведение лога действий, создание чек-листов для пациентов

> 🎯 **Метрика успеха**: На уровне 3 вы можете самостоятельно восстановить данные после форматирования. На уровне 5 — подготовить универсальный WTG-образ, который загрузится на любом ПК без синего экрана.

---

> ℹ️ Все утилиты в списке — **бесплатные** и **официально портативные**. Источники: официальные сайты разработчиков, PortableApps.com, MajorGeeks, GitHub. [[2]][[35]][[52]][[78]][[85]][[107]][[155]][[175]]






