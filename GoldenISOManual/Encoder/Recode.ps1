$script = @'
<#
.SYNOPSIS
    Универсальный перекодировщик файлов для блока 03A.
.DESCRIPTION
    Применяется ТОЛЬКО если файлы были созданы вручную через Блокнот (не через PowerShell).
    Если файлы созданы через here-string + WriteAllText — этот скрипт не нужен.
.NOTES
    Кодировка: UTF-8 с BOM (гарантирована при создании).
#>

# ==============================================================================
# CONFIG - НАСТРОЙКИ ПЕРЕКОДИРОВАНИЯ
# ==============================================================================

# --- ЦЕЛЕВАЯ КОДИРОВКА (выберите ОДНУ) ---
$TARGET_ENCODING = 'UTF8-BOM'          # UTF-8 с BOM (для .ps1 и .psd1)
# $TARGET_ENCODING = 'UTF8-NOBOM'      # UTF-8 без BOM (для .json, .txt)
# $TARGET_ENCODING = 'ANSI'            # Windows-1251 (для .cmd)

# --- ИСХОДНАЯ КОДИРОВКА ---
$SOURCE_ENCODING = 'AUTO'

# --- ФАЙЛЫ ДЛЯ ПЕРЕКОДИРОВАНИЯ ---
$FILES = @(
    'Apply.ps1',
    'Verify.ps1',
    'Rollback.ps1',
    'Config.psd1'
)

# ==============================================================================
# ЛОГИКА (не редактировать)
# ==============================================================================

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

if ($MyInvocation.MyCommand.Definition) {
    $ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
} else {
    $ScriptPath = $PWD.Path
}

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  ПЕРЕКОДИРОВЩИК ФАЙЛОВ БЛОКА 03A" -ForegroundColor Cyan
Write-Host "========================================================================`n" -ForegroundColor Cyan

Write-Host "[INFO] Целевая кодировка: ${TARGET_ENCODING}" -ForegroundColor Yellow
Write-Host "[INFO] Файлов в списке: $($FILES.Count)`n" -ForegroundColor Yellow

function Get-Encoding {
    param([string]$Name)
    switch ($Name.ToUpper()) {
        'UTF8-BOM'    { return [System.Text.UTF8Encoding]::new($true) }
        'UTF8-NOBOM'  { return [System.Text.UTF8Encoding]::new($false) }
        'ANSI'        { return [System.Text.Encoding]::Default }
        default       { throw "Неизвестная кодировка: $Name" }
    }
}

function Get-SourceEncoding {
    param([string]$FilePath)
    $bytes = [System.IO.File]::ReadAllBytes($FilePath)
    if ($bytes.Length -lt 3) { return [System.Text.Encoding]::UTF8 }
    
    if ($bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        Write-Host "  [AUTO] Обнаружен UTF-8 BOM" -ForegroundColor Gray
        return [System.Text.UTF8Encoding]::new($true)
    }
    
    Write-Host "  [AUTO] BOM не обнаружен, предполагаем UTF-8 без BOM" -ForegroundColor Gray
    return [System.Text.UTF8Encoding]::new($false)
}

$targetEnc = Get-Encoding $TARGET_ENCODING
$sourceEnc = if ($SOURCE_ENCODING -eq 'AUTO') { $null } else { Get-Encoding $SOURCE_ENCODING }

$successCount = 0; $skipCount = 0; $failCount = 0

foreach ($fileRel in $FILES) {
    if ([System.IO.Path]::IsPathRooted($fileRel)) {
        $filePath = $fileRel
    } else {
        $filePath = Join-Path $ScriptPath $fileRel
    }
    
    Write-Host "Обработка: $filePath" -ForegroundColor White
    
    if (-not (Test-Path $filePath)) {
        Write-Host "  [SKIP] Файл не найден" -ForegroundColor DarkYellow
        $skipCount++
        continue
    }
    
    try {
        $enc = if ($sourceEnc) { $sourceEnc } else { Get-SourceEncoding $filePath }
        $content = [System.IO.File]::ReadAllText($filePath, $enc)
        [System.IO.File]::WriteAllText($filePath, $content, $targetEnc)
        
        Write-Host "  [OK] Перекодировано в ${TARGET_ENCODING}" -ForegroundColor Green
        $successCount++
    }
    catch {
        Write-Host "  [FAIL] Ошибка: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}

Write-Host "`n========================================================================" -ForegroundColor Cyan
Write-Host "  ИТОГ: Успешно=$successCount | Пропущено=$skipCount | Ошибок=$failCount" -ForegroundColor White
Write-Host "========================================================================`n" -ForegroundColor Cyan

if ($failCount -eq 0) {
    Write-Host "[+] Все файлы перекодированы успешно." -ForegroundColor Green
} else {
    Write-Host "[!] Есть ошибки. Проверьте файлы и пути." -ForegroundColor Red
}

pause
'@

$utf8Bom = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$PWD\Recode.ps1", $script, $utf8Bom)

Write-Host "[+] Файл Recode.ps1 создан в кодировке UTF-8 с BOM" -ForegroundColor Green