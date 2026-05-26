


V:\ (exFAT 300GB)
├── 📁 ISO\
│   ├── WinPE_Strelec_vX.iso      # Основной рабочий образ
│   ├── SystemRescue_XX.X.iso     # Linux для ddrescue/ext4
│   ├── memtest86-usb.img         # Или .iso (проверьте совместимость)
│   ├── shellx64.efi              # UEFI Shell (переименовать в .iso или запускать напрямую)
│   └── ubuntu-XX.X-live.iso      # Опционально: другой Linux-инструментарий
│
├── 📁 TOOLS\
│   ├── 📁 WinPE_Portable\        # .exe-утилиты для копирования в WinPE
│   │   ├── CrystalDiskInfo_*.exe
│   │   ├── DMDE_*.exe
│   │   ├── RWEverything_*.exe
│   │   └── SDIO_*.exe
│   │
│   ├── 📁 Firmware\
│   │   ├── UEFITool_*.exe        # Запускать с хост-ОС
│   │   ├── chipsec_*.zip         # Распаковать при необходимости
│   │   └── BIOS_Backups\         # Дампы прошивок (для анализа)
│   │
│   └── 📁 Drivers\
│       ├── Intel_Chipset_*.exe
│       ├── AMD_Chipset_*.exe
│       └── VivoBook_Drivers\     # Скачанные с ASUS драйверы
│
├── 📁 DATA\
│   ├── 📁 disk_images\      # Большие .img/.dd (можно и тут)
│   └── 📁 recovered_files\  # Восстановленные данные
│
└──  VENToy_EXTRA\         # Опционально: данные, доступные из Ventoy
    └── ... (некоторые плагины Ventoy могут читать с NTFS)



### ✅ Must Have (базовый набор)

```
V:\ (Ventoy exFAT)
├── 📁 ISO\
│   ├── WinPE_Strelec_vX.iso          # Windows-утилиты
│   ├── SystemRescue_XX.X.iso         # Linux + ddrescue/testdisk
│   ├── gparted-live-XX.X.iso         # Разметка/ФС
│   ├── memtest86-usb.iso             # Тест ОЗУ
│   └── clonezilla-live-XX.X.iso      # Клонирование (опционально)
│
W:\ (NTFS Tools)
├── 📁 TOOLS\
│   ├── 📁 WinPE_Portable\
│   │   ├── CrystalDiskInfo\
│   │   ├── DMDE\
│   │   ├── AOMEI_Partition_Assistant\
│   │   ├── MiniTool_Partition_Wizard\
│   │   ├── Victoria\
│   │   ├── RWEverything\
│   │   └── Recuva\
│   │
│   ├── 📁 Linux_Portable\
│   │   └── (скрипты для автоматизации в Linux)
│   │
│   └── 📁 CrossPlatform\
│       ├── 7-Zip\
│       └── Ventoy\
│
└── 📁 DATA\
    ├── 📁 disk_images\
    └── 📁 recovered_files\
```

📁 W:\TOOLS\Partition_Managers\
├── 📁 AOMEI_PA_Standard\
│   ├── PartitionAssistant.exe
│   └── README_AOMEI.txt  # шпаргалка: когда использовать
│
└── 📁 MiniTool_PW_Free\
    ├── PartitionWizard.exe
    └── README_MiniTool.txt  # шпаргалка: когда использовать

W:\ (NTFS, Tools)
└── 📁 Partition_Managers\
    ├── 📁 01_DiskGenius_6.0\          # 🥇 ОСНОВНОЙ
    │   ├── DiskGenius.exe
    │   ├── README_DiskGenius.md       # шпаргалка по горячим клавишам
    │   └── Tutorials\                 # скриншоты первых шагов
    │
    ├── 📁 02_MiniTool_13.5\           # 🥈 РЕЗЕРВНЫЙ
    │   ├── PartitionWizard.exe
    │   └── README_MiniTool.md
    │
    ├── 📁 03_AOMEI_10.10\             # 🥉 ОБУЧАЮЩИЙ
    │   ├── PartitionAssistant.exe
    │   └── README_AOMEI.md            # акцент на мастерах
    │
    └── 📄 Comparison_Matrix.md        # эта таблица в удобном формате






🔐 Золотое правило:  
80% задач закрываются: WinPE (CrystalDiskInfo + AOMEI + DMDE) + GParted Live
Остальные 20% — специализированные инструменты (подключайте по мере необходимости)






## 2️⃣ Кроссплатформенные утилиты (диагностика/восстановление)

### 🔧 Универсальные инструменты (работают везде)

| Утилита | Тип | Что умеет | GUI/CLI | Где доступна |
|---------|-----|-----------|---------|--------------|
| **TestDisk** | Восстановление разделов, загрузчиков | ✅ CLI | WinPE / Linux Live / macOS |
| **PhotoRec** | Восстановление файлов по сигнатурам | ✅ CLI (+ QPhotoRec GUI) | WinPE / Linux Live |
| **DMDE** | Редактирование секторов, восстановление | ✅ GUI + CLI | Win / Linux / macOS (портативная) |
| **ddrescue** | Клонирование «умирающих» дисков | ✅ CLI | Linux Live / Win (Cygwin/WSL) |
| **smartctl** (smartmontools) | SMART-диагностика дисков | ✅ CLI (+ gsmartcontrol GUI) | Win / Linux / macOS |
| **GParted Live** | Разметка, ФС, операции с разделами | ✅ GUI | ISO (запуск с Ventoy) |
| **Clonezilla** | Клонирование дисков/разделов | ✅ TUI (текстовый GUI) | ISO (запуск с Ventoy) |
| **Hiren's BootCD PE** | Набор утилит в WinPE | ✅ GUI | ISO (на базе Win10 PE) |

### 📊 Файловые операции (кроссплатформенные)

| Утилита | Назначение | Форматы | GUI/CLI |
|---------|-----------|---------|---------|
| **7-Zip** | Архивация/распаковка | ZIP, 7z, TAR, GZ, ISO | ✅ GUI + CLI |
| **dd** | Побитовое копирование | Любые образы | ✅ CLI |
| **rsync** | Синхронизация файлов | Любые | ✅ CLI |

---

## 3️⃣ GUI-утилиты для работы с дисками (по категориям)

### 📐 **Разметка и управление разделами**

| Утилита | Платформа | Возможности | Портативная | Цена |
|---------|-----------|-------------|-------------|------|
| **GParted** | Linux Live (ISO) | GPT/MBR, ФС, resize, copy, backup | ✅ (Live ISO) | Free |
| **KDE Partition Manager** | Linux (App) | Аналог GParted, интеграция с KDE | ❌ | Free |
| **GNOME Disks** (`gnome-disk-utility`) | Linux (App) | Простой GUI, SMART, бенчмарки | ❌ | Free |
| **AOMEI Partition Assistant** | Windows | MBR↔GPT, миграция ОС, клонирование | ✅ Std Edition | Free/Pro |
| **MiniTool Partition Wizard** | Windows | Восстановление разделов, тест поверхности | ✅ Free | Free/Pro |
| **EaseUS Partition Master** | Windows | Resize, клонирование, конвертация | ❌ | Free/Pro |
| **Disk Management** (`diskmgmt.msc`) | Windows | Базовые операции, сжатие томов | ✅ Встроено | Free |

> 💡 **Рекомендация для вас:** 
> - **GParted Live** (с Ventoy) — для сложных операций
> - **AOMEI/MiniTool** (в WinPE Стрельца) — для Windows-специфичных задач

---

### 🔍 **Диагностика и мониторинг**

| Утилита | Платформа | Что показывает | GUI/CLI | Портативная |
|---------|-----------|----------------|---------|-------------|
| **CrystalDiskInfo** | Windows | SMART, температура, здоровье | ✅ GUI | ✅ |
| **HD Tune** | Windows | SMART, тест поверхности, бенчмарки | ✅ GUI | ✅ Pro |
| **Victoria** | Windows | SMART, remap, тест секторов | ✅ GUI + CLI | ✅ |
| **gsmartcontrol** | Win / Linux / macOS | SMART (GUI для smartctl) | ✅ GUI | ⚠️ Требуется установка |
| **GNOME Disks** | Linux | SMART, бенчмарки, ФС | ✅ GUI | ✅ Встроено в GNOME |
| **smartctl** | Win / Linux / macOS | Полный SMART, самотесты | ✅ CLI | ✅ (smartmontools) |

> 💡 **Рекомендация:**
> - **Windows/WinPE**: CrystalDiskInfo + Victoria
> - **Linux Live**: gsmartcontrol + `smartctl`

---

### 💾 **Восстановление данных и разделов**

| Утилита | Платформа | Тип восстановления | GUI/CLI | Портативная |
|---------|-----------|-------------------|---------|-------------|
| **DMDE** | Win / Linux / macOS | Разделы, файлы, RAW | ✅ GUI + CLI | ✅ Free (огр. 4000 файлов) |
| **R-Studio** | Win / Linux / macOS | Сложные случаи, RAID, сеть | ✅ GUI | ⚠️ Платная |
| **UFS Explorer** | Win / Linux / macOS | Профессиональное, ФС | ✅ GUI | ⚠️ Платная |
| **TestDisk** | Win / Linux / macOS | Загрузчик, разделы | ✅ CLI | ✅ Free |
| **PhotoRec** | Win / Linux / macOS | Файлы по сигнатурам | ✅ CLI (+ QPhotoRec GUI) | ✅ Free |
| **Recuva** | Windows | Удалённые файлы | ✅ GUI | ✅ Free |
| **extundelete** | Linux | Удалённые файлы ext3/4 | ✅ CLI | ✅ Free |

> 💡 **Рекомендация для вас:**
> - **Базовый уровень**: DMDE (Free) + TestDisk
> - **Продвинутый**: R-Studio (если часто работаете с RAID/сложными случаями)

---

### 🔄 **Клонирование и бэкап**

| Утилита | Платформа | Особенности | GUI/CLI | Портативная |
|---------|-----------|-------------|---------|-------------|
| **Clonezilla** | Live ISO | Клонирование, образы, multicast | ✅ TUI | ✅ (ISO) |
| **ddrescue** | Linux / WSL | Спасение с bad-секторов | ✅ CLI | ✅ В Live-образах |
| **HDD Raw Copy** | Windows | Побитовое копирование | ✅ GUI | ✅ Portable |
| **Macrium Reflect** | Windows | Инкрементные бэкапы, VSS | ✅ GUI | ⚠️ Free урезанная |
| **Acronis True Image** | Win / Boot ISO | Полные бэкапы, облако | ✅ GUI | ⚠️ Платная |
| **dd** | Linux / macOS | Универсальное копирование | ✅ CLI | ✅ Встроено |

> 💡 **Рекомендация:**
> - **Для «умирающих» дисков**: ddrescue (Linux Live)
> - **Для клонирования исправных**: Clonezilla или Macrium Reflect

---

### 🛠️ **Модификация и работа с образами**

| Утилита | Платформа | Что умеет | GUI/CLI |
|---------|-----------|-----------|---------|
| **Rufus** | Windows | Создание загрузочных флешек | ✅ GUI |
| **Ventoy** | Win / Linux | Мультизагрузочная флешка | ✅ GUI + CLI |
| **balenaEtcher** | Win / Linux / macOS | Запись образов | ✅ GUI |
| **PowerISO / UltraISO** | Windows | Работа с ISO, конвертация | ✅ GUI |
| **7-Zip** | Win / Linux | Распаковка ISO/IMG | ✅ GUI + CLI |
| **mkisofs / genisoimage** | Linux | Создание ISO | ✅ CLI |

---

## 4️⃣ Итоговая матрица: что добавить на вашу флешку

### ✅ Must Have (базовый набор)

```
V:\ (Ventoy exFAT)
├── 📁 ISO\
│   ├── WinPE_Strelec_vX.iso          # Windows-утилиты
│   ├── SystemRescue_XX.X.iso         # Linux + ddrescue/testdisk
│   ├── gparted-live-XX.X.iso         # Разметка/ФС
│   ├── memtest86-usb.iso             # Тест ОЗУ
│   └── clonezilla-live-XX.X.iso      # Клонирование (опционально)
│
W:\ (NTFS Tools)
├── 📁 TOOLS\
│   ├── 📁 WinPE_Portable\
│   │   ├── CrystalDiskInfo\
│   │   ├── DMDE\
│   │   ├── AOMEI_Partition_Assistant\
│   │   ├── MiniTool_Partition_Wizard\
│   │   ├── Victoria\
│   │   ├── RWEverything\
│   │   └── Recuva\
│   │
│   ├── 📁 Linux_Portable\
│   │   └── (скрипты для автоматизации в Linux)
│   │
│   └── 📁 CrossPlatform\
│       ├── 7-Zip\
│       └── Ventoy\
│
└── 📁 DATA\
    ├── 📁 disk_images\
    └── 📁 recovered_files\
```

---



