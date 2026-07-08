# Требования:
- следи за правильностью/верностью/точностью своих ответов
- всегда задавайся вопросом об однозначности своих выводов перед ответом
- если для однозначности выводов нужен дополнительный контекст - уточняй у меня перед формированием ответа
- если однозначность выводов не подтверждена собирай дополнительную информацию и проводи дополнительные проверки
- ответ должен быть проверен и протестирован
- ответ должен представлять полную/структурированную/систематизированную инженерную инструкцию разбитую на логические блоки с понятными/однозначными комментариями
- не давай ответ пока он не прошел все тесты и проверки
- формат ответа: 
   - список блоков 
   - для каждого блока:
      - осмысленное название блока с понятными/однозначными комментариями
      - список действий
      - для каждого действия:
         - осмысленное название действия с понятными/однозначными комментариями в виде таблицы(формат таблицы придумай сам в контексте наглядного представления действия и связанного с ним окружения)

# Цель: 
- создание инженерной инструкции - профессиональный алгоритм действий для создания оптимизированного/отчищенного «золотого образа» с использованием Sophia Script

# Задания:
- проанализируй загруженного скриншота
- дополни/исправь инструкцию там где это нужно
- критически проанализируй полученную инструкцию
- систематизируй результаты анализа
- исправь, дополни, отредактируй там где нужно
- отдай итоговую выверенную инструкцию для создания «золотого образа»




<!-- 
Экранирование от MDM/Intune/Autopilot: Применяете команды отключения служб удаленного управления (DmEnrollmentSvc, WmpNetworkSvc) и прописываете блокирующие ключи в ветку реестра HKLM\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\MDM (параметр DisableMDM=1) и параметры Autopilot. -->


<!-- ```
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
└── 03A.11. Решение типовых проблем (Troubleshooting) -->



=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================
---

## Логика порядка применения

Порядок определяется **принципом зависимостей**: каждый последующий шаг предполагает, что предыдущий уже завершён и не будет перезаписан. Ключевые правила цепочки:

> `Снимок → Заморозка фона → Очистка AppX → Обновления → Реестр HKLM → Default User → Глубокая очистка → Верификация → Sysprep`

Нарушение порядка приводит к: восстановлению удалённых AppX через Store, перезаписи реестровых твиков Cumulative Update, сбою Sysprep на `PartialProductKey`.

---

## Таблица А. Связка: логический порядок инструментов и скриптов

| № | Этап (что происходит) | Инструмент / Скрипт | Зона ответственности | Режим применения | Риск пропуска / нарушения порядка |
|---|---|---|---|---|---|
| **0** | **Точка отсчёта: снимок ВМ** | VirtualBox Snapshot «Fresh Install» | Создание контрольной точки ДО любых изменений | Ручной, 1 раз | Нет точки отката — при сбое Sysprep потеря 3–6 часов работы |
| **1** | **Заморозка фоновой активности** | `sc config` + `schtasks /Change /Disable` + PowerShell `Set-Service` | Остановка WU, Store, DoSvc, DiagTrack, телеметрия-задачи планировщика | Скрипт — автомат | Store восстановит удалённые AppX во время шага 2; WU подтянет CU и сломает порядок обновлений |
| **2** | **Удаление Bloatware / AppX** | `Remove-AppxProvisionedPackage` (PowerShell) + BCUninstaller | Вырезание provisioned UWP-пакетов из образа для всех пользователей | Скрипт — автомат | Каждый лишний AppX с PartialProductKey = Fatal Error в Sysprep |
| **3** | **Offline-обновления (.msu)** | `DISM /Add-Package` + `wusa.exe /quiet /norestart` | SSU → CU → .NET CU → Defender definitions через Shared Folder | Скрипт — полуавтомат | Без SSU первым — CU не установится; без обновлений до реестра — CU перезапишет твики |
| **4** | **Твики реестра HKLM** | Sophia Script (HKLM-профиль) + `.reg`-файлы | Телеметрия, Copilot, Recall, Delivery Opt, SkipRearm=1, политики gpedit | Скрипт — по профилю | Без SkipRearm=1 — Sysprep падает на повторном запуске; без телеметрии — образ «звонит домой» |
| **5** | **Настройка Default User (HKCU-шаблон)** | `reg load/unload HKLM\DU` + ручной `.reg` | Монтирование NTUSER.DAT, твики ContentDelivery, панель задач, тема | Скрипт + ручной контроль | Без этого шага каждый новый пользователь на клиенте получает «грязный» старт с рекламой |
| **6** | **Глубокая очистка + WinSxS** | `DISM /Cleanup-Image /StartComponentCleanup /ResetBase` + PowerShell | WinSxS, Temp, SoftwareDistribution, логи событий, hiberfil, pagefile | Скрипт — автомат | Без /ResetBase образ на 3–8 ГБ тяжелее; после /ResetBase откат обновлений невозможен — только вперёд |
| **7** | **Удаление гостевых дополнений ВМ** | `wmic product` / PowerShell `Get-WmiObject Win32_Product` | Вырезание VirtualBox Guest Additions из образа | Ручной | GA в образе = синий экран или зависание на реальном железе клиента |
| **8** | **Финальная верификация** | `sfc /scannow` + `DISM /CheckHealth` + `Get-AppxProvisionedPackage` | Целостность ОС, отсутствие pending reboot, проверка AppX, SkipRearm | Скрипт — автомат | Пропуск верификации = риск Fatal Error в Sysprep без понятной причины |
| **9** | **Снимок ВМ «Before Sysprep»** | VirtualBox Snapshot | Последняя точка отката перед необратимой операцией | Ручной, 1 раз | Нет возможности повторить Sysprep с другими параметрами без полного пересборки |
| **10** | **Запечатывание (Sysprep)** | `sysprep /generalize /oobe /shutdown /unattend:unattend.xml` | Генерализация: удаление SID, аппаратной привязки, подготовка OOBE | Ручной — строго однократно | Повторный запуск ВМ после shutdown = повреждение образа; нарушение порядка шагов = Fatal Error |
| **11** | **Захват образа WIM / ESD** | `DISM /Capture-Image /Compress:max` из WinPE / DiskGenius | Снятие финального WIM/ESD с холодного диска выключенной ВМ | Ручной из WinPE | Захват с «тёплого» диска = артефакты в образе; без `/Compress:max` = лишние 2–4 ГБ |

---

## Таблица Б. Направления оптимизации: сущности, инструменты, ссылки

| № | Направление (Сущность ОС) | Конкретные объекты воздействия | Эффект для образа и клиента | Топ-2/3 инструмента / ссылки на скрипты | Применимость к образу-болванке |
|---|---|---|---|---|---|
| **1** | **AppX / UWP provisioned пакеты** | Xbox*, Cortana, Widgets (WebExperience), Teams/Chat, BingNews, BingWeather, Zune*, People, Skype, MixedReality, Solitaire, FeedbackHub, OfficeHub | Главная причина сбоя Sysprep устранена; образ на 1–3 ГБ легче | 1. `Remove-AppxProvisionedPackage` (встроенный PowerShell) 2. [Win11Debloat](https://github.com/Raphire/Win11Debloat) — параметрический PS-скрипт 3. [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) → `Uninstall-UWPApps` | ✅ Обязательно |
| **2** | **Windows 11 AI-компоненты** | Recall (WindowsAI), Copilot (Shell), Windows AI Platform, BingSearch в поиске | Снижение фоновой нагрузки; блокировка утечки данных с клиентских ПК | 1. Реестр: `TurnOffWindowsAIFeatures=1`, `DisableAIDataAnalysis=1` 2. [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) → функции Copilot/Recall 3. `DISM /Remove-Package` для WindowsAI | ✅ Обязательно (Win11 24H2+) |
| **3** | **Телеметрия и CEIP** | DiagTrack, dmwappushservice, WerSvc, SQMClient, Customer Experience задачи планировщика | Полная блокировка телеметрии в образе; соответствие политикам ИБ | 1. [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) → `DiagTrackService -Disable`, `DiagnosticDataLevel -Minimal` 2. [O&O ShutUp10++](https://www.oo-software.com/en/shutup10) — экспорт `.cfg` для тихого применения 3. Групповые политики: `gpedit.msc` → Computer Config → Admin Templates → DataCollection | ✅ Обязательно |
| **4** | **Службы и автозагрузка** | WaaSMedicSvc, UsoSvc, DoSvc, InstallService (Store), XboxNetApiSvc, RetailDemo, PrintWorkflow, MixedRealityOpenXR | Освобождение 150–400 МБ RAM в простое; снижение DPC Latency | 1. [Autoruns](https://learn.microsoft.com/sysinternals/downloads/autoruns) (Sysinternals) — точечный ручной анализ 2. PowerShell `Set-Service -StartupType Disabled` по списку 3. [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) → раздел Services | ✅ Обязательно |
| **5** | **Планировщик задач (нежелательные триггеры)** | `\Microsoft\Windows\Customer Experience Improvement Program\*`, `\Autochk\*`, `\DiskDiagnostic\*`, `\Application Experience\*`, `\CloudExperienceHost\*` | Устранение фоновых «будильников» телеметрии и нежелательных обновлений | 1. `schtasks /Change /TN "путь\задача" /Disable` (батч/PS) 2. [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) → `ScheduledTasks` секция 3. Autoruns → вкладка Scheduled Tasks | ✅ Обязательно |
| **6** | **Реестр HKLM: конфиденциальность и реклама** | AllowTelemetry=0, DODownloadMode=0, DisableWindowsConsumerFeatures=1, DisableSoftLanding=1, TurnOffWindowsCopilot=1, SkipRearm=1, WER\Disabled=1 | Долгосрочная блокировка рекламы и телеметрии для всех будущих пользователей | 1. [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) — покрывает 90% ключей 2. Кастомные `.reg`-файлы под проект (версионируемые в Git) 3. `gpedit.msc` → Local Computer Policy | ✅ Обязательно |
| **7** | **Default User (HKCU-шаблон)** | ContentDeliveryManager (реклама), Start Layout, TaskBar (Chat=hide, Search=hide, Cortana=hide), тёмная тема, обои, Language/Locale | Все новые пользователи на клиентах получают чистый, настроенный рабочий стол | 1. `reg load HKLM\DU C:\Users\Default\NTUSER.DAT` → правка → `reg unload` 2. `<CopyProfile>true</CopyProfile>` в unattend.xml (альтернатива) 3. [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) → запуск от DefaultUser профиля | ✅ Обязательно |
| **8** | **WinSxS и компонентное хранилище** | Superseded компоненты после установки CU, старые версии обновлений | Образ на 2–8 ГБ легче; DISM /AnalyzeComponentStore подтверждает экономию | 1. `DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase` (необратимо — только на финальном образе) 2. `DISM /Online /Cleanup-Image /AnalyzeComponentStore` (анализ до) 3. PowerShell `Optimize-Volume -DriveLetter C -ReTrim` (для SSD) | ✅ Обязательно (после всех обновлений) |
| **9** | **Временные файлы и артефакты сессии** | `%SystemRoot%\Temp\*`, `%SystemRoot%\SoftwareDistribution\Download\*`, `%TEMP%\*`, Prefetch, hiberfil.sys, pagefile.sys, `wevtutil` — очистка логов | Минимальный «след» сессии в образе; исключение персональных данных Admin | 1. PowerShell-скрипт (кастомный, 10 строк) — `Remove-Item` по путям 2. `wevtutil el \| ForEach {wevtutil cl $_}` — очистка всех журналов 3. `powercfg /hibernate off` → удаляет hiberfil.sys | ✅ Обязательно |
| **10** | **BitLocker / Device Encryption** | Device Encryption (автовключается на Win11 24H2+ при TPM+SecureBoot) | Sysprep падает с ошибкой если шифрование активно на C: | 1. Параметры → Конфиденциальность → Шифрование устройства → Выкл 2. `manage-bde -off C:` + ожидание 100% расшифровки 3. Проверка: `manage-bde -status C:` → `Protection Status: Off` | ✅ Обязательно (Win11 24H2+) |
| **11** | **Необязательные компоненты ОС** | Internet Explorer (Win10), Windows Media Player Legacy, XPS Viewer, MSXML 3.0, WorkFolders Client, Hello Face, Fax and Scan | Сокращение поверхности атаки; меньше legacy-кода в образе | 1. `DISM /Online /Disable-Feature /FeatureName:... /Remove` 2. `Get-WindowsOptionalFeature -Online` — инвентаризация 3. PowerShell `Disable-WindowsOptionalFeature -Online -FeatureName ...` | ✅ Рекомендуется |
| **12** | **Драйверы: очистка виртуального железа** | VirtualBox Guest Additions, VirtIO drivers, SVGA-драйвер — всё, что специфично для гипервизора | Образ не зависает / не BSoD на реальном железе клиента | 1. `wmic product where "name like '%VirtualBox%'" call uninstall` 2. Диспетчер устройств → удаление устройств VBox 3. `pnputil /delete-driver` для INF-файлов GA | ✅ Обязательно перед Sysprep |
| **13** | **Сетевой стек (базовая гигиена)** | NetBIOS over TCP/IP, LLMNR, IPv6 (если не нужен), SMBv1 | Снижение широковещательного шума в сети клиента; закрытие legacy-уязвимостей | 1. `Set-NetAdapterBinding` + реестровые ключи (встроенный PS) 2. `Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol` 3. [Sophia Script](https://github.com/farag2/Sophia-Script-for-Windows) → раздел Network | ✅ Рекомендуется |
| **14** | **Файловая система и TRIM** | MFT оптимизация, SSD TRIM, отключение LastAccess timestamp | Максимальная скорость накопителя клиентского ПК после развёртывания | 1. `Optimize-Volume -DriveLetter C -ReTrim` (только SSD) 2. `fsutil behavior set disableLastAccess 1` 3. `Optimize-Volume -DriveLetter C -Defrag` (только HDD) | ✅ Рекомендуется |

