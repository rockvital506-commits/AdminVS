



26_05_08
=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================




# Задания:
```
Auto Install: Добавлен блок. Ventoy умеет читать autounattend.xml с другого раздела (W:), если указать путь.
```
- расскажи подробнее про этот блок



[MAIN] Подробный разбор `auto_install`

### 🔍 Как работает механизм

Ventoy **НЕ** модифицирует ISO. Он:
1. При выборе ISO с `auto_install` → монтирует образ
2. Ищет файл `autounattend.xml` (или `unattend.xml`) **внутри** ISO (в корне или `\sources\`)
3. **Подменяет** найденный файл на ваш кастомный из пути `template`
4. Запускает установку Windows с подменённым файлом

**Важно:** Путь в `template` указывается относительно **корня загрузочного раздела Ventoy** (V:), но Ventoy умеет "видеть" другие разделы через специальные пути.

---

### 📂 Работа с разделом W: (NTFS)

#### Вариант 1: Файл на том же разделе (V:)
```json
"auto_install": [
  {
    "image": "/ISO/Win/win11.iso",
    "template": "/Data/win11/autounattend.xml"
  }
]
```
✅ **Работает всегда.** Файл лежит `V:\Data\win11\autounattend.xml`

#### Вариант 2: Файл на разделе W: (NTFS)
Ventoy 1.0.90+ поддерживает доступ к другим разделам через **UUID** или **LABEL**:

```json
"auto_install": [
  {
    "image": "/ISO/Win/win11.iso",
    "template": "(hd0,msdos2)/Data/win11/autounattend.xml"
  }
]
```
⚠️ **Ненадёжно:** `(hd0,msdos2)` — это GRUB-синтаксис, зависит от порядка подключения дисков.

#### ✅ Рекомендуемый подход для split-диска:
**Храните `autounattend.xml` на V: (exFAT)**, а не на W:. 

**Почему:**
1. Ventoy загружается с V: → гарантированный доступ
2. exFAT читается в WinPE/Linux без проблем
3. W: может не смонтироваться автоматически в ранней стадии установки Windows

**Структура:**
```
V: (exFAT 300GB)
├── ventoy.json
├── ISO/
│   └── Win/win11.iso
└── Data/
    └── win11/
        └── autounattend.xml  ← здесь

W: (NTFS 176GB)
└── (ваши данные, бэкапы, драйверы)
```

---

### 📝 Пример `autounattend.xml` для Windows 11 IoT Enterprise LTSC 2024

Минимальный файл для **обхода TPM/SecureBoot** и **локальной учётки**:

```xml
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
  
  <!-- Пропуск проверки TPM/SecureBoot -->
  <settings pass="windowsPE">
    <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <BypassTPMCheck>true</BypassTPMCheck>
      <BypassSecureBootCheck>true</BypassSecureBootCheck>
    </component>
  </settings>

  <!-- Локальная учётка (без Microsoft Account) -->
  <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <HideLocalAccountScreen>false</HideLocalAccountScreen>
        <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
        <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
        <NetworkLocation>Work</NetworkLocation>
        <ProtectYourPC>3</ProtectYourPC>
      </OOBE>
      <UserAccounts>
        <LocalAccounts>
          <LocalAccount wcm:action="add">
            <Name>Admin</Name>
            <Group>Administrators</Group>
            <Password>
              <Value></Value>
              <PlainText>true</PlainText>
            </Password>
          </LocalAccount>
        </LocalAccounts>
      </UserAccounts>
    </component>
  </settings>

</unattend>
```

**Сохраните как:** `V:\Data\win11\autounattend.xml` (UTF-8 **без BOM**!)

---

### 🔄 Обновлённый `ventoy.json` (корректный путь)

```json
"auto_install": [
  {
    "image": "/ISO/Win/en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd_f6b14814.iso",
    "template": "/Data/win11/autounattend.xml"
  },
  {
    "image": "/ISO/Win/Win11_25H2_Russian_x64_v2.iso",
    "template": "/Data/win11/autounattend.xml"
  }
]
```

---

### 🛡️ Ловушки и ограничения

| Проблема | Решение |
|----------|---------|
| **Файл не применяется** | Проверьте кодировку: **UTF-8 без BOM**. Notepad++ → Encoding → UTF-8 (без BOM) |
| **Ошибки валидации XML** | Используйте `Windows System Image Manager (WSIM)` или онлайн-валидатор |
| **Ventoy не видит файл** | Путь должен начинаться с `/`, не `\`. Проверьте через `Ctrl+F` в меню Ventoy |
| **Установка игнорирует файл** | В ISO может быть свой `autounattend.xml`. Ventoy подменяет, но если имя другое (`unattend.xml`) → укажите явно |
| **Разные редакции Windows** | Один файл работает для всех редакций, если не указаны специфичные `ProductKey` |

---

### 🔧 Продвинутый сценарий: Разные ответы для разных ISO

```json
"auto_install": [
  {
    "image": "/ISO/Win/en-us_windows_11_iot_enterprise_ltsc_2024_x64_dvd_f6b14814.iso",
    "template": "/Data/win11/ltsc_autounattend.xml"
  },
  {
    "image": "/ISO/Win/Win11_25H2_Russian_x64_v2.iso",
    "template": "/Data/win11/pro_autounattend.xml"
  }
]
```

---

### 📊 Как проверить работу

1. **В меню Ventoy:** Выберите ISO → нажмите `Ctrl+F` (debug mode)
2. **В логе увидите:** 
   ```
   Auto install template: /Data/win11/autounattend.xml
   Template file found: Yes
   ```
3. **При установке:** В логе `setupact.log` (`C:\$WINDOWS.~BT\Sources\Panther\`) будет запись о применении unattend

---

[RECOMMEND]
1. Создайте `V:\Data\win11\autounattend.xml` с примером выше
2. Протестируйте на **виртуальной машине** (VirtualBox/VMware) перед реальной установкой
3. Используйте `Windows Answer File Generator` (https://schneegans.de/windows/unattend-generator/) для генерации сложных конфигов

[ANTICIPATE]
• Как добавить **драйверы** в autounattend.xml (например, Wi-Fi для ноутбука)?
• Как настроить **разбивку диска** (partitioning) через unattend?
• Можно ли использовать **PowerShell-скрипты** post-install через auto_install?