

---

###  Плагины Ventoy

**Ключевые плагины для вашего сценария:**

| Плагин | Назначение | Файл конфигурации |
|--------|------------|-------------------|
| **Persistence** | Сохранение данных в Live-сессиях Linux | ventoy.json [[24]] |
| **Theme** | Кастомизация меню загрузки | ventoy/theme/ [[71]] |
| **Auto Menu** | Автоматическая загрузка по умолчанию | ventoy.json |
| **Injection** | Внедрение драйверов в Windows ISO | ventoy.json |

**Пример ventoy.json для persistence:**
```json
{
    "persistence": [
        {
            "image": "/ISO/Linux/ubuntu-24.04-desktop.iso",
            "backend": "/ventoy/persistence/ubuntu_casper.dat",
            "autosel": 1
        }
    ]
}
```

---

## 📊 Сводная таблица действий

| Шаг | Действие | Инструмент | Время | Критично |
|-----|----------|------------|-------|----------|
| 1 | Проверка на подлинность | ValiDrive + H2testw | 30 сек + 2-4 часа | **Да** |
| 2 | Тест скорости | CrystalDiskMark | 5 минут | Нет |
| 3 | Установка Ventoy | Ventoy2Disk.exe | 2 минуты | **Да** |
| 4 | Настройка Secure Boot | Ventoy2Disk.exe (опция) | 30 секунд | **Да** |
| 5 | Создание структуры папок | Проводник Windows | 10 минут | Нет |
| 6 | Настройка плагинов | VentoyPlugson.exe | 15 минут | Рекомендуется |
| 7 | Тест загрузки | Тестовый ПК/ноутбук | 10 минут | **Да** |

---



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

## 🔍 ИССЛЕДОВАНИЕ И АНАЛИЗ СТРУКТУР ФЛЕШЕК

### 📊 ОЦЕНКА ОПТИМАЛЬНОСТИ СТРУКТУРЫ РАЗДЕЛОВ

**Ваша комбинация: Ventoy 300 ГБ + Data 168 ГБ**

| Параметр | Оценка | Комментарий |
|----------|--------|-------------|
| **Соотношение объёмов** | ⚠️ 7/10 | 300 ГБ для Ventoy может быть недостаточно при росте коллекции ISO |
| **Изоляция данных** | ✅ 10/10 | BitLocker на Data разделе — лучшая практика 2026 [[24]] |
| **Масштабируемость** | ✅ 9/10 | GPT позволяет добавлять разделы без потери данных [[49]] |
| **Совместимость** | ✅ 10/10 | exFAT + NTFS оптимальны для Windows 11 + Linux [[21]] |

**Критическая рекомендация:** Рассмотрите **400 ГБ Ventoy + 68 ГБ Data** для будущего роста коллекции ISO.

---

## ✅ ОБНОВЛЁННАЯ СТРУКТУРА С ЗАПОЛНЕННЫМИ "..."

### **РАЗДЕЛ 1: VENTOY (exFAT — 300/400 ГБ)**

```
VENTOY/
├── ISO/
│   ├── Windows/
│   │   ├── Win11_24H2_Official.iso
│   │   ├── Win11_23H2_Official.iso
│   │   ├── Win10_22H2_Official.iso
│   │   ├── Win10_21H2_Official.iso
│   │   ├── Win7_SP1_x64_Ultimate.iso
│   │   └── WinPE/
│   │       ├── Sergei_Strelec_2026.03.03_ENG.iso ⭐
│   │       ├── Hiren's_BootCD_PE_x64_2025.iso
│   │       ├── FirPE_V2.1.1.iso
│   │       ├── MediCat_USB_2025.iso
│   │       └── Custom/
│   │           └── WinPE_Custom_v1.0.iso
│   ├── Linux/
│   │   ├── Ubuntu/
│   │   │   ├── ubuntu-24.04.2-desktop-amd64.iso
│   │   │   └── ubuntu-22.04.5-desktop-amd64.iso
│   │   ├── Debian/
│   │   │   └── debian-12.9.0-amd64-netinst.iso
│   │   ├── Kali/
│   │   │   └── kali-linux-2025.4-live-amd64.iso
│   │   ├── Mint/
│   │   │   └── linuxmint-22.1-cinnamon-64bit.iso
│   │   └── Rescue/
│   │       ├── systemrescue-11.00-amd64.iso
│   │       └── clonezilla-live-3.2.1-15-amd64.iso
│   ├── Utilities/
│   │   ├── Clonezilla_2025.iso
│   │   ├── GParted_Live_1.7.0.iso
│   │   ├── MemTest86_11.2.iso
│   │   ├── DBAN_2.3.0.iso
│   │   └── Ventoy_Plugin_Test.iso
│   └── _Archive/
│       ├── 2025-Q4/
│       └── 2026-Q1/
├── ventoy/
│   ├── ventoy.json
│   ├── ventoy.log
│   ├── theme/
│   │   ├── background.png
│   │   ├── font.txt
│   │   └── ventoy.theme
│   ├── persistence/
│   │   ├── ubuntu_casper.dat
│   │   ├── kali_persistence.dat
│   │   └── mint_persistence.dat
│   └── plugins/
│       ├── auto_menu.json
│       └── injection.json
├── Docs/
│   ├── Manuals/
│   │   ├── Windows_Deployment_Guide.md
│   │   ├── Linux_Installation_Guide.md
│   │   └── Network_Troubleshooting_Guide.md
│   ├── Cheatsheets/
│   │   ├── PowerShell_Commands_2026.pdf [[39]]
│   │   ├── Network_Commands_Cheatsheet.pdf [[106]]
│   │   ├── Linux_Basic_Commands.pdf
│   │   └── DISM_Commands_Reference.pdf
│   ├── Configs/
│   │   ├── answer_files/
│   │   │   ├── win11_autounattend.xml
│   │   │   └── win10_autounattend.xml
│   │   ├── network_configs/
│   │   │   └── static_ip_templates.txt
│   │   └── registry_templates/
│   │       └── optimization.reg
│   ├── Templates/
│   │   ├── Runbook_Template.md [[62]]
│   │   ├── SOP_Template.md [[63]]
│   │   ├── Incident_Report_Template.docx
│   │   └── IT_Asset_Inventory_Template.xlsx [[124]]
│   ├── WinPE_Comparison_2026.md
│   ├── Strelec_Utils_List.xlsx
│   └── README.md
├── Scripts/
│   ├── PowerShell/
│   │   ├── 01_System_Info/
│   │   │   ├── Get-SystemInfo.ps1
│   │   │   ├── Get-NetworkConfig.ps1
│   │   │   └── Get-DriverList.ps1
│   │   ├── 02_Deployment/
│   │   │   ├── New-LocalUser.ps1
│   │   │   ├── Join-Domain.ps1
│   │   │   └── Install-Applications.ps1
│   │   ├── 03_Maintenance/
│   │   │   ├── Clear-EventLogs.ps1
│   │   │   ├── Update-Windows.ps1
│   │   │   └── Backup-Registry.ps1
│   │   ├── 04_Network/
│   │   │   ├── Test-Connectivity.ps1
│   │   │   ├── Reset-NetworkAdapter.ps1
│   │   │   └── Get-DNSCache.ps1
│   │   └── README_PowerShell.md
│   ├── Bash/
│   │   ├── system_info.sh
│   │   ├── backup_scripts.sh
│   │   └── network_diag.sh
│   ├── Python/
│   │   ├── requirements.txt
│   │   ├── inventory_scanner.py
│   │   └── config_parser.py
│   └── README.md
├── Drivers/
│   ├── Network/
│   │   ├── Intel/
│   │   ├── Realtek/
│   │   ├── Broadcom/
│   │   └── Qualcomm/
│   ├── Storage/
│   │   ├── Intel_RST/
│   │   ├── AMD_Chipset/
│   │   ├── NVMe_Generic/
│   │   └── RAID/
│   ├── Video/
│   │   ├── NVIDIA/
│   │   ├── AMD/
│   │   └── Intel_iGPU/
│   ├── Chipset/
│   │   ├── Intel/
│   │   └── AMD/
│   ├── Audio/
│   │   ├── Realtek/
│   │   └── Conexant/
│   ├── SDI_Offline_Pack/
│   │   └── Snappy_Driver_Installer_Origin/ [[55]]
│   └── README_Drivers.md
├── Software/
│   ├── Portable/
│   │   ├── Sysinternals_Suite/ [[97]]
│   │   ├── NirLauncher_v1.30.22/ [[87]]
│   │   ├── PuTTY/
│   │   ├── WinSCP/
│   │   ├── 7-Zip_Portable/
│   │   ├── Notepad++_Portable/
│   │   ├── HWMonitor/
│   │   ├── CrystalDiskInfo/
│   │   ├── TeamViewer_QuickSupport/
│   │   └── AnyDesk/
│   ├── Diagnostics/
│   │   ├── MemTest86/
│   │   ├── Victoria_SSD_HDD/
│   │   ├── HDDScan/
│   │   └── FurMark/
│   ├── Recovery/
│   │   ├── Recuva_Portable/
│   │   ├── DMDE_Portable/
│   │   ├── TestDisk/
│   │   └── PhotoRec/
│   ├── Network/
│   │   ├── Wireshark_Portable/ [[1]]
│   │   ├── Nmap/
│   │   ├── Advanced_IP_Scanner/
│   │   └── Angry_IP_Scanner/
│   └── README_Software.md
└── _Archive/
    ├── 2025-Q4/
    ├── 2026-Q1/
    └── README_Archive.md
```

---

### **РАЗДЕЛ 2: DATA (NTFS + BitLocker — ~168 ГБ)**

```
Data/
├── Secure/ (BitLocker — обязательно включить!)
│   ├── Credentials/
│   │   ├── password_manager.kdbx (KeePass)
│   │   └── ssh_keys/
│   ├── Licenses/
│   │   ├── Windows_Keys/
│   │   ├── Software_Licenses/
│   │   └── Subscription_Logins.xlsx
│   ├── Private_Configs/
│   │   ├── vpn_configs/
│   │   └── email_profiles/
│   └── README_Secure.md
├── Backup/
│   ├── Ventoy_Config/
│   │   ├── ventoy.json.backup_2026-03-28
│   │   └── theme_backup/
│   ├── ISO_Manifest/
│   │   └── iso_checksums.sha256
│   └── Scripts_Backup/
│       └── scripts_backup_2026-03-28.zip
├── Custom_ISO_Work/
│   ├── WinPE_Custom/
│   │   ├── ADK_Working_Files/
│   │   ├── mount/
│   │   ├── packages/
│   │   ├── drivers/
│   │   └── output/
│   ├── Linux_Custom/
│   │   └── cubic_projects/
│   └── ISO_Tools/
│       ├── oscdimg.exe
│       ├── dism_gui.exe
│       └── AnyBurn_Portable/
├── Documentation/
│   ├── Client_Notes/
│   ├── Project_Documentation/
│   ├── Learning_Notes/
│   │   ├── DevOps_Notes/
│   │   ├── Network_Notes/
│   │   └── Security_Notes/
│   └── Certificates/
│       └── study_materials/
├── Downloads/
│   ├── ISO_Staging/
│   ├── Driver_Packs/
│   │   ├── SDIO_R312/ [[59]]
│   │   └── SamDrivers_25.11/ [[54]]
│   └── Software_Staging/
├── Tools_Development/
│   ├── VSCode_Portable/
│   ├── Git_Portable/
│   ├── Python_3.12_Portable/
│   └── Docker_Desktop_Offline_Installer/
└── _Temp/
    └── (временные файлы, можно чистить)
```

---

## 🛠️ НАБОР ИНСТРУМЕНТОВ ДЛЯ НАЧИНАЮЩЕГО СИСАДМИНА

### 📌 УРОВЕНЬ 1: БАЗОВЫЕ (Освоить в первые 1-3 месяца)

| Категория | Инструмент | Зачем | Когда использовать |
|-----------|------------|-------|-------------------|
| **Диагностика** | **Sysinternals Suite** [[97]] | Анализ процессов, реестра, диска | При любых проблемах с Windows |
| **Диагностика** | **CrystalDiskInfo** | Проверка здоровья SSD/HDD | Перед установкой ОС, при подозрении на диск |
| **Диагностика** | **HWMonitor** | Мониторинг температур, напряжений | При перегреве, нестабильности |
| **Сеть** | **PuTTY** | SSH/RDP подключение к серверам | Работа с Linux серверами |
| **Сеть** | **Advanced IP Scanner** | Сканирование сети, поиск устройств | При настройке сети |
| **Сеть** | **Wireshark Portable** [[1]] | Анализ сетевого трафика | При проблемах с подключением |
| **Драйверы** | **Snappy Driver Installer Origin** [[55]] | Офлайн установка драйверов | После чистой установки Windows |
| **Утилиты** | **7-Zip Portable** | Архивация, работа с образами | Постоянно |
| **Утилиты** | **Notepad++ Portable** | Редактирование конфигов, скриптов | Постоянно |
| **Резервное копирование** | **Clonezilla** [[1]] | Создание образов дисков | Перед крупными изменениями |
| **Восстановление** | **Recuva Portable** | Восстановление удалённых файлов | При случайном удалении |
| **Скрипты** | **PowerShell 7** [[41]] | Автоматизация задач Windows | Для рутинных операций |
| **WinPE** | **Sergei Strelec** [[1]] | Экстренная загрузка, восстановление | При нерабочей ОС |
| **Документация** | **IT Asset Inventory Template** [[124]] | Учёт оборудования, лицензий | При начале работы с клиентом |

---

### 📌 УРОВЕНЬ 2: ПРОДВИНУТЫЕ (3-6 месяцев)

| Категория | Инструмент | Зачем | Когда осваивать |
|-----------|------------|-------|----------------|
| **Автоматизация** | **Ansible** [[9]] | Конфигурация серверов, деплой | После освоения PowerShell |
| **Мониторинг** | **Zabbix** [[3]] | Мониторинг серверов и сетей | При управлении 5+ серверами |
| **Контейнеры** | **Docker** | Развёртывание приложений | Для DevOps направления |
| **Сеть** | **Nmap** | Сканирование портов, безопасность | При настройке фаерволов |
| **Деплой** | **Windows ADK + WinPE** [[116]] | Создание custom образов | При массовом развёртывании |
| **Документация** | **Runbook Templates** [[62]] | Стандартизация процедур | При работе в команде |
| **Виртуализация** | **VirtualBox/VMware** | Тестирование в изоляции | Для безопасного тестирования |
| **Безопасность** | **Kali Linux** [[3]] | Тестирование на уязвимости | При изучении безопасности |

---

### 📌 УРОВЕНЬ 3: ЭКСПЕРТНЫЕ (6-12+ месяцев)

| Категория | Инструмент | Зачем | Когда осваивать |
|-----------|------------|-------|----------------|
| **CI/CD** | **Jenkins/GitLab CI** | Автоматизация деплоя | При переходе в DevOps |
| **IaC** | **Terraform** | Инфраструктура как код | При работе с облаками |
| **Конфигурация** | **Puppet/Chef** [[8]] | Управление конфигурациями | В больших инфраструктурах |
| **Логи** | **ELK Stack** | Централизованное логирование | При 10+ серверах |
| **Облака** | **AWS/Azure CLI** | Управление облачными ресурсами | При миграции в облако |
| **Безопасность** | **Security Runbooks** [[70]] | Реагирование на инциденты | При работе с безопасностью |

---

## 🎯 КРИТИЧЕСКАЯ ОЦЕНКА СТРУКТУРЫ

### ✅ Сильные стороны

| Аспект | Оценка | Обоснование |
|--------|--------|-------------|
| **Модульность** | 9/10 | Чёткое разделение по категориям |
| **Расширяемость** | 10/10 | `_Archive/` и подпапки позволяют расти |
| **Документация** | 9/10 | Templates для runbook/SOP [[62]][[63]] |
| **Безопасность** | 10/10 | BitLocker на Data разделе [[24]] |
| **Портативность** | 10/10 | Все инструменты portable [[78]] |

### ⚠️ Слабые стороны (требуют внимания)

| Аспект | Риск | Рекомендация |
|--------|------|--------------|
| **Сложность для новичка** | Высокий порог входа | Начать с Уровня 1, остальное добавлять постепенно |
| **Требует дисциплины** | Без ведения архива — хаос | Создать правило: "Новая версия → старая в _Archive/" |
| **Объём 300 ГБ может не хватить** | Через 6-12 месяцев | Мониторить заполнение, планировать апгрейд |
| **Время на первоначальную настройку** | 8-12 часов | Разбить на этапы по 2 часа в день |

---

## 📋 ПЛАН ЗАПОЛНЕНИЯ ФЛЕШКИ (ПОЭТАПНО)

| Этап | Действие | Время | Приоритет |
|------|----------|-------|-----------|
| **1** | Ventoy установка + Secure Boot | 30 мин | 🔴 Критично |
| **2** | Структура папок (без контента) | 1 час | 🔴 Критично |
| **3** | Копирование WinPE ISO (Strelec + Hiren's) | 30 мин | 🔴 Критично |
| **4** | Копирование Windows ISO (11 + 10) | 1 час | 🔴 Критично |
| **5** | Sysinternals + NirLauncher | 30 мин | 🟡 Важно |
| **6** | Snappy Driver Installer | 30 мин | 🟡 Важно |
| **7** | PowerShell скрипты (базовые) | 2 часа | 🟡 Важно |
| **8** | Документация templates | 1 час | 🟢 Желательно |
| **9** | Linux ISO (Ubuntu + Rescue) | 1 час | 🟢 Желательно |
| **10** | BitLocker шифрование Data раздела | 30 мин | 🔴 Критично |

---

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

# 📋 SUMMARY ДИАЛОГА — ПОДГОТОВКА МУЛЬТИЗАГРУЗОЧНЫХ ФЛЕШЕК

---

## 🎯 ИСХОДНЫЕ ДАННЫЕ

| Параметр | Значение |
|----------|----------|
| **Пользователь** | Начинающий DevOps/сетевой администратор |
| **ОС хоста** | Windows 11 |
| **Носители** | 2× USB флешки по 512 ГБ (новые) |
| **Назначение** | Мультизагрузочная среда на базе Ventoy |
| **Требования** | Установка ОС, драйверы, диагностика, восстановление, скрипты, документация |

---

## ✅ ПРИНЯТЫЕ РЕШЕНИЯ

### 1️⃣ Разметка флешек (GPT)

```
┌─────────────────────────────────────────────────────────────┐
│  Раздел 1: Ventoy (exFAT) — 300-400 ГБ                      │
│  Раздел 2: Data (NTFS + BitLocker) — 168-68 ГБ              │
│  EFI System Partition — 32 МБ                               │
└─────────────────────────────────────────────────────────────┘
```

**Обоснование:** GPT + Secure Boot для Windows 11, изоляция данных с шифрованием [[24]][[49]].

---

### 2️⃣ Ventoy настройки

| Параметр | Значение |
|----------|----------|
| **Схема разделов** | GPT |
| **Secure Boot** | ВКЛЮЧЕНО (требуется для Windows 11) [[1]] |
| **Файловая система** | exFAT (Ventoy) + NTFS (Data) |
| **Версия Ventoy** | 1.1.10+ (актуальная 2026) [[5]] |
| **Reserved Space** | 68-168 ГБ для второго раздела |

---

### 3️⃣ Топ-3 WinPE образов (ранжировано по 20 параметрам)

| Место | Образ | Версия | Размер | Оценка |
|-------|-------|--------|--------|--------|
| **🥇 1** | Sergei Strelec | 2026.03.03 | 3.2 ГБ | 186/200 |
| **🥈 2** | FirPE | V2.1.1 | 2.5 ГБ | 180/200 |
| **🥉 3** | Hiren's BootCD PE | 2025 | 3.0 ГБ | 163/200 |

**Рекомендация:** Strelec (основной) + Hiren's (резерв) [[1]][[36]][[44]].

---

### 4️⃣ Отдельный WinPE раздел vs ISO в Ventoy

**Решение:** ISO в Ventoy (без отдельного раздела)

| Критерий | Решение |
|----------|---------|
| **Для начинающего** | Проще в настройке и обновлении |
| **Secure Boot** | Поддерживается Ventoy 1.0.76+ [[1]] |
| **Гибкость** | Легко заменить/добавить ISO |
| **Время настройки** | 2-3 часа vs 10-15 часов для отдельного раздела |

---

### 5️⃣ Структура папок (Вариант 3: Professional)

**VENTOY раздел:**
```
├── ISO/ (Windows, Linux, Utilities, _Archive)
├── ventoy/ (ventoy.json, theme, persistence, plugins)
├── Docs/ (Manuals, Cheatsheets, Configs, Templates)
├── Scripts/ (PowerShell, Bash, Python)
├── Drivers/ (Network, Storage, Video, Chipset, SDI)
└── Software/ (Portable, Diagnostics, Recovery, Network)
```

**DATA раздел (BitLocker):**
```
├── Secure/ (Credentials, Licenses, Private_Configs)
├── Backup/ (Ventoy_Config, ISO_Manifest, Scripts_Backup)
├── Custom_ISO_Work/ (WinPE_Custom, Linux_Custom, ISO_Tools)
├── Documentation/ (Client_Notes, Learning_Notes, Certificates)
├── Downloads/ (ISO_Staging, Driver_Packs, Software_Staging)
└── Tools_Development/ (VSCode, Git, Python, Docker)
```

---

### 6️⃣ Набор инструментов для начинающего сисадмина

| Уровень | Период | Ключевые инструменты |
|---------|--------|---------------------|
| **Уровень 1** | 1-3 месяца | Sysinternals, CrystalDiskInfo, PuTTY, SDI Origin, PowerShell 7, Clonezilla, Strelec [[97]][[55]][[41]] |
| **Уровень 2** | 3-6 месяцев | Ansible, Zabbix, Docker, Nmap, Windows ADK, Runbook Templates [[9]][[3]][[116]] |
| **Уровень 3** | 6-12+ месяцев | Jenkins/GitLab CI, Terraform, ELK Stack, AWS/Azure CLI, Security Runbooks [[70]] |

---

## 📋 ПЛАН ДЕЙСТВИЙ (10 этапов)

| # | Этап | Время | Приоритет |
|---|------|-------|-----------|
| 1 | Ventoy установка + Secure Boot | 30 мин | 🔴 |
| 2 | Структура папок (без контента) | 1 час | 🔴 |
| 3 | Копирование WinPE ISO (Strelec + Hiren's) | 30 мин | 🔴 |
| 4 | Копирование Windows ISO (11 + 10) | 1 час | 🔴 |
| 5 | Sysinternals + NirLauncher | 30 мин | 🟡 |
| 6 | Snappy Driver Installer | 30 мин | 🟡 |
| 7 | PowerShell скрипты (базовые) | 2 часа | 🟡 |
| 8 | Документация templates | 1 час | 🟢 |
| 9 | Linux ISO (Ubuntu + Rescue) | 1 час | 🟢 |
| 10 | BitLocker шифрование Data раздела | 30 мин | 🔴 |

**Итого:** ~8-10 часов на полную настройку одной флешки.

---

## ⚠️ КРИТИЧЕСКИЕ ЗАМЕЧАНИЯ

| Риск | Рекомендация |
|------|--------------|
| **300 ГБ может не хватить** | Мониторить заполнение, рассмотреть 400 ГБ для Ventoy |
| **Сложность для новичка** | Начать с Уровня 1 инструментов, остальное добавлять постепенно |
| **Требуется дисциплина** | Правило: "Новая версия → старая в _Archive/" с датированием |
| **Время на настройку** | Разбить на этапы по 2 часа в день (5 дней) |

---

## 🔄 СЛЕДУЮЩИЕ ВОЗМОЖНЫЕ ШАГИ

1. **Инструкция по custom WinPE ISO** (Windows ADK + DISM пошагово)
2. **Шаблон ventoy.json** с готовыми persistence настройками для Ubuntu/Kali
3. **Скрипт автоматизации** резервного копирования структуры на вторую флешку
4. **Чек-лист тестирования** загрузки на UEFI + Legacy оборудовании

---

## 📌 КЛЮЧЕВЫЕ ССЫЛКИ ИЗ ДИАЛОГА

| Ресурс | Назначение |
|--------|------------|
| ventoy.net | Официальный сайт Ventoy [[1]] |
| Sergei Strelec | WinPE образ (ежемесячные обновления) [[1]] |
| Hiren's BootCD | Легальный WinPE образ [[36]] |
| FirPE | Компактный WinPE с двойным ядром [[44]] |
| Sysinternals Suite | Набор утилит для диагностики Windows [[97]] |
| Snappy Driver Installer | Офлайн пакет драйверов [[55]] |







### Минимальный набор инструментов для начинающего сисадмина (Обязательный стартовый комплект (поместится на 50 ГБ))
✅ ОБРАЗЫ:
• Win10_22H2_x64_RU.iso (~4.8 ГБ)
• Win11_24H2_x64_RU.iso (~5.2 ГБ)
• WinPE_Sergei_Strelec_2026.iso (~4.5 ГБ) ⭐

✅ ДРАЙВЕРЫ:
• Папка с сетевыми драйверами (LAN/WiFi) для Win10/11
• Драйверы NVMe/RAID-контроллеров (частая проблема при установке)

✅ УТИЛИТЫ:
• Sysinternals Suite (Process Explorer, Autoruns, DiskMon) [[45]]
• Wireshark Portable (анализ сетевого трафика) [[45]]
• CrystalDiskInfo (диагностика дисков)
• Recuva Portable (восстановление файлов)
• NTPWEdit (сброс паролей локальных учётных записей) [[70]]
• WinMTR (диагностика сети: ping+traceroute) [[77]]

✅ СКРИПТЫ:
• Простой .bat-файл для автоматической установки драйверов через DISM [[63]]
• PowerShell-скрипт для сбора системной информации (Get-ComputerInfo)

✅ ДОКУМЕНТАЦИЯ:
• Шпаргалка по командам DISM, SFC, CHKDSK
• Список типовых проблем и решений (текстовый файл)
