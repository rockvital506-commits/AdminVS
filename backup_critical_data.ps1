<#
.SYNOPSIS
    Экспорт критических данных со старого ПК перед миграцией на Windows 11 Pro (25H2).

.DESCRIPTION
    Собирает в единую папку-архив на флешке:
      - Драйверы (DISM OEM Export + инвентаризация)
      - Дистрибутивы WSL2 (все установленные, .tar.gz)
      - Образы Docker (все локальные, .tar)
      - SSH-ключи (~/.ssh)
      - Глобальные пакеты: npm, pip, cargo, gem, composer, winget
      - Переменные окружения (PATH, JAVA_HOME, GOPATH и др.)
      - Конфиги разработчика (.gitconfig, .wslconfig, VS Code, Windows Terminal…)
      - ЛИЦЕНЗИОННЫЕ КЛЮЧИ: Windows, Office, Adobe, JetBrains, Autodesk,
        Visual Studio, SQL Server, Sublime Text, Total Commander, WinRAR,
        VMware, Parallels, 1C, Антивирусы, ReSharper и другие.

.NOTES
    ЗАПУСКАТЬ: на СТАРОМ ПК, от имени Администратора, ДО начала миграции.
    Питание: строго от розетки (не от батареи).
    Сеть: отключить (исключает фоновые обновления во время резервирования).

.PARAMETER Destination
    Буква или полный путь к флешке-приёмнику.
    По умолчанию: автоопределение первого съёмного диска с > 16 ГБ свободного места.

.EXAMPLE
    # Явное указание флешки:
    powershell -ExecutionPolicy Bypass -File "backup_critical_data.ps1" -Destination "E:"

    # Автоопределение флешки:
    powershell -ExecutionPolicy Bypass -File "backup_critical_data.ps1"
#>

[CmdletBinding()]
param(
    [string]$Destination = ""
)

# ==============================================================
# ИНИЦИАЛИЗАЦИЯ
# ==============================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"

$StartTime = Get-Date
$LogLines  = [System.Collections.Generic.List[string]]::new()

function Write-Log {
    param([string]$Message, [string]$Color = "White", [string]$Level = "INFO")
    $ts   = (Get-Date).ToString("HH:mm:ss")
    $line = "[$ts][$Level] $Message"
    $LogLines.Add($line)
    Write-Host $line -ForegroundColor $Color
}
function Write-Section {
    param([string]$Title)
    $bar = "=" * 70
    Write-Host "`n$bar"        -ForegroundColor Yellow
    Write-Host "  $Title"      -ForegroundColor Yellow
    Write-Host "$bar"          -ForegroundColor Yellow
    $LogLines.Add("`n$bar"); $LogLines.Add("  $Title"); $LogLines.Add("$bar")
}
function Write-Step { param([string]$Msg) Write-Log "[--->] $Msg" "Cyan"        "STEP" }
function Write-Ok   { param([string]$Msg) Write-Log "[+]    $Msg" "Green"       "OK"   }
function Write-Skip { param([string]$Msg) Write-Log "[~]    $Msg" "Gray"        "SKIP" }
function Write-Warn { param([string]$Msg) Write-Log "[!]    $Msg" "DarkYellow"  "WARN" }
function Write-Fail { param([string]$Msg) Write-Log "[X]    $Msg" "Red"         "FAIL" }

Write-Host ("`n" + "=" * 70) -ForegroundColor Magenta
Write-Host "  BACKUP CRITICAL DATA — Подготовка к миграции на Windows 11 (25H2)" -ForegroundColor Magenta
Write-Host ("=" * 70 + "`n") -ForegroundColor Magenta

# ==============================================================
# 0. ПРОВЕРКА ПРАВ АДМИНИСТРАТОРА
# ==============================================================
if (-not ([Security.Principal.WindowsPrincipal]
          [Security.Principal.WindowsIdentity]::GetCurrent()
         ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[X] КРИТИЧНО: Запустите скрипт от имени Администратора!" -ForegroundColor Red
    Write-Host "    ПКМ по файлу -> 'Запуск от имени администратора'"    -ForegroundColor Red
    Exit 1
}

# ==============================================================
# 1. ОПРЕДЕЛЕНИЕ ФЛЕШКИ-ПРИЁМНИКА
# ==============================================================
Write-Section "БЛОК 1: Целевой накопитель"

if ($Destination -eq "") {
    Write-Step "Автопоиск съёмного диска (NTFS/exFAT, > 16 ГБ свободно)..."
    $RemovableDrive = Get-WmiObject Win32_LogicalDisk |
        Where-Object {
            $_.DriveType -eq 2 -and
            $_.FreeSpace -gt 16GB -and
            $_.FileSystem -in @("NTFS","exFAT","FAT32")
        } | Sort-Object FreeSpace -Descending | Select-Object -First 1

    if (-not $RemovableDrive) {
        Write-Fail "Съёмный диск не найден. Укажите путь через -Destination."
        Exit 1
    }
    $Destination = $RemovableDrive.DeviceID
    Write-Ok "Выбран диск: $Destination  (свободно: $([math]::Round($RemovableDrive.FreeSpace/1GB,1)) ГБ)"
} else {
    if (-not (Test-Path $Destination)) {
        Write-Fail "Путь '$Destination' недоступен."
        Exit 1
    }
    Write-Ok "Целевой диск: $Destination"
}

$DateStamp  = (Get-Date).ToString("yyyy-MM-dd_HHmm")
$BackupRoot = Join-Path $Destination "PC_Backup_$DateStamp"
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
Write-Ok "Папка бэкапа: $BackupRoot"
$LogFile = Join-Path $BackupRoot "backup_log.txt"

function New-BackupDir {
    param([string]$Name)
    $p = Join-Path $BackupRoot $Name
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

# ==============================================================
# 2. ЭКСПОРТ OEM-ДРАЙВЕРОВ
# ==============================================================
Write-Section "БЛОК 2: OEM-драйверы (DISM)"

$DriversDir = New-BackupDir "Drivers"
Write-Step "DISM /Export-Driver..."
$DismOut = & DISM.exe /Online /Export-Driver /Destination:"$DriversDir" 2>&1
if ($LASTEXITCODE -eq 0) {
    $dc = (Get-ChildItem $DriversDir -Filter "*.inf" -Recurse).Count
    Write-Ok "Экспортировано .inf файлов: $dc"
} else {
    Write-Fail "DISM ошибка (код $LASTEXITCODE)"
    Write-Warn ($DismOut -join "`n")
}

Write-Step "Инвентаризация всех активных драйверов -> drivers_inventory.csv"
Get-WindowsDriver -Online -All -ErrorAction SilentlyContinue |
    Select-Object Driver, OriginalFileName, ProviderName, Version, Date, ClassDescription |
    Export-Csv (Join-Path $BackupRoot "drivers_inventory.csv") -Encoding UTF8 -NoTypeInformation
Write-Ok "drivers_inventory.csv сохранён"

# ==============================================================
# 3. ЭКСПОРТ WSL2
# ==============================================================
Write-Section "БЛОК 3: WSL2 — дистрибутивы"

$WslDir = New-BackupDir "WSL2"
if (-not (Get-Command "wsl.exe" -ErrorAction SilentlyContinue)) {
    Write-Skip "wsl.exe не найден — WSL не установлен."
} else {
    $WslRaw  = & wsl.exe --list --quiet 2>&1
    $Distros = $WslRaw |
        ForEach-Object { $_ -replace '\x00','' } |
        Where-Object   { $_ -match '\S' -and $_ -notmatch 'Windows Subsystem' } |
        ForEach-Object { $_.Trim() }

    if ($Distros.Count -eq 0) {
        Write-Skip "Установленные дистрибутивы WSL не найдены."
    } else {
        Write-Step "Найдено дистрибутивов: $($Distros.Count) — $($Distros -join ', ')"
        (& wsl.exe --version 2>&1) | Out-File (Join-Path $WslDir "wsl_version.txt") -Encoding UTF8

        foreach ($D in $Distros) {
            $SafeName = $D -replace '\s*\(Default\)','' -replace '[^\w\-\.]','_'
            $Tar      = Join-Path $WslDir "$SafeName.tar.gz"
            Write-Step "Экспорт: $D -> $SafeName.tar.gz"
            & wsl.exe --export "$D" "$Tar" 2>&1 | Out-Null
            if (Test-Path $Tar) {
                Write-Ok "$D  ($([math]::Round((Get-Item $Tar).Length/1MB,1)) МБ)"
            } else {
                Write-Fail "Экспорт $D не удался"
            }
        }

        # Скрипт восстановления
        $rst = "# === ИМПОРТ WSL2 НА НОВОМ ПК ===`n"
        $rst += "# 1. wsl --install --no-distribution  (перезагрузиться)`n"
        $rst += "# 2. Запустить этот скрипт от Администратора`n`n"
        $rst += '`$Dir = Split-Path -Parent `$MyInvocation.MyCommand.Definition' + "`n"
        foreach ($D in $Distros) {
            $SafeName  = $D -replace '\s*\(Default\)','' -replace '[^\w\-\.]','_'
            $InstDir   = "C:\WSL\$SafeName"
            $rst += "New-Item -ItemType Directory -Path `"$InstDir`" -Force | Out-Null`n"
            $rst += "wsl --import `"$D`" `"$InstDir`" `"`$Dir\$SafeName.tar.gz`" --version 2`n"
            $rst += "Write-Host `"[+] $D импортирован`"`n`n"
        }
        $rst | Out-File (Join-Path $WslDir "RESTORE_WSL.ps1") -Encoding UTF8
        Write-Ok "Скрипт: WSL2\RESTORE_WSL.ps1"
    }
}

# ==============================================================
# 4. ЭКСПОРТ DOCKER IMAGES
# ==============================================================
Write-Section "БЛОК 4: Docker images"

$DockerDir = New-BackupDir "Docker"
if (-not (Get-Command "docker.exe" -ErrorAction SilentlyContinue)) {
    Write-Skip "docker.exe не найден."
} else {
    $info = & docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Docker daemon не отвечает. Запустите Docker Desktop и повторите."
    } else {
        $Images = & docker images --format "{{.Repository}}:{{.Tag}}" 2>&1 |
                  Where-Object { $_ -notmatch '<none>' -and $_ -match '\S' }
        if ($Images.Count -eq 0) {
            Write-Skip "Локальные образы не найдены."
        } else {
            Write-Step "Образов: $($Images.Count)"
            $Images | Out-File (Join-Path $DockerDir "images_list.txt") -Encoding UTF8
            foreach ($Img in $Images) {
                $Safe = $Img -replace '[/:.]','_'
                $Tar  = Join-Path $DockerDir "$Safe.tar"
                Write-Step "docker save: $Img"
                & docker save -o "$Tar" "$Img" 2>&1 | Out-Null
                if (Test-Path $Tar) {
                    Write-Ok "$Img  ($([math]::Round((Get-Item $Tar).Length/1MB,1)) МБ)"
                } else {
                    Write-Fail "Сохранение '$Img' не удалось"
                }
            }
            @'
# === ИМПОРТ DOCKER IMAGES НА НОВОМ ПК ===
$Dir = Split-Path -Parent $MyInvocation.MyCommand.Definition
Get-ChildItem $Dir -Filter "*.tar" | ForEach-Object {
    Write-Host "Загрузка: $($_.Name)"
    docker load -i $_.FullName
}
Write-Host "Готово. Проверьте: docker images"
'@ | Out-File (Join-Path $DockerDir "RESTORE_DOCKER.ps1") -Encoding UTF8
            Write-Ok "Скрипт: Docker\RESTORE_DOCKER.ps1"
        }
    }
}

# ==============================================================
# 5. ЭКСПОРТ SSH-КЛЮЧЕЙ
# ==============================================================
Write-Section "БЛОК 5: SSH-ключи"

$SshDir = New-BackupDir "SSH"
$SshSrc = Join-Path $env:USERPROFILE ".ssh"

if (-not (Test-Path $SshSrc)) {
    Write-Skip "~/.ssh не найдена."
} else {
    $Files = Get-ChildItem $SshSrc -File
    if ($Files.Count -eq 0) {
        Write-Skip "~/.ssh пуста."
    } else {
        Copy-Item "$SshSrc\*" $SshDir -Recurse -Force
        # Ужесточаем права на приватные ключи
        $PrivKeys = Get-ChildItem $SshDir -File |
            Where-Object { $_.Name -notmatch '\.(pub|ppk|txt|cfg|conf|config)$' -and
                           $_.Name -notin @('known_hosts','authorized_keys') }
        foreach ($K in $PrivKeys) {
            $Acl = Get-Acl $K.FullName
            $Acl.SetAccessRuleProtection($true,$false)
            $Acl.Access | ForEach-Object { $Acl.RemoveAccessRule($_) | Out-Null }
            $Acl.AddAccessRule(
                (New-Object System.Security.AccessControl.FileSystemAccessRule(
                    $env:USERNAME,"FullControl","Allow")))
            Set-Acl $K.FullName $Acl -ErrorAction SilentlyContinue
        }
        Write-Ok "Файлов скопировано: $($Files.Count) (приватных ключей: $($PrivKeys.Count))"
        @'
# === ВОССТАНОВЛЕНИЕ SSH-КЛЮЧЕЙ НА НОВОМ ПК ===
$Src = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Dst = Join-Path $env:USERPROFILE ".ssh"
New-Item -ItemType Directory -Path $Dst -Force | Out-Null
Copy-Item "$Src\*" $Dst -Recurse -Force
# Устанавливаем права 600 на приватные ключи
Get-ChildItem $Dst -File |
    Where-Object { $_.Name -notmatch '\.(pub|txt|cfg|config)$' -and
                   $_.Name -notin @('known_hosts','authorized_keys') } |
    ForEach-Object {
        $a = New-Object System.Security.AccessControl.FileSecurity
        $a.SetAccessRuleProtection($true,$false)
        $a.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $env:USERNAME,"FullControl","Allow")))
        Set-Acl $_.FullName $a
        Write-Host "[+] Права обновлены: $($_.Name)"
    }
Write-Host "SSH-ключи восстановлены в $Dst"
'@ | Out-File (Join-Path $SshDir "RESTORE_SSH.ps1") -Encoding UTF8
        Write-Ok "Скрипт: SSH\RESTORE_SSH.ps1"
    }
}

# ==============================================================
# 6. ЛИЦЕНЗИОННЫЕ КЛЮЧИ
# ==============================================================
Write-Section "БЛОК 6: Лицензионные ключи программного обеспечения"

$LicDir  = New-BackupDir "Licenses"
$LicFile = Join-Path $LicDir "license_keys.txt"

$LicLines = [System.Collections.Generic.List[string]]::new()
$LicLines.Add("=" * 68)
$LicLines.Add("  ЛИЦЕНЗИОННЫЕ КЛЮЧИ — экспорт $DateStamp")
$LicLines.Add("  ХРАНИТЬ В БЕЗОПАСНОМ МЕСТЕ. НЕ ПЕРЕДАВАТЬ ТРЕТЬИМ ЛИЦАМ.")
$LicLines.Add("=" * 68)
$LicLines.Add("")

$LicCount = 0
function Add-LicenseEntry {
    param([string]$Product, [string]$Key, [string]$Extra = "")
    if ($Key -and $Key.Trim() -ne "" -and $Key -notmatch "^\s*$") {
        $script:LicLines.Add("[$Product]")
        $script:LicLines.Add("  Ключ : $Key")
        if ($Extra) { $script:LicLines.Add("  Инфо : $Extra") }
        $script:LicLines.Add("")
        $script:LicCount++
        Write-Ok "$Product : $($Key.Substring(0,[Math]::Min(8,$Key.Length)))****"
    }
}

# ---------------------------------------------------------------
# 6.1  WINDOWS — восстановление ключа через SoftwareLicensingService
# ---------------------------------------------------------------
Write-Step "Windows: извлечение ключа продукта..."
$LicLines.Add("──── WINDOWS ──────────────────────────────────────────────────")

try {
    # Метод 1: через WMI SoftwareLicensingService (работает на OEM и Retail)
    $SLS   = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingService" -ErrorAction Stop
    $WinKey = $SLS.OA3xOriginalProductKey
    if (-not $WinKey) {
        # Метод 2: декодирование DigitalProductId из реестра (универсальный)
        $RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        $dpid    = (Get-ItemProperty $RegPath).DigitalProductId
        if ($dpid -and $dpid.Length -ge 67) {
            $KeyOffset = 52
            $Chars     = "BCDFGHJKMPQRTVWXY2346789"
            $KeyChars  = New-Object char[] 25
            for ($i = 24; $i -ge 0; $i--) {
                $Cur = 0
                for ($j = 14; $j -ge 0; $j--) {
                    $Cur  = $Cur * 256 -bxor $dpid[$j + $KeyOffset]
                    $dpid[$j + $KeyOffset] = [math]::Floor($Cur / 24)
                    $Cur  = $Cur % 24
                }
                $KeyChars[$i] = $Chars[$Cur]
            }
            $WinKey = ($KeyChars -join "") -replace '(.{5})(?!$)','$1-'
        }
    }

    $WinEdition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
    $WinBuild   = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuild

    if ($WinKey) {
        Add-LicenseEntry "Windows" $WinKey "$WinEdition  Build $WinBuild"
    } else {
        $LicLines.Add("[Windows]")
        $LicLines.Add("  Ключ : НЕ ИЗВЛЕЧЁН (возможно, лицензия привязана к учётной записи Microsoft)")
        $LicLines.Add("  Инфо : $WinEdition  Build $WinBuild")
        $LicLines.Add("")
        Write-Warn "Windows: ключ не извлечён (Digital License / MSDM-привязка к железу)"
    }

    # Тип лицензии
    $LicStatus = (Get-WmiObject -Query "SELECT LicenseStatus,Description FROM SoftwareLicensingProduct WHERE PartialProductKey <> null AND Name LIKE 'Windows%'" |
                  Select-Object -First 1)
    if ($LicStatus) {
        $LicLines.Add("  Статус активации: $($LicStatus.Description)")
        $LicLines.Add("")
    }
} catch {
    Write-Fail "Windows: ошибка WMI — $_"
}

# ---------------------------------------------------------------
# 6.2  MICROSOFT OFFICE (все версии: 2013 / 2016 / 2019 / 2021 / 365)
# ---------------------------------------------------------------
Write-Step "Microsoft Office: поиск ключей во всех версиях..."
$LicLines.Add("──── MICROSOFT OFFICE ─────────────────────────────────────────")

$OfficePaths = @(
    "HKLM:\SOFTWARE\Microsoft\Office",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office"
)
$OfficeFound = $false
foreach ($OPath in $OfficePaths) {
    if (-not (Test-Path $OPath)) { continue }
    Get-ChildItem $OPath -ErrorAction SilentlyContinue | ForEach-Object {
        $Ver = $_.PSChildName
        if ($Ver -match '^\d+\.\d+$') {
            $RegBase = "$OPath\$Ver\Registration"
            if (Test-Path $RegBase) {
                Get-ChildItem $RegBase -ErrorAction SilentlyContinue | ForEach-Object {
                    $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    # DigitalProductId декодируем аналогично Windows
                    $dpid  = $props.DigitalProductId
                    if ($dpid -and $dpid.Length -ge 67) {
                        $KeyOffset = 52
                        $Chars     = "BCDFGHJKMPQRTVWXY2346789"
                        $dpidCopy  = $dpid.Clone()
                        $KeyChars  = New-Object char[] 25
                        for ($i = 24; $i -ge 0; $i--) {
                            $Cur = 0
                            for ($j = 14; $j -ge 0; $j--) {
                                $Cur           = $Cur * 256 -bxor $dpidCopy[$j + $KeyOffset]
                                $dpidCopy[$j + $KeyOffset] = [math]::Floor($Cur / 24)
                                $Cur           = $Cur % 24
                            }
                            $KeyChars[$i] = $Chars[$Cur]
                        }
                        $OffKey = ($KeyChars -join "") -replace '(.{5})(?!$)','$1-'
                        $Prod   = $props.ProductName
                        if (-not $Prod) { $Prod = "Microsoft Office $Ver" }
                        Add-LicenseEntry $Prod $OffKey
                        $OfficeFound = $true
                    }
                }
            }
        }
    }
}
if (-not $OfficeFound) {
    Write-Skip "Office: ключи в реестре не найдены (M365 подписка или Click-to-Run без локального ключа)"
    $LicLines.Add("[Microsoft Office]")
    $LicLines.Add("  Ключ : НЕ НАЙДЕН (возможно, Microsoft 365 — лицензия в учётной записи MS)")
    $LicLines.Add("")
}

# ---------------------------------------------------------------
# 6.3  UNIVERSAL: поиск ключей по реестровым путям (10+ продуктов)
# ---------------------------------------------------------------
Write-Step "Универсальный поиск ключей в реестре продуктов..."

# Описание: [Заголовок группы, Массив путей HKLM\..., Имя_свойства_с_ключом]
$RegProducts = @(
    @{
        Group = "──── VISUAL STUDIO ─────────────────────────────────────────────"
        Paths = @(
            "HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\Registration",   # VS 2015
            "HKLM:\SOFTWARE\Microsoft\VisualStudio\15.0\Registration",   # VS 2017
            "HKLM:\SOFTWARE\Microsoft\VisualStudio\16.0\Registration",   # VS 2019
            "HKLM:\SOFTWARE\Microsoft\VisualStudio\17.0\Registration",   # VS 2022
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\14.0\Registration",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\15.0\Registration",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\16.0\Registration",
            "HKLM:\SOFTWARE\Wow6432Node\Microsoft\VisualStudio\17.0\Registration"
        )
        PropKey  = "pidkey"
        PropName = "VisualStudioVersion"
        Label    = "Microsoft Visual Studio"
    },
    @{
        Group = "──── SQL SERVER ─────────────────────────────────────────────────"
        Paths = @(
            "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\120\Tools\Setup",  # 2014
            "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\130\Tools\Setup",  # 2016
            "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\140\Tools\Setup",  # 2017
            "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\150\Tools\Setup",  # 2019
            "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\160\Tools\Setup"   # 2022
        )
        PropKey  = "ProductKey"
        PropName = "Edition"
        Label    = "Microsoft SQL Server"
    },
    @{
        Group = "──── WINDOWS SERVER ─────────────────────────────────────────────"
        Paths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DefaultProductKey",
            "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\DefaultProductKey2"
        )
        PropKey  = "ProductKey"
        PropName = ""
        Label    = "Windows Server / KMS Key"
    }
)

foreach ($RG in $RegProducts) {
    $LicLines.Add($RG.Group)
    $found = $false
    foreach ($P in $RG.Paths) {
        if (Test-Path $P) {
            $props = Get-ItemProperty $P -ErrorAction SilentlyContinue
            $key   = $props.($RG.PropKey)
            $name  = if ($RG.PropName) { $props.($RG.PropName) } else { "" }
            if ($key) {
                Add-LicenseEntry $RG.Label $key $name
                $found = $true
            }
        }
    }
    if (-not $found) { Write-Skip "$($RG.Label): ключ не найден в реестре" }
}

# ---------------------------------------------------------------
# 6.4  JETBRAINS (IntelliJ, PyCharm, WebStorm, Rider, CLion…)
# ---------------------------------------------------------------
Write-Step "JetBrains: поиск лицензий..."
$LicLines.Add("──── JETBRAINS ─────────────────────────────────────────────────")

# JetBrains хранит лицензии в папках настроек IDE
$JBApps = @(
    @{Name="IntelliJ IDEA";  Dir="JetBrains\IntelliJIdea*"}
    @{Name="PyCharm";        Dir="JetBrains\PyCharm*"}
    @{Name="WebStorm";       Dir="JetBrains\WebStorm*"}
    @{Name="PhpStorm";       Dir="JetBrains\PhpStorm*"}
    @{Name="CLion";          Dir="JetBrains\CLion*"}
    @{Name="Rider";          Dir="JetBrains\Rider*"}
    @{Name="GoLand";         Dir="JetBrains\GoLand*"}
    @{Name="DataGrip";       Dir="JetBrains\DataGrip*"}
    @{Name="RubyMine";       Dir="JetBrains\RubyMine*"}
    @{Name="AppCode";        Dir="JetBrains\AppCode*"}
)

$JBDir     = New-BackupDir "Licenses\JetBrains"
$JBFound   = $false
$JBBaseDirs = @(
    "$env:AppData",
    "$env:LocalAppData"
)

foreach ($App in $JBApps) {
    foreach ($Base in $JBBaseDirs) {
        $Matches = Get-ChildItem (Join-Path $Base $App.Dir) -Directory -ErrorAction SilentlyContinue
        foreach ($M in $Matches) {
            # Файл лицензии
            $LicXml = Join-Path $M.FullName "config\idea.key"
            $LicDat = Join-Path $M.FullName "license\*.key"
            $LicJet = Get-ChildItem "$($M.FullName)\config\" -Filter "*.key" -ErrorAction SilentlyContinue |
                      Select-Object -First 1

            if ($LicJet) {
                $DestFile = Join-Path $JBDir "$($App.Name)_$($M.Name).key"
                Copy-Item $LicJet.FullName $DestFile -Force -ErrorAction SilentlyContinue
                Write-Ok "$($App.Name): лицензионный файл сохранён ($($LicJet.Name))"
                $LicLines.Add("[$($App.Name)]")
                $LicLines.Add("  Файл : Licenses\JetBrains\$($App.Name)_$($M.Name).key")
                $LicLines.Add("")
                $JBFound = $true
            }

            # Активационный код (subscription) в xml-конфиге
            $RegFile = Join-Path $M.FullName "config\options\other.xml"
            if (Test-Path $RegFile) {
                $Content = Get-Content $RegFile -Raw -ErrorAction SilentlyContinue
                if ($Content -match 'key="?licenseCode"?\s+value="([^"]+)"') {
                    Add-LicenseEntry "$($App.Name) (код активации)" $Matches[1]
                    $JBFound = $true
                }
            }
        }
    }
}

# Toolbox лицензии (JWT-токен)
$TBToken = Join-Path $env:AppData "JetBrains\Toolbox\.settings.json"
if (Test-Path $TBToken) {
    Copy-Item $TBToken (Join-Path $JBDir "toolbox_settings.json") -Force
    Write-Ok "JetBrains Toolbox: токен сохранён"
    $LicLines.Add("[JetBrains Toolbox]")
    $LicLines.Add("  Файл : Licenses\JetBrains\toolbox_settings.json")
    $LicLines.Add("")
    $JBFound = $true
}
if (-not $JBFound) { Write-Skip "JetBrains: лицензионные файлы не найдены" }

# ---------------------------------------------------------------
# 6.5  SUBLIME TEXT
# ---------------------------------------------------------------
Write-Step "Sublime Text: поиск лицензии..."
$LicLines.Add("──── SUBLIME TEXT ───────────────────────────────────────────────")

$SublimePaths = @(
    "$env:AppData\Sublime Text\Local\License.sublime_license",
    "$env:AppData\Sublime Text 3\Local\License.sublime_license",
    "$env:AppData\Sublime Text 2\Local\License.sublime_license"
)
$SublimeFound = $false
foreach ($SP in $sublimePaths) {
    if (Test-Path $SP) {
        Copy-Item $SP (Join-Path $LicDir "sublime_license.txt") -Force
        $content = Get-Content $SP -Raw
        # Извлекаем email и лицензионный блок для отображения в сводке
        $email = if ($content -match 'uti="([^"]+)"') { $Matches[1] } else { "см. файл" }
        $LicLines.Add("[Sublime Text]")
        $LicLines.Add("  Email : $email")
        $LicLines.Add("  Файл  : Licenses\sublime_license.txt")
        $LicLines.Add("")
        Write-Ok "Sublime Text: лицензия сохранена (email: $email)"
        $SublimeFound = $true
        break
    }
}
if (-not $SublimeFound) { Write-Skip "Sublime Text: лицензионный файл не найден" }

# ---------------------------------------------------------------
# 6.6  TOTAL COMMANDER
# ---------------------------------------------------------------
Write-Step "Total Commander: поиск лицензии..."
$LicLines.Add("──── TOTAL COMMANDER ────────────────────────────────────────────")

$TCPaths = @(
    "$env:AppData\GHISLER\wincmd.ini",
    "C:\Windows\wincmd.ini",
    "$env:ProgramFiles\totalcmd\wincmd.ini",
    "${env:ProgramFiles(x86)}\totalcmd\wincmd.ini"
)
$TCFound = $false
foreach ($TCP in $TCPaths) {
    if (Test-Path $TCP) {
        $ini = Get-Content $TCP -Raw -ErrorAction SilentlyContinue
        if ($ini -match 'RegName=(.+)' ) { $tcName = $Matches[1].Trim() }
        if ($ini -match 'Registration=(.+)' ) { $tcReg = $Matches[1].Trim() }
        if ($tcName -and $tcReg) {
            Copy-Item $TCP (Join-Path $LicDir "totalcmd_wincmd.ini") -Force
            Add-LicenseEntry "Total Commander" $tcReg "Имя: $tcName"
            $TCFound = $true
            break
        }
    }
}
if (-not $TCFound) { Write-Skip "Total Commander: wincmd.ini не найден или ключ отсутствует" }

# ---------------------------------------------------------------
# 6.7  WINRAR
# ---------------------------------------------------------------
Write-Step "WinRAR: поиск лицензии..."
$LicLines.Add("──── WINRAR ─────────────────────────────────────────────────────")

$WRPaths = @(
    "$env:AppData\WinRAR\rarreg.key",
    "$env:ProgramFiles\WinRAR\rarreg.key",
    "${env:ProgramFiles(x86)}\WinRAR\rarreg.key"
)
$WRFound = $false
foreach ($WRP in $WRPaths) {
    if (Test-Path $WRP) {
        Copy-Item $WRP (Join-Path $LicDir "winrar_rarreg.key") -Force
        $wrcontent = Get-Content $WRP -TotalCount 3 -ErrorAction SilentlyContinue
        $LicLines.Add("[WinRAR]")
        $LicLines.Add("  Файл : Licenses\winrar_rarreg.key")
        $LicLines.Add("  Инфо : $($wrcontent -join ' | ')")
        $LicLines.Add("")
        Write-Ok "WinRAR: rarreg.key сохранён"
        $WRFound = $true
        break
    }
}
if (-not $WRFound) { Write-Skip "WinRAR: rarreg.key не найден" }

# ---------------------------------------------------------------
# 6.8  VMWARE (Workstation / Player)
# ---------------------------------------------------------------
Write-Step "VMware: поиск серийного номера..."
$LicLines.Add("──── VMWARE ─────────────────────────────────────────────────────")

$VMwarePaths = @(
    "HKLM:\SOFTWARE\VMware, Inc.\VMware Workstation",
    "HKLM:\SOFTWARE\Wow6432Node\VMware, Inc.\VMware Workstation",
    "HKLM:\SOFTWARE\VMware, Inc.\VMware Player",
    "HKLM:\SOFTWARE\Wow6432Node\VMware, Inc.\VMware Player"
)
$VMFound = $false
foreach ($VMP in $VMwarePaths) {
    if (Test-Path $VMP) {
        $props = Get-ItemProperty $VMP -ErrorAction SilentlyContinue
        $serial = $props.Serial -or $props.ProductID -or $props.SerialNumber
        $ver    = $props.ProductVersion
        if ($serial) {
            Add-LicenseEntry "VMware" $serial "Version: $ver"
            $VMFound = $true
        }
    }
}
if (-not $VMFound) { Write-Skip "VMware: серийный номер в реестре не найден" }

# ---------------------------------------------------------------
# 6.9  AUTODESK (AutoCAD, 3ds Max, Maya, Inventor, Revit, Fusion)
# ---------------------------------------------------------------
Write-Step "Autodesk: поиск серийных номеров..."
$LicLines.Add("──── AUTODESK ───────────────────────────────────────────────────")

$ADPath = "HKLM:\SOFTWARE\Autodesk\LicensingService\Locale"
$ADPathWow = "HKLM:\SOFTWARE\Wow6432Node\Autodesk\LicensingService\Locale"
$ADFound = $false
foreach ($ADP in @($ADPath, $ADPathWow)) {
    if (Test-Path $ADP) {
        Get-ChildItem $ADP -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($p.ProductKey) {
                Add-LicenseEntry "Autodesk ($($_.PSChildName))" $p.ProductKey $p.ProductName
                $ADFound = $true
            }
        }
    }
}
# Autodesk также хранит данные в AdSSO папке
$AdSSODir = "$env:ProgramData\Autodesk\AdSSO"
if (Test-Path $AdSSODir) {
    $AdSSODst = New-BackupDir "Licenses\Autodesk"
    Copy-Item "$AdSSODir\*" $AdSSODst -Recurse -Force -ErrorAction SilentlyContinue
    $LicLines.Add("[Autodesk AdSSO (токены авторизации)]")
    $LicLines.Add("  Файлы : Licenses\Autodesk\")
    $LicLines.Add("")
    Write-Ok "Autodesk: AdSSO токены скопированы"
}
if (-not $ADFound) { Write-Skip "Autodesk: ключи в реестре не найдены" }

# ---------------------------------------------------------------
# 6.10 ADOBE (Creative Cloud — токены и лицензионные файлы)
# ---------------------------------------------------------------
Write-Step "Adobe: поиск лицензионных данных..."
$LicLines.Add("──── ADOBE ──────────────────────────────────────────────────────")

$AdobeDir = New-BackupDir "Licenses\Adobe"
$AdobeFound = $false

# Adobe хранит лицензии и токены в нескольких местах
$AdobeLicPaths = @(
    "$env:ProgramData\Adobe\SLStore",                   # Лицензионное хранилище SL
    "$env:ProgramData\FLEXnet",                         # FLEXnet (старые версии CS)
    "$env:AppData\Adobe\SLStore"
)
foreach ($ALP in $AdobeLicPaths) {
    if (Test-Path $ALP) {
        Copy-Item "$ALP\*" $AdobeDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "Adobe: скопировано из $ALP"
        $LicLines.Add("[Adobe SLStore / FLEXnet]")
        $LicLines.Add("  Папка : Licenses\Adobe\")
        $LicLines.Add("  Источник: $ALP")
        $LicLines.Add("")
        $AdobeFound = $true
    }
}
# Серийные номера CS-продуктов в реестре
$AdobeRegPath = "HKLM:\SOFTWARE\Adobe"
if (Test-Path $AdobeRegPath) {
    Get-ChildItem $AdobeRegPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($p.Serial -or $p.SerialNumber) {
            $sn = $p.Serial ?? $p.SerialNumber
            Add-LicenseEntry "Adobe $($_.PSChildName)" $sn
            $AdobeFound = $true
        }
    }
}
if (-not $AdobeFound) {
    Write-Skip "Adobe: лицензионные файлы не найдены"
    $LicLines.Add("[Adobe]")
    $LicLines.Add("  Инфо : Лицензии Adobe CC управляются через Creative Cloud аккаунт.")
    $LicLines.Add("         После установки CC Desktop App войдите в тот же Adobe ID.")
    $LicLines.Add("")
}

# ---------------------------------------------------------------
# 6.11 АНТИВИРУСЫ
# ---------------------------------------------------------------
Write-Step "Антивирусы: поиск лицензионных ключей..."
$LicLines.Add("──── АНТИВИРУСЫ ─────────────────────────────────────────────────")

$AVProducts = @(
    @{Name="Kaspersky";      Paths=@("HKLM:\SOFTWARE\KasperskyLab","HKLM:\SOFTWARE\Wow6432Node\KasperskyLab"); Key="LicenseKey" }
    @{Name="Dr.Web";         Paths=@("HKLM:\SOFTWARE\Doctor Web","HKLM:\SOFTWARE\Wow6432Node\Doctor Web");    Key="SerialNumber" }
    @{Name="ESET NOD32";     Paths=@("HKLM:\SOFTWARE\ESET\ESET Security","HKLM:\SOFTWARE\Wow6432Node\ESET"); Key="ProductKey" }
    @{Name="Avast";          Paths=@("HKLM:\SOFTWARE\Avast Software\Avast");                                  Key="LicKey" }
    @{Name="Norton";         Paths=@("HKLM:\SOFTWARE\Norton","HKLM:\SOFTWARE\Wow6432Node\Norton");            Key="ProductKey" }
    @{Name="Malwarebytes";   Paths=@("HKLM:\SOFTWARE\Malwarebytes","HKLM:\SOFTWARE\Wow6432Node\Malwarebytes"); Key="ProductKey" }
)
foreach ($AV in $AVProducts) {
    $avFound = $false
    foreach ($AVP in $AV.Paths) {
        if (Test-Path $AVP) {
            Get-ChildItem $AVP -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                $k = $p.($AV.Key)
                if ($k) { Add-LicenseEntry $AV.Name $k; $avFound = $true }
            }
        }
    }
    if (-not $avFound) { Write-Skip "$($AV.Name): ключ не найден" }
}

# ---------------------------------------------------------------
# 6.12 1С:Предприятие
# ---------------------------------------------------------------
Write-Step "1С:Предприятие: поиск лицензии..."
$LicLines.Add("──── 1С:ПРЕДПРИЯТИЕ ─────────────────────────────────────────────")

$OneCPaths = @(
    "$env:AppData\1C\1CEStart",
    "$env:LocalAppData\1C\1CEStart",
    "C:\ProgramData\1C\licenses",
    "$env:AppData\1C\licenses"
)
$OneCDir   = New-BackupDir "Licenses\1C"
$OneCFound = $false
foreach ($OCP in $OneCPaths) {
    if (Test-Path $OCP) {
        $LicFiles = Get-ChildItem $OCP -Filter "*.lic" -Recurse -ErrorAction SilentlyContinue
        $LicFiles += Get-ChildItem $OCP -Filter "*.key" -Recurse -ErrorAction SilentlyContinue
        if ($LicFiles.Count -gt 0) {
            Copy-Item $LicFiles.FullName $OneCDir -Force -ErrorAction SilentlyContinue
            $LicLines.Add("[1С:Предприятие]")
            $LicLines.Add("  Папка  : Licenses\1C\")
            $LicLines.Add("  Файлов : $($LicFiles.Count)")
            $LicLines.Add("")
            Write-Ok "1С: скопировано лицензионных файлов: $($LicFiles.Count)"
            $OneCFound = $true
        }
    }
}
if (-not $OneCFound) { Write-Skip "1С:Предприятие: лицензионные файлы не найдены" }

# ---------------------------------------------------------------
# 6.13 УНИВЕРСАЛЬНЫЙ СКАН РЕЕСТРА UNINSTALL (партнёрский поиск)
#      Ищем ProductID / SerialNumber / LicenseKey в записях деинсталляции
# ---------------------------------------------------------------
Write-Step "Универсальный скан реестра деинсталляции на наличие ключей..."
$LicLines.Add("──── ПРОЧИЕ ПРОДУКТЫ (авто-обнаружение) ────────────────────────")

$UninstPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$ScannedNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$KeyProps = @("ProductID","ProductKey","SerialNumber","LicenseKey","RegistrationCode","ActivationCode")

Get-ItemProperty $UninstPaths -ErrorAction SilentlyContinue | ForEach-Object {
    $dispName = $_.DisplayName
    if (-not $dispName -or $ScannedNames.Contains($dispName)) { return }
    foreach ($KP in $KeyProps) {
        $val = $_.$KP
        # Фильтруем: ключ должен быть похож на лицензионный (> 8 симв, содержит цифры)
        if ($val -and $val.Length -gt 8 -and $val -match '\d' -and $val -notmatch '^[0-9]+$') {
            Add-LicenseEntry $dispName $val
            $ScannedNames.Add($dispName) | Out-Null
            break
        }
    }
}
Write-Ok "Скан реестра деинсталляции завершён"

# ---------------------------------------------------------------
# Сохраняем сводный файл лицензий
# ---------------------------------------------------------------
$LicLines.Add("")
$LicLines.Add("=" * 68)
$LicLines.Add("  Итого найдено лицензий: $LicCount")
$LicLines.Add("  Дата экспорта         : $DateStamp")
$LicLines.Add("=" * 68)

$LicLines | Out-File $LicFile -Encoding UTF8

Write-Ok "Сводный файл: Licenses\license_keys.txt  ($LicCount записей)"

# Предупреждение о безопасности
Write-Host "`n  [!] БЕЗОПАСНОСТЬ: папка Licenses\ содержит конфиденциальные данные." -ForegroundColor DarkYellow
Write-Host "      Не оставляйте флешку без присмотра. Рассмотрите шифрование папки." -ForegroundColor DarkYellow

# ==============================================================
# 7. ГЛОБАЛЬНЫЕ ПАКЕТЫ
# ==============================================================
Write-Section "БЛОК 7: Глобальные пакеты менеджеров"

$PackagesDir = New-BackupDir "Packages"

# ---- npm ----
Write-Step "npm: глобальные пакеты..."
$NpmExe = (Get-Command "npm.cmd" -ErrorAction SilentlyContinue) ??
          (Get-Command "npm"     -ErrorAction SilentlyContinue)
if (-not $NpmExe) {
    Write-Skip "npm не найден"
} else {
    Write-Log "  Node: $(& node --version 2>&1) | npm: $(& npm --version 2>&1)" "Gray" "INFO"
    $NpmJson = & npm list -g --depth=0 --json 2>&1 | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($NpmJson -and $NpmJson.dependencies) {
        $Pkgs = $NpmJson.dependencies.PSObject.Properties | ForEach-Object { "$($_.Name)@$($_.Value.version)" }
        $Pkgs | Out-File (Join-Path $PackagesDir "npm_global.txt") -Encoding UTF8
        @'
Get-Content "$PSScriptRoot\npm_global.txt" | ForEach-Object { npm install -g $_ }
'@ | Out-File (Join-Path $PackagesDir "RESTORE_NPM.ps1") -Encoding UTF8
        Write-Ok "npm: $($Pkgs.Count) пакетов -> npm_global.txt"
    } else { Write-Skip "npm: глобальные пакеты не найдены" }
}

# ---- pip ----
Write-Step "pip: глобальные пакеты..."
$PipExe = (Get-Command "pip3" -ErrorAction SilentlyContinue) ??
          (Get-Command "pip"  -ErrorAction SilentlyContinue)
if (-not $PipExe) {
    Write-Skip "pip не найден"
} else {
    Write-Log "  Python: $(& python --version 2>&1)" "Gray" "INFO"
    $PipFile = Join-Path $PackagesDir "pip_requirements.txt"
    & pip freeze --user 2>&1 | Out-File $PipFile -Encoding UTF8
    if ((Get-Content $PipFile | Where-Object { $_ -match '\S' }).Count -eq 0) {
        & pip list --format=freeze 2>&1 |
            Where-Object { $_ -notmatch "^(pip|setuptools|wheel)==" } |
            Out-File $PipFile -Encoding UTF8
    }
    $pc = (Get-Content $PipFile | Where-Object { $_ -match "==" }).Count
    @'
pip install -r "$PSScriptRoot\pip_requirements.txt"
'@ | Out-File (Join-Path $PackagesDir "RESTORE_PIP.ps1") -Encoding UTF8
    Write-Ok "pip: $pc пакетов -> pip_requirements.txt"
}

# ---- cargo ----
Write-Step "cargo (Rust): крейты..."
if (Get-Command "cargo" -ErrorAction SilentlyContinue) {
    Write-Log "  $(& cargo --version 2>&1)" "Gray" "INFO"
    $Crates = & cargo install --list 2>&1 |
        Where-Object { $_ -match '^[a-z0-9_-]+ v[\d.]+' } |
        ForEach-Object { ($_ -split ' v')[0].Trim() }
    if ($Crates.Count -gt 0) {
        $Crates | Out-File (Join-Path $PackagesDir "cargo_crates.txt") -Encoding UTF8
        @'
Get-Content "$PSScriptRoot\cargo_crates.txt" | ForEach-Object { cargo install $_ }
'@ | Out-File (Join-Path $PackagesDir "RESTORE_CARGO.ps1") -Encoding UTF8
        Write-Ok "cargo: $($Crates.Count) крейтов"
    } else { Write-Skip "cargo: крейты не найдены" }
} else { Write-Skip "cargo не найден" }

# ---- gem ----
Write-Step "gem (Ruby)..."
if (Get-Command "gem" -ErrorAction SilentlyContinue) {
    $Gems = & gem list --no-versions 2>&1 | Where-Object { $_ -match '\S' -and $_ -notmatch '^LOCAL' }
    if ($Gems.Count -gt 0) {
        $Gems | Out-File (Join-Path $PackagesDir "ruby_gems.txt") -Encoding UTF8
        @'
Get-Content "$PSScriptRoot\ruby_gems.txt" | ForEach-Object { gem install $_ }
'@ | Out-File (Join-Path $PackagesDir "RESTORE_GEMS.ps1") -Encoding UTF8
        Write-Ok "gem: $($Gems.Count) пакетов"
    } else { Write-Skip "gem: пакеты не найдены" }
} else { Write-Skip "gem не найден" }

# ---- composer ----
Write-Step "Composer (PHP)..."
if (Get-Command "composer" -ErrorAction SilentlyContinue) {
    $CJson = "$env:USERPROFILE\AppData\Roaming\Composer\composer.json"
    if (Test-Path $CJson) {
        Copy-Item $CJson (Join-Path $PackagesDir "composer_global.json") -Force
        @'
$d="$env:USERPROFILE\AppData\Roaming\Composer"
New-Item -ItemType Directory -Path $d -Force|Out-Null
Copy-Item "$PSScriptRoot\composer_global.json" "$d\composer.json" -Force
Set-Location $d; composer global install
'@ | Out-File (Join-Path $PackagesDir "RESTORE_COMPOSER.ps1") -Encoding UTF8
        Write-Ok "Composer: composer_global.json сохранён"
    } else { Write-Skip "Composer: composer.json не найден" }
} else { Write-Skip "composer не найден" }

# ---- winget ----
Write-Step "winget: экспорт установленного ПО..."
if (Get-Command "winget" -ErrorAction SilentlyContinue) {
    $WFile = Join-Path $PackagesDir "winget_export.json"
    & winget export -o "$WFile" --accept-source-agreements 2>&1 | Out-Null
    if (Test-Path $WFile) {
        $wc = (Get-Content $WFile | ConvertFrom-Json -ErrorAction SilentlyContinue).Sources.Packages.Count
        @'
winget import -i "$PSScriptRoot\winget_export.json" --accept-source-agreements --accept-package-agreements
'@ | Out-File (Join-Path $PackagesDir "RESTORE_WINGET.ps1") -Encoding UTF8
        Write-Ok "winget: $wc приложений -> winget_export.json"
    } else { Write-Fail "winget export не удался" }
} else { Write-Skip "winget не найден" }

# ==============================================================
# 8. ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ
# ==============================================================
Write-Section "БЛОК 8: Переменные окружения"

$EnvDir  = New-BackupDir "Environment"
$UserEnv = [System.Environment]::GetEnvironmentVariables("User")
$SysEnv  = [System.Environment]::GetEnvironmentVariables("Machine")
$UserEnv | ConvertTo-Json | Out-File (Join-Path $EnvDir "env_user.json")    -Encoding UTF8
$SysEnv  | ConvertTo-Json | Out-File (Join-Path $EnvDir "env_machine.json") -Encoding UTF8
"# PATH пользователя:`n" + (($UserEnv["PATH"] -split ";") -join "`n") | Out-File (Join-Path $EnvDir "PATH_user.txt")    -Encoding UTF8
"# PATH системный:`n"    + (($SysEnv["PATH"]  -split ";") -join "`n") | Out-File (Join-Path $EnvDir "PATH_machine.txt") -Encoding UTF8
@'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Definition
(Get-Content "$dir\env_user.json" | ConvertFrom-Json).PSObject.Properties |
    Where-Object { $_.Name -ne "PATH" } |
    ForEach-Object {
        [System.Environment]::SetEnvironmentVariable($_.Name,$_.Value,"User")
        Write-Host "[+] $($_.Name)"
    }
Write-Host "`nPATH — добавьте вручную из PATH_user.txt и PATH_machine.txt"
'@ | Out-File (Join-Path $EnvDir "RESTORE_ENV.ps1") -Encoding UTF8
Write-Ok "Переменных: пользователь=$($UserEnv.Count), система=$($SysEnv.Count)"

# ==============================================================
# 9. КОНФИГУРАЦИОННЫЕ ФАЙЛЫ РАЗРАБОТЧИКА
# ==============================================================
Write-Section "БЛОК 9: Конфиги разработчика"

$ConfigDir = New-BackupDir "DevConfigs"
$Cfgs = @(
    @{D="Git config";              S="$env:USERPROFILE\.gitconfig";                                                                   T="gitconfig"}
    @{D="Git ignore global";       S="$env:USERPROFILE\.gitignore_global";                                                            T="gitignore_global"}
    @{D="WSL2 ядро .wslconfig";   S="$env:USERPROFILE\.wslconfig";                                                                    T="wslconfig"}
    @{D="PowerShell профиль";      S=$PROFILE;                                                                                         T="powershell_profile.ps1"}
    @{D="Windows Terminal";        S="$env:LocalAppData\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json";   T="wt_settings.json"}
    @{D="VS Code settings";        S="$env:AppData\Code\User\settings.json";                                                          T="vscode_settings.json"}
    @{D="VS Code keybindings";     S="$env:AppData\Code\User\keybindings.json";                                                       T="vscode_keybindings.json"}
    @{D="VS Code snippets";        S="$env:AppData\Code\User\snippets";                                                               T="vscode_snippets"}
    @{D=".npmrc";                  S="$env:USERPROFILE\.npmrc";                                                                        T="npmrc"}
    @{D="pip.ini";                 S="$env:AppData\pip\pip.ini";                                                                      T="pip.ini"}
    @{D="cargo config.toml";       S="$env:USERPROFILE\.cargo\config.toml";                                                           T="cargo_config.toml"}
    @{D="Docker settings";         S="$env:AppData\Docker\settings.json";                                                             T="docker_settings.json"}
    @{D=".editorconfig";           S="$env:USERPROFILE\.editorconfig";                                                                T="editorconfig"}
    @{D="hosts файл";              S="C:\Windows\System32\drivers\etc\hosts";                                                         T="hosts"}
    @{D="Maven settings.xml";      S="$env:USERPROFILE\.m2\settings.xml";                                                             T="maven_settings.xml"}
    @{D="Gradle gradle.properties";S="$env:USERPROFILE\.gradle\gradle.properties";                                                    T="gradle.properties"}
    @{D="Kubectl config";          S="$env:USERPROFILE\.kube\config";                                                                 T="kubectl_config"}
    @{D="AWS credentials";         S="$env:USERPROFILE\.aws\credentials";                                                             T="aws_credentials"}
    @{D="AWS config";              S="$env:USERPROFILE\.aws\config";                                                                  T="aws_config"}
    @{D="Azure CLI config";        S="$env:USERPROFILE\.azure\config";                                                                T="azure_config"}
    @{D="Terraform .terraformrc";  S="$env:USERPROFILE\.terraformrc";                                                                 T="terraformrc"}
    @{D="Ansible ansible.cfg";     S="$env:USERPROFILE\.ansible.cfg";                                                                 T="ansible.cfg"}
)
foreach ($C in $Cfgs) {
    if (Test-Path $C.S) {
        Copy-Item $C.S (Join-Path $ConfigDir $C.T) -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok $C.D
    } else {
        Write-Skip "$($C.D) — не найден"
    }
}

# VS Code расширения
if (Get-Command "code" -ErrorAction SilentlyContinue) {
    $ExtFile = Join-Path $ConfigDir "vscode_extensions.txt"
    & code --list-extensions 2>&1 | Out-File $ExtFile -Encoding UTF8
    $ec = (Get-Content $ExtFile | Where-Object { $_ -match '\S' }).Count
    @'
Get-Content "$PSScriptRoot\vscode_extensions.txt" | Where-Object { $_ -match '\S' } |
    ForEach-Object { code --install-extension $_ }
'@ | Out-File (Join-Path $ConfigDir "RESTORE_VSCODE_EXT.ps1") -Encoding UTF8
    Write-Ok "VS Code расширений: $ec"
}

# ==============================================================
# 10. ИТОГОВЫЙ ОТЧЁТ
# ==============================================================
Write-Section "ИТОГ"

$EndTime     = Get-Date
$Duration    = [math]::Round(($EndTime - $StartTime).TotalMinutes,1)
$BackupBytes = (Get-ChildItem $BackupRoot -Recurse -File | Measure-Object Length -Sum).Sum
$BackupSizeGB= [math]::Round($BackupBytes/1GB,2)

Write-Ok "Время выполнения  : $Duration мин"
Write-Ok "Размер бэкапа     : $BackupSizeGB ГБ"
Write-Ok "Лицензий найдено  : $LicCount"
Write-Ok "Папка бэкапа      : $BackupRoot"

$LogLines | Out-File $LogFile -Encoding UTF8

Write-Host "`n$(("=" * 70))" -ForegroundColor Green
Write-Host "  БЭКАП ЗАВЕРШЁН." -ForegroundColor Green
Write-Host "  Дождитесь, пока значок флешки в трее перестанет мигать," -ForegroundColor Green
Write-Host "  и только затем извлекайте накопитель." -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Green

Write-Host "`n  Структура сохранённых данных:" -ForegroundColor Cyan
Write-Host "  $BackupRoot\" -ForegroundColor White
Write-Host "  ├── Drivers\                OEM-драйверы (DISM) + drivers_inventory.csv" -ForegroundColor Gray
Write-Host "  ├── WSL2\                   Дистрибутивы (.tar.gz) + RESTORE_WSL.ps1" -ForegroundColor Gray
Write-Host "  ├── Docker\                 Образы (.tar) + RESTORE_DOCKER.ps1" -ForegroundColor Gray
Write-Host "  ├── SSH\                    ~/.ssh ключи + RESTORE_SSH.ps1" -ForegroundColor Gray
Write-Host "  ├── Licenses\               ЛИЦЕНЗИОННЫЕ КЛЮЧИ" -ForegroundColor Yellow
Write-Host "  │   ├── license_keys.txt    Windows, Office, VisualStudio, SQL Server," -ForegroundColor Yellow
Write-Host "  │   │                       TotalCmd, WinRAR, VMware, Sublime, АВ-ключи," -ForegroundColor Yellow
Write-Host "  │   │                       Autodesk и все найденные в реестре" -ForegroundColor Yellow
Write-Host "  │   ├── JetBrains\          .key файлы IDE + Toolbox токен" -ForegroundColor Gray
Write-Host "  │   ├── Adobe\              SLStore + FLEXnet файлы" -ForegroundColor Gray
Write-Host "  │   ├── Autodesk\           AdSSO токены" -ForegroundColor Gray
Write-Host "  │   ├── 1C\                 .lic / .key файлы 1С:Предприятие" -ForegroundColor Gray
Write-Host "  │   ├── winrar_rarreg.key   WinRAR лицензия" -ForegroundColor Gray
Write-Host "  │   └── sublime_license.txt Sublime Text лицензия" -ForegroundColor Gray
Write-Host "  ├── Packages\               npm / pip / cargo / gem / composer / winget" -ForegroundColor Gray
Write-Host "  ├── Environment\            Переменные окружения + PATH" -ForegroundColor Gray
Write-Host "  ├── DevConfigs\             .gitconfig, .wslconfig, VS Code, WinTerminal," -ForegroundColor Gray
Write-Host "  │                           kubectl, AWS, Azure, Terraform, Ansible..." -ForegroundColor Gray
Write-Host "  └── backup_log.txt          Полный лог операции`n" -ForegroundColor Gray
