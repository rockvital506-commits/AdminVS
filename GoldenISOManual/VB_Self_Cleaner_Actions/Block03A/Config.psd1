$config = @'
#Requires -Version 5.1
# ==============================================================================
# КОНФИГУРАЦИЯ БЛОКА 03A: Блокировка фоновой активности
# ВАЖНО: Этот файл автоматически сохранён в кодировке UTF-8 с BOM!
# ==============================================================================
# ИНСТРУКЦИЯ:
# Чтобы отключить целый блок, установите Enabled = $false
# Чтобы отключить конкретную службу, закомментируйте строку в массиве Services.
# ==============================================================================

@{
    # --- БЛОК 1: WINDOWS UPDATE ---
    WindowsUpdate = @{
        Enabled = $true
        Services = @(
            @{ Name = 'wuauserv';    State = 'Disabled'; Method = 'Service'  }
            @{ Name = 'UsoSvc';      State = 'Disabled'; Method = 'Service'  }
            @{ Name = 'WaaSMedicSvc';State = 'Disabled'; Method = 'Registry' } # TrustedInstaller
            @{ Name = 'DoSvc';       State = 'Disabled'; Method = 'Registry' } # TrustedInstaller
            @{ Name = 'BITS';        State = 'Manual';   Method = 'Service'  }
        )
    }

    # --- БЛОК 2: MICROSOFT STORE & APPX ---
    StoreAppX = @{
        Enabled = $true
        Services = @(
            @{ Name = 'InstallService'; State = 'Disabled'; Method = 'Registry' }
            @{ Name = 'AppXSvc';        State = 'Disabled'; Method = 'Registry' }
            @{ Name = 'ClipSVC';        State = 'Disabled'; Method = 'Registry' }
            @{ Name = 'LicenseManager'; State = 'Disabled'; Method = 'Service'  }
        )
    }

    # --- БЛОК 3: ТЕЛЕМЕТРИЯ И ДИАГНОСТИКА ---
    Telemetry = @{
        Enabled = $true
        Services = @(
            @{ Name = 'DiagTrack';         State = 'Disabled'; Method = 'Service' }
            @{ Name = 'dmwappushservice';  State = 'Disabled'; Method = 'Service' }
            @{ Name = 'WerSvc';            State = 'Disabled'; Method = 'Service' }
        )
    }

    # --- БЛОК 4: ИНДЕКСАЦИЯ И КЭШИРОВАНИЕ ---
    Indexing = @{
        Enabled = $true
        Services = @(
            @{ Name = 'WSearch'; State = 'Disabled'; Method = 'Service' }
            @{ Name = 'SysMain'; State = 'Disabled'; Method = 'Service' }
        )
    }

    # --- БЛОК 5: РЕЕСТР И ПОЛИТИКИ ---
    RegistryPolicies = @{
        Enabled = $true
        Keys = @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'DODownloadMode';      Value = 0; Type = 'DWord' },
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization'; Name = 'AllowCloudDownload';  Value = 0; Type = 'DWord' },
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive';             Name = 'DisableFileSyncNGSC'; Value = 1; Type = 'DWord' },
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive';             Name = 'PreventOneDriveFromStarting'; Value = 1; Type = 'DWord' }
        )
    }

    # --- БЛОК 6: ЗАДАЧИ ПЛАНИРОВЩИКА ---
    ScheduledTasks = @{
        Enabled = $true
        Paths = @(
            '\Microsoft\Windows\WindowsUpdate\',
            '\Microsoft\Windows\Setup\',
            '\Microsoft\Windows\Application Experience\',
            '\Microsoft\Windows\Customer Experience Improvement Program\',
            '\Microsoft\Windows\Autochk\',
            '\Microsoft\Windows\DiskDiagnostic\'
        )
    }
}
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\Config.psd1", $config, $utf8Bom)

Write-Host "[+] Файл Config.psd1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green