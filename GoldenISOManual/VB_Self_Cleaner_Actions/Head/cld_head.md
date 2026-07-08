

---

## Карта блоков: Золотой образ Windows 10/11 Pro (болванка)

---

### Блок 1. Подготовка виртуальной машины

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 1 из 11 | Всё остальное выполняется внутри этой среды |
| Инициализирует | VirtualBox VM, EFI/TPM/SecureBoot, Shared Folder | Без правильной аппаратной конфигурации Sysprep и BitLocker дадут сбой |
| Критичная зависимость | Сеть ОТКЛЮЧЕНА до Блока 5 | Любой фоновый процесс WU загрязнит образ |
| Снимок ВМ | До установки ОС | Точка быстрого сброса при ошибке |

**Подблоки:**

| # | Подблок | Что делается | Почему здесь |
|---|---|---|---|
| 1.1 | Конфигурация ВМ | RAM ≥ 4 ГБ, диск ≥ 80 ГБ VDI, EFI=on, TPM 2.0, SecureBoot=on | Win11 не установится без TPM/SecureBoot |
| 1.2 | Сетевой адаптер | NAT → Отключено. «Подключить кабель» = снять галочку | Предотвращает любой контакт с WU/telemetry |
| 1.3 | Shared Folder | Папка на хосте с .msu пакетами, смонтирована как X:\ | Единственный канал доставки обновлений в ВМ |
| 1.4 | Монтирование ISO | Win10/11 Pro 22H2/24H2/25H2 — официальный образ | Редакция Pro — обязательна (Sysprep + gpedit) |
| 1.5 | Снимок ВМ | «Before OS Install» | Точка отката до форматирования диска |

---

### Блок 2. Установка Windows без сети

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 2 из 11 | База для всех дальнейших манипуляций |
| Инициализирует | Чистая ОС, локальный Admin, NTFS-разметка | Только отсюда работает Audit Mode |
| Критичная зависимость | Нет сети → нет OOBE Microsoft Account | MSA-аккаунт привяжет Digital License, Sysprep упадёт |
| Снимок ВМ | После первого входа в Admin | Точка до любых изменений |

**Подблоки:**

| # | Подблок | Что делается | Почему здесь |
|---|---|---|---|
| 2.1 | Обход сетевого OOBE | `OOBE\BYPASSNRO` или `Shift+F10` → нет интернета | Без этого Win11 заставляет создать MSA |
| 2.2 | Создание Admin | Локальный пользователь `Admin`, пустой пароль | Sysprep требует локальной учётной записи |
| 2.3 | Верификация установки | `winver`, `msinfo32`, проверка редакции Pro | Убедиться что не Home/Education |
| 2.4 | Снимок ВМ | «Fresh Install» | Точка сброса перед Audit Mode |

---

### Блок 3. Блокировка фоновой активности (Audit Mode)

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 3 из 11 | Должен быть выполнен ДО любых изменений в системе |
| Инициализирует | Audit Mode (встроенный Administrator), заморозка фоновых служб | В Audit Mode нет профиля пользователя — чистое HKLM-пространство |
| Критичная зависимость | Выполняется ДО удаления AppX | Store и CloudContent не должны восстанавливать пакеты во время удаления |
| Риск пропуска | Windows Update скачает CU в фоне и сломает порядок обновлений | — |

**Подблоки:**

| # | Подблок | Что блокируется / останавливается | Метод |
|---|---|---|---|
| 3.1 | Вход в Audit Mode | `Ctrl+Shift+F3` на экране OOBE | Активирует встроенный Administrator |
| 3.2 | Службы Windows Update | `wuauserv`, `UsoSvc`, `WaaSMedicSvc` → Disabled | `sc config` + `reg add` (WaaSMedic защищён, нужен реестр) |
| 3.3 | Microsoft Store / CloudContent | `InstallService`, `wscsvc` Store-агент → Disabled | Предотвращает автовосстановление удалённых AppX |
| 3.4 | Delivery Optimization | `DoSvc` → Disabled | Блокирует P2P и CDN-загрузку обновлений |
| 3.5 | Telemetry-задачи планировщика | `\Microsoft\Windows\Customer Experience`, `Autochk`, `DiskDiagnostic` → Disabled | `schtasks /Change /Disable` |
| 3.6 | Уведомления и автозапуск | `NotificationPlatform`, `StartupBoost` → off | Чистота сессии Audit Mode |
| 3.7 | Защитник (временно) | Real-time protection → off | Антивирус блокирует скрипты удаления AppX |

---

### Блок 4. Удаление Bloatware и встроенного мусора

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 4 из 11 | После блокировки фона (иначе Store восстанавливает пакеты) |
| Инициализирует | Чистка AppX/provisioned пакетов, удаление ненужных компонентов | Каждый лишний AppX = потенциальный сбой Sysprep |
| Критичная зависимость | После Блока 3 (Store заблокирован) | — |
| Верификация | `Get-AppxProvisionedPackage -Online` должен вернуть только нужные | — |

**Подблоки:**

| # | Подблок | Список сущностей | Метод |
|---|---|---|---|
| 4.1 | AppX/UWP — универсальный список | Xbox*, BingNews, BingWeather, Zune*, People, Skype, MixedReality, Solitaire, FeedbackHub | `Remove-AppxProvisionedPackage -Online` |
| 4.2 | Win11-специфичный мусор | Widgets (WebExperience), Teams (Chat), Copilot, Recall (WindowsAI) | Те же + `winget uninstall` если остались |
| 4.3 | Win10-специфичный мусор | OneDrive (installer), 3DViewer, Mixed Reality Portal, YourPhone | `Get-AppxPackage | Remove-AppxPackage` |
| 4.4 | Необязательные компоненты ОС | IE11 (Win10), Windows Media Player legacy, XPS Viewer, MSXML | `DISM /Remove-Capability` или `OptionalFeatures` |
| 4.5 | Win11 AI-компоненты | Recall, Windows AI Platform, Copilot (если остался) | Реестр + `DISM /Remove-Package` |
| 4.6 | Верификация | Вывод `Get-AppxProvisionedPackage` — нет нежелательных | Исправить до следующего блока |

---

### Блок 5. Установка Offline-обновлений (.msu)

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 5 из 11 | После удаления AppX, до драйверов |
| Инициализирует | SSU + CU + .NET Framework + Defender definitions | SSU должен быть первым — иначе CU не установится |
| Источник пакетов | Microsoft Update Catalog → Shared Folder X:\ | Без интернета в ВМ |
| Критичная зависимость | После Блока 4: AppX-мусор не будет мешать обновлению ядра | — |
| Снимок ВМ | После успешной установки всех обновлений | Дорогостоящая операция — снимок обязателен |

**Подблоки:**

| # | Подблок | Порядок установки | Метод |
|---|---|---|---|
| 5.1 | SSU (Servicing Stack Update) | **Первым** — иначе остальные .msu не установятся | `DISM /Add-Package` или `wusa /quiet /norestart` |
| 5.2 | Cumulative Update (CU) | После SSU | Тот же метод |
| 5.3 | .NET Framework Cumulative | После CU | Тот же метод |
| 5.4 | Defender Definition Update | Опционально — offline база угроз | `MpCmdRun -SignatureUpdate -Path X:\` |
| 5.5 | Верификация | `Get-HotFix`, `DISM /Get-Packages` | Убедиться в статусе Installed |
| 5.6 | Снимок ВМ | «After Updates» | Сброс если что-то пойдёт не так дальше |

---

### Блок 6. Внедрение offline-драйверов

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 6 из 11 | После обновлений ядра — INF-подписи верифицируются корректно |
| Инициализирует | OEM-нейтральные драйверы в хранилище DriverStore | В золотой образ-болванку идут только аппаратно-независимые драйверы |
| Принцип | Аппаратно-специфичные драйверы (GPU, NIC конкретного ПК) — через autounattend на клиенте | Иначе образ не будет универсальным |
| Критичная зависимость | VirtIO / VirtualBox GA — удалить из образа перед Sysprep | Они привязаны к виртуальному железу |

**Подблоки:**

| # | Подблок | Что включается | Что исключается |
|---|---|---|---|
| 6.1 | Гостевые дополнения ВМ | VirtualBox Guest Additions — только для работы в ВМ | Удалить перед Sysprep (блок 9) |
| 6.2 | OEM-нейтральные драйверы | Общие Chipset, USB3, NVMe-контроллер (если универсальный) | Видеодрайверы NVIDIA/AMD — нет |
| 6.3 | Метод внедрения | `DISM /Online /Add-Driver /Driver:X:\Drivers /Recurse` | Только подписанные .inf |
| 6.4 | Верификация | `DISM /Online /Get-Drivers /All` — нет неподписанных | Неподписанные = сбой Sysprep |

---

### Блок 7. Твики реестра HKLM и локальные политики

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 7 из 11 | После обновлений: некоторые CU сбрасывают реестровые ключи, поэтому твики идут после |
| Инициализирует | Политики конфиденциальности, отключение телеметрии, реклама, AI-функции | HKLM-ключи наследуются всеми пользователями — включая профиль из Блока 8 |
| Критичная зависимость | SkipRearm=1 обязательно до Sysprep | Без него Sysprep упадёт при повторном запуске |
| Инструменты | `.reg`-файлы / PowerShell / `gpedit.msc` | |

**Подблоки:**

| # | Подблок | Ключи / политики | Значение |
|---|---|---|---|
| 7.1 | Телеметрия | `HKLM\...\DataCollection\AllowTelemetry` | 0 (Security only) |
| 7.2 | Delivery Optimization | `DODownloadMode` | 0 (отключено) |
| 7.3 | Recall / Windows AI | `TurnOffWindowsAIFeatures`, `DisableAIDataAnalysis` | 1 |
| 7.4 | Copilot | `TurnOffWindowsCopilot` | 1 |
| 7.5 | CEIP / WER / SQM | `CEIPEnable=0`, `WER\Disabled=1` | — |
| 7.6 | CloudContent / реклама | `DisableWindowsConsumerFeatures`, `DisableSoftLanding` | 1 |
| 7.7 | Службы телеметрии | `DiagTrack`, `dmwappushservice` → Disabled | `Set-Service` |
| 7.8 | Sysprep SkipRearm | `HKLM\...\SoftwareProtectionPlatform\SkipRearm` | 1 |
| 7.9 | Локальные политики gpedit | Computer Config → Admin Templates → Windows Components | Телеметрия, реклама, Store, Cortana |

---

### Блок 8. Настройка профиля Default User (HKCU-шаблон)

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 8 из 11 | После HKLM-политик: Default User наследует их через CopyProfile |
| Инициализирует | Шаблон HKCU для каждого нового пользователя на клиентских ПК | Без настройки Default User первый вход на клиенте даёт «голый» рабочий стол с рекламой |
| Метод | `reg load HKLM\DU C:\Users\Default\NTUSER.DAT` → правим → `reg unload` | Нельзя редактировать NTUSER.DAT залогиненного пользователя |
| CopyProfile | `<CopyProfile>true</CopyProfile>` в unattend.xml | Копирует Admin-профиль в Default — альтернативный метод |

**Подблоки:**

| # | Подблок | Что настраивается | Ключ / метод |
|---|---|---|---|
| 8.1 | Монтирование куста | `reg load HKLM\DU C:\Users\Default\NTUSER.DAT` | Только в Audit Mode / WinPE |
| 8.2 | Реклама и ContentDelivery | `SubscribedContent-*Enabled=0`, `OemPreInstalledAppsEnabled=0` | HKCU\...\ContentDeliveryManager |
| 8.3 | Персонализация | Тёмная тема, обои, отключение Live Tiles (Win10) | Реестр |
| 8.4 | Панель задач | Поиск = скрыт, Cortana = скрыта, News = off, Chat = off | HKCU\...\Explorer\Advanced |
| 8.5 | Язык и раскладка | Русский / English — по заданию клиента | intl.cpl или unattend.xml |
| 8.6 | Размонтирование куста | `reg unload HKLM\DU` | Обязательно перед Sysprep |
| 8.7 | CopyProfile (альтернатива) | `<CopyProfile>true</CopyProfile>` в unattend.xml | Копирует весь Admin-профиль |

---

### Блок 9. Глубокая очистка и оптимизация

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 9 из 11 | Последнее действие перед финальной проверкой |
| Инициализирует | Уменьшение размера WIM, стерилизация журналов и артефактов | `/ResetBase` необратима — откат патчей невозможен, поэтому только на готовом образе |
| Критичная зависимость | После Блока 6: гостевые дополнения ВМ удаляются здесь | VirtIO в образе = крах на реальном железе |
| Эффект | Размер WIM уменьшается на 2–8 ГБ | — |

**Подблоки:**

| # | Подблок | Команда / действие | Что удаляется |
|---|---|---|---|
| 9.1 | Удаление VirtualBox GA | `wmic product where name like '%VirtualBox%' call uninstall` | Драйверы виртуального железа |
| 9.2 | DISM ResetBase | `DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase` | Superseded компоненты WinSxS |
| 9.3 | SoftwareDistribution | `net stop wuauserv && del /f /s /q C:\Windows\SoftwareDistribution\Download` | Кэш загрузок WU |
| 9.4 | Временные файлы | `%SystemRoot%\Temp\*`, `%TEMP%\*`, Prefetch | Артефакты установки |
| 9.5 | Журналы событий | `wevtutil el | ForEach {wevtutil cl $_}` | Логи с данными текущей сессии |
| 9.6 | PageFile | `wmic pagefileset delete` (пересоздаётся Sysprep) | Виртуальная память |
| 9.7 | Гибернация | `powercfg /hibernate off` → удаляет hiberfil.sys | ~4–8 ГБ в образе |
| 9.8 | Очистка реестра | Удаление MRU, Recent Docs, RunOnce остатков Admin | Артефакты сессии |
| 9.9 | Снимок ВМ | «Before Sysprep» | Последняя точка отката |

---

### Блок 10. Финальная проверка и запечатывание (Sysprep)

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 10 из 11 | Все операции завершены, образ стерилен |
| Инициализирует | Sysprep /generalize — удаление SID, аппаратной привязки, OOBE для клиента | После shutdown ВМ нельзя запускать — только снимать образ |
| Критичная зависимость | Нет pending reboot, нет AppX с PartialKey, SFC чист | Один не выполненный пункт = Fatal Error в Sysprep |
| При сбое Sysprep | Лог: `C:\Windows\System32\Sysprep\Panther\setuperr.log` | |

**Подблоки:**

| # | Подблок | Команда / проверка | Ожидаемый результат |
|---|---|---|---|
| 10.1 | Проверка целостности | `sfc /scannow` + `DISM /CheckHealth` | «Нарушений не обнаружено» |
| 10.2 | Проверка AppX | `Get-AppxProvisionedPackage -Online` — нет нежелательных | Пустой или только нужные |
| 10.3 | Проверка Pending Reboot | Ключ `HKLM\...\PendingFileRenameOperations` — пустой | Нет ожидающих операций |
| 10.4 | Проверка SkipRearm | `HKLM\...\SkipRearm = 1` | Установлен |
| 10.5 | Размонтирование Default NTUSER | `reg unload HKLM\DU` (если не размонтирован) | Обязательно |
| 10.6 | Запуск Sysprep | `sysprep /generalize /oobe /shutdown /unattend:unattend.xml` | ВМ выключилась сама |
| 10.7 | Верификация результата | ВМ выключена, не перезагружена | Не запускать ВМ снова |

---

### Блок 11. Захват образа WIM / ESD

| Параметр | Значение | Обоснование |
|---|---|---|
| Позиция | 11 из 11 | Выполняется вне ВМ — образ снимается с холодного диска |
| Инициализирует | Финальный WIM/ESD готовый к тиражированию | |
| Инструменты | DISM из WinPE / DiskGenius | |
| Критичная зависимость | ВМ выключена после Sysprep и больше не запускалась | |

**Подблоки:**

| # | Подблок | Команда / действие | Параметры |
|---|---|---|---|
| 11.1 | Монтирование VDI | DiskGenius: Open Virtual Disk → смонтировать раздел C: | Только чтение |
| 11.2 | Захват WIM | `DISM /Capture-Image /ImageFile:D:\Gold.wim /CaptureDir:C:\ /Name:"Win11_Gold" /Compress:max` | max = минимальный размер |
| 11.3 | Конвертация в ESD (опц.) | `DISM /Export-Image /SourceImageFile:Gold.wim /DestinationImageFile:Gold.esd /Compress:recovery` | ESD на 30–40% меньше WIM |
| 11.4 | Верификация образа | `DISM /Get-ImageInfo /ImageFile:Gold.wim` | Проверить версию, индекс, размер |
| 11.5 | Размещение | WIM/ESD → папка рядом с `autounattend.xml` на загрузочной флешке | Готово к развёртыванию |

---

## Критический анализ полноты структуры

| Риск / пропуск | Статус | Где решено |
|---|---|---|
| Фоновые процессы загрязняют образ во время работы | ✅ Закрыто | Блок 3 — первым после входа в Audit Mode |
| Store восстанавливает удалённые AppX | ✅ Закрыто | Блок 3 (Store off) → Блок 4 (удаление) |
| CU ломает уже установленные твики | ✅ Закрыто | Твики (Блок 7) идут после обновлений (Блок 5) |
| INF-драйверы несовместимы со старым ядром | ✅ Закрыто | Блоки 5→6: сначала обновления, потом драйверы |
| Гостевые дополнения ВМ попадают в образ | ✅ Закрыто | Блок 9.1 — удаляются перед очисткой |
| Default User без твиков = реклама на клиентах | ✅ Закрыто | Блок 8 — отдельный полный подблок |
| Sysprep падает из-за AppX с PartialKey | ✅ Закрыто | Блок 10.2 — явная проверка перед запуском |
| Образ снимается с «тёплого» диска | ✅ Закрыто | Блок 11 — только после shutdown Sysprep |
| Нет точек отката при ошибке | ✅ Закрыто | Снимки ВМ в блоках 1, 2, 5, 9 |
| Win10 и Win11 различаются по AppX | ✅ Закрыто | Блоки 4.2 / 4.3 — раздельные подблоки |