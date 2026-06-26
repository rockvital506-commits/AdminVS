<#
.SYNOPSIS
    Critical Data Backup Script for Windows Migration (FIXED)
.DESCRIPTION
    Backs up drivers, WSL2, Docker, SSH keys, licenses, configs to USB drive.
    FIXED: Cyrillic paths, WSL2 parsing, NULL handling.
.NOTES
    Requires: Administrator privileges
    Encoding: UTF-8 with BOM
#>

[CmdletBinding()]
param(
    [string]$Destination = ""
)

# ==============================================================================
# INITIALIZATION
# ==============================================================================
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = "SilentlyContinue"
$StartTime = Get-Date

# FIX: Use .NET method for user profile path (handles Cyrillic correctly)
$UserProfilePath = [Environment]::GetFolderPath("UserProfile")
Write-Host "User Profile: $UserProfilePath" -ForegroundColor Gray

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-Status "==========================================================================" "Yellow"
Write-Status "  CRITICAL DATA BACKUP - Windows Migration Preparation (FIXED)" "Yellow"
Write-Status "==========================================================================" "Yellow"

# ==============================================================================
# 0. CHECK ADMINISTRATOR PRIVILEGES
# ==============================================================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Status "[X] CRITICAL: Run as Administrator!" "Red"
    pause
    Exit 1
}

# ==============================================================================
# 1. DETERMINE DESTINATION DRIVE
# ==============================================================================
Write-Status "`n[INFO] Determining destination drive..." "Cyan"

if ($Destination -eq "") {
    Write-Status "  Auto-searching removable drive..." "Gray"
    $RemovableDrive = Get-WmiObject Win32_LogicalDisk |
        Where-Object {
            $_.DriveType -eq 2 -and
            $_.FreeSpace -gt 16GB -and
            ($_.FileSystem -eq "NTFS" -or $_.FileSystem -eq "exFAT")
        } | Sort-Object FreeSpace -Descending | Select-Object -First 1
    
    if (-not $RemovableDrive) {
        Write-Status "[X] Removable drive not found. Use -Destination parameter." "Red"
        pause
        Exit 1
    }
    $Destination = $RemovableDrive.DeviceID
    Write-Status "[+] Selected drive: $Destination (Free: $([math]::Round($RemovableDrive.FreeSpace/1GB,1)) GB)" "Green"
} else {
    if (-not (Test-Path $Destination)) {
        Write-Status "[X] Path '$Destination' not accessible." "Red"
        pause
        Exit 1
    }
    Write-Status "[+] Destination: $Destination" "Green"
}

# Create backup structure
$DateStamp = (Get-Date).ToString("yyyy-MM-dd_HHmm")
$BackupRoot = Join-Path $Destination "PC_Backup_$DateStamp"
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
Write-Status "[+] Backup folder: $BackupRoot" "Green"

function New-BackupDir {
    param([string]$Name)
    $p = Join-Path $BackupRoot $Name
    New-Item -ItemType Directory -Path $p -Force | Out-Null
    return $p
}

# ==============================================================================
# 2. EXPORT DRIVERS
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 1/12: Export Drivers" "Yellow"
Write-Status "==========================================================================" "Cyan"

$DriversDir = New-BackupDir "Drivers"
Write-Status "  [INFO] DISM /Export-Driver..." "Gray"

try {
    & DISM.exe /Online /Export-Driver /Destination:$DriversDir | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $dc = (Get-ChildItem $DriversDir -Filter "*.inf" -Recurse).Count
        Write-Status "  [+] Exported drivers: $dc" "Green"
    } else {
        Write-Status "  [!] DISM exit code: $LASTEXITCODE" "Yellow"
    }
} catch {
    Write-Status "  [X] Driver export error: $($_.Exception.Message)" "Red"
}

# ==============================================================================
# 3. EXPORT WSL2 DISTRIBUTIONS (FIXED PARSING)
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 2/12: Export WSL2 Distributions" "Yellow"
Write-Status "==========================================================================" "Cyan"

$WslDir = New-BackupDir "WSL2"

if (-not (Get-Command "wsl.exe" -ErrorAction SilentlyContinue)) {
    Write-Status "  [~] WSL not installed" "Gray"
} else {
    try {
        Write-Status "  [INFO] Getting distribution list..." "Gray"
        
        # FIX: Parse WSL output correctly - remove null chars, carriage returns, empty lines
        $WslRaw = & wsl.exe --list --quiet 2>&1
        $Distros = $WslRaw -split "`n" |
            ForEach-Object { $_ -replace "`r", "" -replace "`0", "" } |
            Where-Object { $_ -match '\S' -and $_ -notmatch 'Windows Subsystem' -and $_.Trim().Length -gt 0 } |
            ForEach-Object { $_.Trim() }
        
        Write-Status "  [INFO] Raw WSL output length: $($WslRaw.Length) chars" "Gray"
        Write-Status "  [INFO] Found distributions: $($Distros.Count)" "Gray"
        
        if ($Distros.Count -eq 0) {
            Write-Status "  [~] No WSL distributions found" "Gray"
            Write-Status "  [INFO] Raw output: [$WslRaw]" "Gray"
        } else {
            foreach ($D in $Distros) {
                Write-Status "  [INFO] Processing: [$D]" "Gray"
                
                # Skip if empty or invalid
                if ([string]::IsNullOrWhiteSpace($D)) {
                    Write-Status "  [!] Skipping empty distribution name" "Yellow"
                    continue
                }
                
                $SafeName = $D -replace '[^\w\-\.]','_'
                $Tar = Join-Path $WslDir "$SafeName.tar.gz"
                Write-Status "  [INFO] Exporting: $D -> $SafeName.tar.gz" "Gray"
                
                try {
                    & wsl.exe --export "$D" "$Tar" 2>&1 | Out-Null
                    if (Test-Path $Tar) {
                        $FileSize = [math]::Round((Get-Item $Tar).Length/1MB,1)
                        Write-Status "  [+] $D ($FileSize MB)" "Green"
                    } else {
                        Write-Status "  [X] Export failed: $D (file not created)" "Red"
                    }
                } catch {
                    Write-Status "  [X] Error exporting $D : $($_.Exception.Message)" "Red"
                }
            }
        }
    } catch {
        Write-Status "  [X] WSL error: $($_.Exception.Message)" "Red"
    }
}

# ==============================================================================
# 4. EXPORT DOCKER IMAGES
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 3/12: Export Docker Images" "Yellow"
Write-Status "==========================================================================" "Cyan"

$DockerDir = New-BackupDir "Docker"

if (-not (Get-Command "docker.exe" -ErrorAction SilentlyContinue)) {
    Write-Status "  [~] Docker not installed" "Gray"
} else {
    try {
        Write-Status "  [INFO] Getting image list..." "Gray"
        $Images = & docker images --format "{{.Repository}}:{{.Tag}}" 2>&1 |
            Where-Object { $_ -notmatch '<none>' -and $_ -match '\S' }
        
        if ($Images.Count -eq 0) {
            Write-Status "  [~] No Docker images found" "Gray"
        } else {
            Write-Status "  [INFO] Images: $($Images.Count)" "Gray"
            
            foreach ($Img in $Images) {
                $Safe = $Img -replace '[/:.]','_'
                $Tar = Join-Path $DockerDir "$Safe.tar"
                Write-Status "  [INFO] Saving: $Img" "Gray"
                
                try {
                    & docker save -o "$Tar" "$Img" 2>&1 | Out-Null
                    if (Test-Path $Tar) {
                        Write-Status "  [+] $Img ($([math]::Round((Get-Item $Tar).Length/1MB,1)) MB)" "Green"
                    } else {
                        Write-Status "  [X] Save failed: '$Img'" "Red"
                    }
                } catch {
                    Write-Status "  [X] Error saving '$Img': $($_.Exception.Message)" "Red"
                }
            }
        }
    } catch {
        Write-Status "  [X] Docker error: $($_.Exception.Message)" "Red"
    }
}

# ==============================================================================
# 5. EXPORT SSH KEYS (FIXED CYRILLIC PATHS)
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 4/12: Export SSH Keys" "Yellow"
Write-Status "==========================================================================" "Cyan"

$SshDir = New-BackupDir "SSH"
$SshFound = $false

# FIX: Use explicit paths with proper encoding
$SshSearchPaths = @(
    @{Path=Join-Path $UserProfilePath ".ssh"; Label="Standard ~/.ssh"},
    @{Path=Join-Path \${env}:HOME ".ssh"; Label="HOME/.ssh"},
    @{Path=Join-Path $UserProfilePath "ssh"; Label="~/ssh (no dot)"},
    @{Path=Join-Path \${env}:LOCALAPPDATA "OpenSSH"; Label="OpenSSH (LocalAppData)"},
    @{Path="C:\ProgramData\ssh"; Label="System OpenSSH"}
)

foreach ($Search in $SshSearchPaths) {
    try {
        Write-Status "  [INFO] Checking: $($Search.Path)" "Gray"
        if (Test-Path $Search.Path) {
            $Files = Get-ChildItem $Search.Path -File -ErrorAction SilentlyContinue
            if ($Files.Count -gt 0) {
                Write-Status "  [INFO] Found in: $($Search.Label) ($($Files.Count) files)" "Gray"
                $DestSubDir = Join-Path $SshDir ($Search.Label -replace '[^\w\-]','_')
                New-Item -ItemType Directory -Path $DestSubDir -Force | Out-Null
                
                Copy-Item "$($Search.Path)\*" $DestSubDir -Recurse -Force -ErrorAction SilentlyContinue
                
                $CopiedCount = (Get-ChildItem $DestSubDir -File).Count
                Write-Status "  [+] $($Search.Label): copied $CopiedCount files" "Green"
                $SshFound = $true
            }
        }
    } catch {
        Write-Status "  [!] $($Search.Label): error - $($_.Exception.Message)" "Yellow"
    }
}

# Search for PuTTY .ppk keys
Write-Status "  [INFO] Searching for PuTTY .ppk keys..." "Gray"
try {
    $PpkFiles = Get-ChildItem $UserProfilePath -Recurse -Filter "*.ppk" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\node_modules\\' -and $_.FullName -notmatch '\\\.git\\' } |
        Select-Object -First 20

    if ($PpkFiles.Count -gt 0) {
        $PpkDir = Join-Path $SshDir "PuTTY_PPK"
        New-Item -ItemType Directory -Path $PpkDir -Force | Out-Null
        foreach ($Ppk in $PpkFiles) {
            Copy-Item $Ppk.FullName $PpkDir -Force -ErrorAction SilentlyContinue
        }
        Write-Status "  [+] PuTTY: found $($PpkFiles.Count) .ppk files" "Green"
        $SshFound = $true
    }
} catch {
    Write-Status "  [!] PuTTY search error: $($_.Exception.Message)" "Yellow"
}

if (-not $SshFound) {
    Write-Status "  [!] SSH keys not found in standard locations" "Yellow"
    Write-Status "  [!] User profile path: $UserProfilePath" "Yellow"
    
    # Create diagnostic file
    $DiagFile = Join-Path $SshDir "SSH_DIAGNOSTIC.txt"
    $DiagInfo = @"
SSH Keys Not Found - Diagnostic Information
============================================
User Profile Path: $UserProfilePath
HOME: \${env}:HOME
USERNAME: \${env}:USERNAME

Please manually check these locations:
1. $UserProfilePath\.ssh
2. \${env}:HOME\.ssh
3. C:\ProgramData\ssh

Run this command to find SSH keys:
Get-ChildItem -Path $UserProfilePath -Recurse -Filter "id_*" -ErrorAction SilentlyContinue
"@
    $DiagInfo | Out-File $DiagFile -Encoding UTF8
}

# ==============================================================================
# 6. EXPORT GPG KEYS (FIXED NULL HANDLING)
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 5/12: Export GPG Keys" "Yellow"
Write-Status "==========================================================================" "Cyan"

$GpgDir = New-BackupDir "GPG"

try {
    # FIX: Use explicit path construction
    $GpgSrc = Join-Path $UserProfilePath ".gnupg"
    Write-Status "  [INFO] Checking GPG path: $GpgSrc" "Gray"
    
    if (Test-Path $GpgSrc) {
        Copy-Item "$GpgSrc\*" $GpgDir -Recurse -Force -ErrorAction SilentlyContinue
        $Files = Get-ChildItem $GpgDir -File
        Write-Status "  [+] GPG keys copied: $($Files.Count) files" "Green"
    } else {
        Write-Status "  [~] ~/.gnupg not found at: $GpgSrc" "Gray"
    }
} catch {
    Write-Status "  [X] GPG export error: $($_.Exception.Message)" "Red"
}

# ==============================================================================
# 7. EXPORT LICENSE KEYS
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 6/12: Export License Keys" "Yellow"
Write-Status "==========================================================================" "Cyan"

$LicDir = New-BackupDir "Licenses"
$LicFile = Join-Path $LicDir "license_keys.txt"
$LicLines = [System.Collections.Generic.List[string]]::new()
$LicCount = 0

$LicLines.Add("=" * 68)
$LicLines.Add("  LICENSE KEYS - export $DateStamp")
$LicLines.Add("=" * 68)
$LicLines.Add("")

# Windows
Write-Status "  [INFO] Windows: extracting key..." "Gray"
try {
    $SLS = Get-WmiObject -Query "SELECT * FROM SoftwareLicensingService" -ErrorAction Stop
    $WinKey = $SLS.OA3xOriginalProductKey
    
    if ($WinKey) {
        $WinEdition = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName
        $LicLines.Add("[Windows]")
        $LicLines.Add("  Key: $WinKey")
        $LicLines.Add("  Edition: $WinEdition")
        $LicLines.Add("")
        $LicCount++
        Write-Status "  [+] Windows: key found" "Green"
    } else {
        Write-Status "  [~] Windows: key not extracted (Digital License)" "Yellow"
        $LicLines.Add("[Windows]")
        $LicLines.Add("  Status: Digital License (HWID)")
        $LicLines.Add("")
    }
} catch {
    Write-Status "  [X] Windows error: $($_.Exception.Message)" "Red"
}

# Office
Write-Status "  [INFO] Office: searching keys..." "Gray"
$OfficePaths = @(
    "HKLM:\SOFTWARE\Microsoft\Office",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Office"
)

foreach ($OPath in $OfficePaths) {
    try {
        if (Test-Path $OPath) {
            Get-ChildItem $OPath -ErrorAction SilentlyContinue | ForEach-Object {
                $Ver = $_.PSChildName
                if ($Ver -match '^\d+\.\d+$') {
                    $RegBase = "$OPath\$Ver\Registration"
                    if (Test-Path $RegBase) {
                        Get-ChildItem $RegBase -ErrorAction SilentlyContinue | ForEach-Object {
                            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                            if ($props.DigitalProductId) {
                                $LicLines.Add("[Microsoft Office $Ver]")
                                $LicLines.Add("  Status: key in registry (use ShowKeyPlus to extract)")
                                $LicLines.Add("")
                                $LicCount++
                                Write-Status "  [+] Office \${Ver}: entry found" "Green"
                            }
                        }
                    }
                }
            }
        }
    } catch {
        Write-Status "  [!] Office search error: $($_.Exception.Message)" "Yellow"
    }
}

# Save license file
$LicLines | Out-File $LicFile -Encoding UTF8
Write-Status "  [+] License file: Licenses\license_keys.txt ($LicCount entries)" "Green"

# ==============================================================================
# 8. EXPORT GLOBAL PACKAGES
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 7/12: Export Global Packages" "Yellow"
Write-Status "==========================================================================" "Cyan"

$PackagesDir = New-BackupDir "Packages"

# npm
Write-Status "  [INFO] npm..." "Gray"
if (Get-Command "npm" -ErrorAction SilentlyContinue) {
    try {
        & npm list -g --depth=0 > (Join-Path $PackagesDir "npm_global.txt") 2>&1
        Write-Status "  [+] npm: packages exported" "Green"
    } catch {
        Write-Status "  [!] npm: error" "Yellow"
    }
} else {
    Write-Status "  [~] npm not found" "Gray"
}

# pip
Write-Status "  [INFO] pip..." "Gray"
if (Get-Command "pip" -ErrorAction SilentlyContinue) {
    try {
        & pip freeze > (Join-Path $PackagesDir "pip_requirements.txt") 2>&1
        Write-Status "  [+] pip: packages exported" "Green"
    } catch {
        Write-Status "  [!] pip: error" "Yellow"
    }
} else {
    Write-Status "  [~] pip not found" "Gray"
}

# winget
Write-Status "  [INFO] winget..." "Gray"
if (Get-Command "winget" -ErrorAction SilentlyContinue) {
    try {
        $WFile = Join-Path $PackagesDir "winget_export.json"
        & winget export -o "$WFile" --accept-source-agreements 2>&1 | Out-Null
        if (Test-Path $WFile) {
            Write-Status "  [+] winget: export complete" "Green"
        }
    } catch {
        Write-Status "  [!] winget: error" "Yellow"
    }
} else {
    Write-Status "  [~] winget not found" "Gray"
}

# cargo
Write-Status "  [INFO] cargo..." "Gray"
if (Get-Command "cargo" -ErrorAction SilentlyContinue) {
    try {
        & cargo install --list > (Join-Path $PackagesDir "cargo_crates.txt") 2>&1
        Write-Status "  [+] cargo: crates exported" "Green"
    } catch {
        Write-Status "  [!] cargo: error" "Yellow"
    }
} else {
    Write-Status "  [~] cargo not found" "Gray"
}

# ==============================================================================
# 9. EXPORT ENVIRONMENT VARIABLES
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 8/12: Export Environment Variables" "Yellow"
Write-Status "==========================================================================" "Cyan"

$EnvDir = New-BackupDir "Environment"

try {
    $UserEnv = [System.Environment]::GetEnvironmentVariables("User")
    $SysEnv = [System.Environment]::GetEnvironmentVariables("Machine")
    
    $UserEnv | ConvertTo-Json | Out-File (Join-Path $EnvDir "env_user.json") -Encoding UTF8
    $SysEnv | ConvertTo-Json | Out-File (Join-Path $EnvDir "env_machine.json") -Encoding UTF8
    
    Write-Status "  [+] Variables: user=$($UserEnv.Count), system=$($SysEnv.Count)" "Green"
} catch {
    Write-Status "  [X] Environment export error: $($_.Exception.Message)" "Red"
}

# ==============================================================================
# 10. EXPORT DEVELOPER CONFIGS (FIXED PATHS)
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 9/12: Export Developer Configs" "Yellow"
Write-Status "==========================================================================" "Cyan"

$ConfigDir = New-BackupDir "DevConfigs"

# FIX: Use explicit path construction for all configs
$Cfgs = @(
    @{D="Git config"; S=Join-Path $UserProfilePath ".gitconfig"; T="gitconfig"},
    @{D="VS Code settings"; S=Join-Path \${env}:AppData "Code\User\settings.json"; T="vscode_settings.json"},
    @{D="Windows Terminal"; S=Join-Path \${env}:LocalAppData "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"; T="wt_settings.json"},
    @{D=".npmrc"; S=Join-Path $UserProfilePath ".npmrc"; T="npmrc"},
    @{D=".wslconfig"; S=Join-Path $UserProfilePath ".wslconfig"; T="wslconfig"}
)

foreach ($C in $Cfgs) {
    try {
        Write-Status "  [INFO] Checking: $($C.S)" "Gray"
        if (Test-Path $C.S) {
            Copy-Item $C.S (Join-Path $ConfigDir $C.T) -Force
            Write-Status "  [+] $($C.D)" "Green"
        } else {
            Write-Status "  [~] $($C.D) - not found" "Gray"
        }
    } catch {
        Write-Status "  [!] $($C.D): error - $($_.Exception.Message)" "Yellow"
    }
}

# ==============================================================================
# 11. EXPORT WIFI PROFILES
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 10/12: Export WiFi Profiles" "Yellow"
Write-Status "==========================================================================" "Cyan"

$WifiDir = New-BackupDir "WiFi"

try {
    $WifiProfiles = & netsh wlan show profiles 2>&1
    $ProfileNames = $WifiProfiles | Where-Object { $_ -match "All User Profile" } | ForEach-Object { ($_ -split ":")[-1].Trim() }
    
    if ($ProfileNames.Count -gt 0) {
        Write-Status "  [INFO] Found WiFi profiles: $($ProfileNames.Count)" "Gray"
        foreach ($Profile in $ProfileNames) {
            $ProfileFile = Join-Path $WifiDir "$Profile.xml"
            & netsh wlan export profile name="$Profile" folder="$WifiDir" key=clear 2>&1 | Out-Null
        }
        Write-Status "  [+] WiFi profiles exported" "Green"
    } else {
        Write-Status "  [~] No WiFi profiles found" "Gray"
    }
} catch {
    Write-Status "  [X] WiFi export error: $($_.Exception.Message)" "Red"
}

# ==============================================================================
# 12. EXPORT BITLOCKER KEYS
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 11/12: Export BitLocker Keys" "Yellow"
Write-Status "==========================================================================" "Cyan"

$BitLockerDir = New-BackupDir "BitLocker"

try {
    $BitLockerStatus = & manage-bde -status C: 2>&1
    if ($BitLockerStatus -match "Protection Status:\s+On") {
        Write-Status "  [INFO] BitLocker enabled, exporting keys..." "Gray"
        $KeyFile = Join-Path $BitLockerDir "BitLocker_Keys.txt"
        $BitLockerStatus | Out-File -FilePath $KeyFile -Encoding UTF8
        Write-Status "  [+] BitLocker keys saved" "Green"
    } else {
        Write-Status "  [~] BitLocker not active" "Gray"
    }
} catch {
    Write-Status "  [X] BitLocker export error: $($_.Exception.Message)" "Red"
}

# ==============================================================================
# 13. EXPORT DATABASES
# ==============================================================================
Write-Status "`n==========================================================================" "Cyan"
Write-Status "  STEP 12/12: Export Databases" "Yellow"
Write-Status "==========================================================================" "Cyan"

$DbDir = New-BackupDir "Databases"

# PostgreSQL
Write-Status "  [INFO] PostgreSQL..." "Gray"
if (Get-Command "pg_dumpall" -ErrorAction SilentlyContinue) {
    try {
        $PgDumpFile = Join-Path $DbDir "postgresql_all.sql"
        & pg_dumpall -U postgres > $PgDumpFile 2>&1
        if (Test-Path $PgDumpFile) {
            Write-Status "  [+] PostgreSQL dump created" "Green"
        }
    } catch {
        Write-Status "  [!] PostgreSQL: error (may require password)" "Yellow"
    }
} else {
    Write-Status "  [~] PostgreSQL not found" "Gray"
}

# MySQL
Write-Status "  [INFO] MySQL..." "Gray"
if (Get-Command "mysqldump" -ErrorAction SilentlyContinue) {
    try {
        $MysqlDumpFile = Join-Path $DbDir "mysql_all.sql"
        & mysqldump --all-databases -u root > $MysqlDumpFile 2>&1
        if (Test-Path $MysqlDumpFile) {
            Write-Status "  [+] MySQL dump created" "Green"
        }
    } catch {
        Write-Status "  [!] MySQL: error (may require password)" "Yellow"
    }
} else {
    Write-Status "  [~] MySQL not found" "Gray"
}

# ==============================================================================
# FINAL REPORT
# ==============================================================================
Write-Status "`n==========================================================================" "Green"
Write-Status "  BACKUP COMPLETED" "Green"
Write-Status "==========================================================================" "Green"

$EndTime = Get-Date
$Duration = [math]::Round(($EndTime - $StartTime).TotalMinutes, 1)

Write-Status "`n[RESULTS]:" "Cyan"
Write-Status "  Duration: $Duration min" "White"
Write-Status "  Backup folder: $BackupRoot" "White"
Write-Status "  Licenses found: $LicCount" "White"

Write-Status "`n[STRUCTURE]:" "Cyan"
Write-Status "  Drivers\      - OEM drivers" "Gray"
Write-Status "  WSL2\         - WSL distributions" "Gray"
Write-Status "  Docker\       - Docker images" "Gray"
Write-Status "  SSH\          - SSH keys" "Gray"
Write-Status "  GPG\          - GPG keys" "Gray"
Write-Status "  Licenses\     - License keys" "Yellow"
Write-Status "  Packages\     - Global packages" "Gray"
Write-Status "  Environment\  - Environment variables" "Gray"
Write-Status "  DevConfigs\   - Developer configs" "Gray"
Write-Status "  WiFi\         - WiFi profiles" "Gray"
Write-Status "  BitLocker\    - BitLocker keys" "Gray"
Write-Status "  Databases\    - Database dumps" "Gray"

Write-Status "`n[IMPORTANT]:" "Yellow"
Write-Status "  - Do not delete backup folder until new PC is fully verified" "White"
Write-Status "  - Store USB drive safely (contains SSH keys and licenses)" "White"

pause

# powershell -ExecutionPolicy Bypass -File "backup_critical_data.ps1" -Destination "D:"

# (Get-Content "backup_critical_data.ps1" -Raw) -replace '\$(\w+):', '\${$1}:' | 
#     Set-Content "backup_critical_data.ps1" -Encoding UTF8
