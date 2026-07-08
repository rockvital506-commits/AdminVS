Часть 1. Скрипт автоматизации (PowerShell)
Этот скрипт объединяет функции включения и отключения блокировки в один инструмент. Он автоматически определяет текущее состояние и переключает его.

# ==============================================================================
# Сценарий автоматического переключения состояния Защитника Windows через WDAC
# Требуются права Администратора для выполнения
# ==============================================================================

$TargetDir = "$env:SystemRoot\System32\CodeIntegrity"
$PolicyPath = "$TargetDir\SiPolicy.p7b"

# Проверка прав Администратора
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Критическая ошибка: Этот скрипт ДОЛЖЕН быть запущен от имени Администратора!"
    Exit
}

# Функция для генерации xml-манифеста блокировки
function Create-WDACXml {
    param ($OutPath)
    # Создаем базовую разрешающую политику, которая разрешает всё, кроме указанных путей
    $XmlContent = @"
<?xml version="1.0" encoding="utf-8"?>
<SiPolicy xmlns="http://microsoft.com">
  <VersionEx>10.0.0.0</VersionEx>
  <PolicyID>{$( [Guid]::NewGuid().ToString("B").ToUpper() )}</PolicyID>
  <BasePolicyID>{$( [Guid]::NewGuid().ToString("B").ToUpper() )}</BasePolicyID>
  <Rules>
    <Rule><Option>Enabled:Unsigned System Integrity Policy</Option></Rule>
    <Rule><Option>Enabled:Advanced Boot Options Menu</Option></Rule>
    <Rule><Option>Enabled:UMCI</Option></Rule>
  </Rules>
  <FileRules>
    <!-- Блокировка главного движка Защитника -->
    <Deny ID="ID_DENY_MSMPENG" FriendlyName="Block MsMpEng" FileName="MsMpEng.exe" MinimumFileVersion="0.0.0.0" MaximumFileVersion="65535.65535.65535.65535" />
    <!-- Блокировка сетевого инспектора Защитника -->
    <Deny ID="ID_DENY_NISSRV" FriendlyName="Block NisSrv" FileName="NisSrv.exe" MinimumFileVersion="0.0.0.0" MaximumFileVersion="65535.65535.65535.65535" />
  </FileRules>
  <SigningScenarios>
    <SigningScenario Value="12" ID="ID_SIGNING_SCENARIO_WINDOWS" FriendlyName="Windows Signing Scenario">
      <ProductSigners />
    </SigningScenario>
  </SigningScenarios>
</SiPolicy>
"@
    $XmlContent | Out-File -FilePath $OutPath -Encoding utf8 -Force
}

# Логика переключения (Toggle)
if (Test-Path $PolicyPath) {
    Write-Host "[*] Обнаружена активная блокировка. Начинаю процедуру ВКЛЮЧЕНИЯ Защитника..." -ForegroundColor Cyan
    try {
        Remove-Item -Path $PolicyPath -Force -ErrorAction Stop
        Write-Host "[+] УСПЕХ: Политика блокировки удалена." -ForegroundColor Green
        Write-Host "[!] ВНИМАНИЕ: Для восстановления полной работы Защитника необходимо ПЕРЕЗАГРУЗИТЬ компьютер." -ForegroundColor Yellow
    } catch {
        Write-Error "Не удалось удалить файл политики. Возможно, он заблокирован системой."
    }
} else {
    Write-Host "[*] Блокировка отсутствует. Начинаю процедуру ОТКЛЮЧЕНИЯ Защитника..." -ForegroundColor Cyan
    
    $TempXml = "$env:TEMP\WDAC_DefBlock.xml"
    $TempBin = "$env:TEMP\SiPolicy.p7b"
    
    Write-Host "[1/3] Генерация XML-манифеста..." -ForegroundColor Gray
    Create-WDACXml -OutPath $TempXml
    
    Write-Host "[2/3] Компиляция бинарного файла политики целостности..." -ForegroundColor Gray
    # Используем встроенный командлет для конвертации XML в бинарный p7b формат
    ConvertFrom-CIPolicy -XmlFilePath $TempXml -BinaryFilePath $TempBin | Out-Null
    
    Write-Host "[3/3] Установка политики в системную директорию..." -ForegroundColor Gray
    Move-Item -Path $TempBin -Destination $PolicyPath -Force
    
    # Очистка временного XML
    Remove-Item -Path $TempXml -Force
    
    Write-Host "[+] УСПЕХ: Защитник Windows заблокирован на уровне ядра." -ForegroundColor Green
    Write-Host "[!] ВНИМАНИЕ: Изменения вступят в силу после ПЕРЕЗАГРУЗКИ компьютера." -ForegroundColor Yellow
}

# Инструкция к скрипту:
- Создайте текстовый файл, скопируйте в него код ниже и сохраните под именем Toggle-DefenderWDAC.ps1.
- Кликните правой кнопкой мыши по кнопке «Пуск» и выберите «Терминал (Администратор)» или «PowerShell (Администратор)».
- Разрешите запуск локальных скриптов в текущей сессии командой: " Set-ExecutionPolicy RemoteSigned -Scope Process -Force
 "
- Перейдите в папку со скриптом и запустите его: " .\Toggle-DefenderWDAC.ps1
 "

Первый запуск скомпилирует политику и заблокирует Защитник. Второй запуск — удалит её и включит его обратно. После каждого запуска обязательна перезагрузка ПК.


=====================================================================================================
=====================================================================================================
=====================================================================================================
=====================================================================================================

# Часть 2. Инструкция по действиям вручную (Без скриптов)
Если вам нужно выполнить этот процесс руками (например, вы находитесь в среде WinPE или хотите точно понимать, как работает каждый шаг под капотом), используйте этот алгоритм.

## Шаг 1. Создание текстового правила (Конфигурация)
Мы должны объяснить ядру Windows, что именно мы хотим запретить. Для этого создается XML-файл, содержащий правила проверки цифровых подписей и путей.Создайте на диске C: обычный текстовый файл с именем rules.xml.Вставьте в него следующую структуру:
<SiPolicy xmlns="http://microsoft.com">
  <VersionEx>10.0.0.0</VersionEx>
  <Rules>
    <!-- Разрешаем запуск неподписанного кода в политике, чтобы система приняла наше правило -->
    <Rule><Option>Enabled:Unsigned System Integrity Policy</Option></Rule>
    <!-- Разрешаем меню расширенной загрузки, чтобы не заблокировать систему при сбоях -->
    <Rule><Option>Enabled:Advanced Boot Options Menu</Option></Rule>
  </Rules>
  <FileRules>
    <!-- Жесткое запрещающее правило по имени файла для исполняемого ядра Защитника -->
    <Deny ID="ID_DENY_MSMPENG" FriendlyName="Block MsMpEng" FileName="MsMpEng.exe" MinimumFileVersion="0.0.0.0" MaximumFileVersion="65535.65535.65535.65535" />
  </FileRules>
  <SigningScenarios>
    <!-- Базовый сценарий верификации Windows-компонентов -->
    <SigningScenario Value="12" ID="ID_SIGNING_SCENARIO_WINDOWS" FriendlyName="Windows">
      <ProductSigners />
    </SigningScenario>
  </SigningScenarios>
</SiPolicy>

Смысл действия: Мы создали «черный список» для функции Windows Application Control. Тег <Deny> указывает, что файлу с именем MsMpEng.exe (это и есть процесс Защитника) запрещен запуск, независимо от того, насколько валидна его цифровая подпись от Microsoft.

## Шаг 2. Компиляция правила в бинарный формат
Ядро Windows при загрузке не умеет читать тяжелые XML-файлы. Ему требуется скомпилированный двоичный код политики.
- Откройте PowerShell от имени Администратора.Выполните команду: powershellConvertFrom-CIPolicy -XmlFilePath "C:\rules.xml" -BinaryFilePath "C:\SiPolicy.p7b"
- Смысл действия: Встроенная системная утилита переводит понятный человеку XML-текст в защищенный двоичный файл SiPolicy.p7b (Code Integrity Policy), который ядро способно быстро обработать на этапе инициализации процессора.

## Шаг 3. Внедрение и активация (ОТКЛЮЧЕНИЕ Защитника)
Теперь нужно положить скомпилированный файл туда, где ядро Windows гарантированно увидит его при старте.
- Перенесите файл SiPolicy.p7b из корня диска C:\ в скрытую системную папку по пути: C:\Windows\System32\CodeIntegrity\.
- Перезагрузите компьютер.
- Смысл действия: При старте ПК подсистема CodeIntegrity (Целостность кода) проверяет папку на наличие глобальных правил. Обнаружив SiPolicy.p7b, ядро применяет его ко всей операционной системе. Когда служба WinDefend пытается вызвать файл MsMpEng.exe, ядро сверяет его с черным списком, видит запрет и обрывает запуск. Защитник полностью «засыпает». Tamper Protection при этом не сопротивляется, так как атака идет не на его реестр, а на уровень выше — на уровень архитектуры выполнения кода Windows.

## Шаг 4. Отмена блокировки (ВКЛЮЧЕНИЕ Защитника)
Чтобы вернуть антивирус в исходное рабочее состояние, нужно убрать запрещающее правило.
- Перейдите в папку C:\Windows\System32\CodeIntegrity\.
- Физически удалите файл SiPolicy.p7b.
- Перезагрузите компьютер.
- Смысл действия: Мы убираем черный список. При следующей загрузке ядро Windows видит, что папка CodeIntegrity пуста (действуют стандартные разрешения по умолчанию). Служба Защитника без препятствий запускает MsMpEng.exe, и антивирус возвращается к 100% штатной работе без каких-либо повреждений или ошибок в Центре обновлений.