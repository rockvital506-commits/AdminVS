# 🔍 Анализ критичности провалов верификации

## 📊 Сводка результатов

| Категория | Пройдено | Провалено | Критичность |
|:---|:---:|:---:|:---|
| **Windows Defender** | 0 | 2 |  **КРИТИЧНО** |
| **Службы** | 20 | 0 | ✅ Отлично |
| **Ключи реестра** | 4 | 0 | ✅ Отлично |
| **Задачи планировщика** | 12 | 2 | 🟡 Средне |
| **ИТОГО** | 36 | 4 | — |

---

## 🔴 КРИТИЧНО: Windows Defender не отключен

**Проблема:** `apply_block.ps1` не смог отключить Windows Defender через `Set-MpPreference`.

**Почему это критично:**
- Defender Real-time Protection **блокирует выполнение скриптов** удаления AppX-пакетов
- Defender **блокирует модификацию системных файлов** и реестра
- Defender **сканирует каждый файл** при записи → замедляет работу DISM, Sysprep
- Defender может **карантинить легитимные утилиты** (например, портативный софт)

**Причины сбоя:**
1. **Group Policy** на уровне системы блокирует изменение настроек Defender
2. **Tamper Protection** включен (защищает настройки Defender от изменений)
3. **Defender управляется организацией** (если ПК был в домене)

### ✅ Исправление Windows Defender

Выполните в PowerShell от имени Администратора:

```powershell
# 1. Проверка текущего состояния
Get-MpPreference | Select-Object DisableRealtimeMonitoring, DisableBehaviorMonitoring, DisableIOAVProtection

# 2. Попытка отключения через Set-MpPreference
Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableBehaviorMonitoring $true -ErrorAction SilentlyContinue
Set-MpPreference -DisableIOAVProtection $true -ErrorAction SilentlyContinue

# 3. Если не сработало - проверка Tamper Protection
Get-MpComputerStatus | Select-Object IsTamperProtected

# 4. Если Tamper Protection включен - отключение через реестр
# ВНИМАНИЕ: Это требует перезагрузки
$TamperPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Features"
if (Test-Path $TamperPath) {
    Set-ItemProperty -Path $TamperPath -Name "TamperProtection" -Value 0 -Type DWord -Force
    Write-Host "[!] Tamper Protection отключен. Требуется перезагрузка." -ForegroundColor Yellow
}

# 5. Альтернатива: отключение через Group Policy
$PolicyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
if (-not (Test-Path $PolicyPath)) {
    New-Item -Path $PolicyPath -Force | Out-Null
}
Set-ItemProperty -Path $PolicyPath -Name "DisableAntiSpyware" -Value 1 -Type DWord -Force
Set-ItemProperty -Path "$PolicyPath\Real-Time Protection" -Name "DisableRealtimeMonitoring" -Value 1 -Type DWord -Force -ErrorAction SilentlyContinue

# 6. Верификация
Get-MpPreference | Select-Object DisableRealtimeMonitoring, DisableBehaviorMonitoring
```

**Ожидаемый результат:**
- ✅ `DisableRealtimeMonitoring` = `True`
- ✅ `DisableBehaviorMonitoring` = `True`

**Если не помогло:**
- Перезагрузите ВМ и повторите
- Проверьте, не управляется ли Defender через Group Policy (`gpedit.msc` → Computer Configuration → Administrative Templates → Windows Components → Microsoft Defender Antivirus)

---

## 🟡 СРЕДНЕ: Задачи планировщика не отключены

### Задача 1: `Refresh Group Policy Cache`

**Что делает:** Обновляет кэш групповых политик каждые 90 минут.

**Критичность для золотого образа:** 🟢 **Низкая**
- В изолированной ВМ без домена эта задача практически ничего не делает
- Sysprep при `/generalize` сам очистит кэш политик
- Не влияет на AppX-пакеты и не вызывает рассинхронизацию

**Исправление:**
```powershell
Disable-ScheduledTask -TaskName "Refresh Group Policy Cache" -TaskPath "\Microsoft\Windows\WindowsUpdate\" -ErrorAction SilentlyContinue
```

---

### Задача 2: `SdbinstMergeDbTask`

**Что делает:** Слияние баз данных совместимости приложений (Application Compatibility Database).

**Критичность для золотого образа:**  **Низкая**
- Это часть системы совместимости приложений Windows
- Не влияет на AppX, не вызывает рассинхронизацию
- Sysprep при `/generalize` сбрасывает базы совместимости

**Исправление:**
```powershell
Disable-ScheduledTask -TaskName "SdbinstMergeDbTask" -TaskPath "\Microsoft\Windows\Application Experience\" -ErrorAction SilentlyContinue
```

---

## 🎯 Итоговая оценка критичности

| Пропуск | Влияние на Sysprep | Влияние на чистоту образа | Обязательно ли исправлять? |
|:---|:---|:---|:---|
| **Windows Defender** | 🔴 **Высокое** — может блокировать скрипты | 🔴 **Высокое** — сканирует все файлы | ✅ **ДА, ОБЯЗАТЕЛЬНО** |
| **Refresh Group Policy Cache** | 🟢 **Низкое** — не влияет | 🟢 **Низкое** — не загрязняет образ | ⚠️ Желательно, но не критично |
| **SdbinstMergeDbTask** | 🟢 **Низкое** — не влияет | 🟢 **Низкое** — не загрязняет образ | ⚠️ Желательно, но не критично |

---

## ✅ Рекомендуемый порядок действий

### Шаг 1: Исправить Windows Defender (КРИТИЧНО)

```powershell
# Выполнить команды из раздела "Исправление Windows Defender" выше
# После выполнения проверить:
Get-MpPreference | Select-Object DisableRealtimeMonitoring, DisableBehaviorMonitoring
```

### Шаг 2: Отключить оставшиеся задачи (ЖЕЛАТЕЛЬНО)

```powershell
# Отключение оставшихся задач планировщика
Disable-ScheduledTask -TaskName "Refresh Group Policy Cache" -TaskPath "\Microsoft\Windows\WindowsUpdate\" -ErrorAction SilentlyContinue
Disable-ScheduledTask -TaskName "SdbinstMergeDbTask" -TaskPath "\Microsoft\Windows\Application Experience\" -ErrorAction SilentlyContinue

# Верификация
Get-ScheduledTask -TaskPath "\Microsoft\Windows\WindowsUpdate\*", "\Microsoft\Windows\Application Experience\*" | 
    Select-Object TaskName, State | 
    Format-Table -AutoSize
```

### Шаг 3: Повторная верификация

```powershell
powershell -ExecutionPolicy Bypass -File ".\verify_block.ps1"
```

**Ожидаемый результат:**
- ✅ Все 40 проверок пройдено
- ✅ 0 провалов

---

## 🔄 Можно ли продолжать без исправления?

**Если Windows Defender не отключен:**
- ❌ **НЕ РЕКОМЕНДУЕТСЯ** продолжать
- Риск: скрипты удаления AppX могут быть заблокированы
- Риск: DISM может работать медленнее из-за сканирования
- Риск: Sysprep может упасть из-за блокировки модификаций

**Если только задачи планировщика не отключены:**
- ✅ **МОЖНО** продолжать, но желательно исправить
- Эти задачи не влияют на критичные операции
- Sysprep сам их очистит при `/generalize`

---

## 📋 Итоговый чек-лист перед продолжением

- [ ] Windows Defender отключен (DisableRealtimeMonitoring = True)
- [ ] Задачи `Refresh Group Policy Cache` и `SdbinstMergeDbTask` отключены (опционально)
- [ ] `verify_block.ps1` показывает 40/40 пройдено (или минимум 38/40 без Defender)

**После исправления Windows Defender можно переходить к Блоку 04 (Offline-обновление системы через DISM).**