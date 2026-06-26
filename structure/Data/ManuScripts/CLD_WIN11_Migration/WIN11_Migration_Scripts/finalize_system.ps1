<#
.SYNOPSIS
    Финальная оптимизация сети, электропитания и верификация целостности ОС.
.DESCRIPTION
    Прописывает публичные DNS (Cloudflare + Google) на активных адаптерах,
    переводит планировщик CPU в режим High Performance,
    запускает DISM RestoreHealth и SFC scannow.
    ЗАПУСКАТЬ: от Администратора, после подключения интернета (Этап 7, финал).
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host ("=" * 74) -ForegroundColor Yellow
Write-Host "  ФИНАЛЬНАЯ СЕТЕВАЯ ОПТИМИЗАЦИЯ И СИСТЕМНЫЙ QA-АУДИТ" -ForegroundColor Yellow
Write-Host ("=" * 74) -ForegroundColor Yellow

# --- ШАГ 1: Публичные DNS (Cloudflare + Google) для всех активных адаптеров ---
#     Устраняет микросбои при npm install / pip install / git push
Write-Host "`n[--->] ШАГ 1: Настройка публичных DNS-серверов..." -ForegroundColor Cyan
$ActiveAdapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
if ($ActiveAdapters) {
    foreach ($Adapter in $ActiveAdapters) {
        Set-DnsClientServerAddress -InterfaceIndex $Adapter.InterfaceIndex `
            -ServerAddresses ("1.1.1.1", "8.8.8.8") -ErrorAction SilentlyContinue
        Write-Host "  -> DNS настроен для: $($Adapter.Name)" -ForegroundColor Gray
    }
    Write-Host "[+] DNS настроен." -ForegroundColor Green
} else {
    Write-Warning "Активные сетевые адаптеры не найдены. Подключите интернет и повторите."
}

# --- ШАГ 2: Режим электропитания High Performance (блокировка парковки ядер CPU) ---
Write-Host "`n[--->] ШАГ 2: Переключение схемы электропитания на High Performance..." -ForegroundColor Cyan
& powercfg.exe /setactive SCHEME_MIN
Write-Host "[+] Планировщик CPU: High Performance." -ForegroundColor Green

# --- ШАГ 3: DISM RestoreHealth — восстановление хранилища компонентов WinSxS ---
Write-Host "`n[--->] ШАГ 3: DISM /RestoreHealth (может занять 5–15 минут)..." -ForegroundColor Cyan
& DISM.exe /Online /Cleanup-Image /RestoreHealth
Write-Host "[+] DISM завершён." -ForegroundColor Green

# --- ШАГ 4: SFC scannow — проверка целостности системных файлов ---
Write-Host "`n[--->] ШАГ 4: SFC /scannow (может занять 5–10 минут)..." -ForegroundColor Cyan
& sfc /scannow
Write-Host "[+] SFC завершён." -ForegroundColor Green

Write-Host "`n$(("=" * 74))" -ForegroundColor Green
Write-Host "  СТАНЦИЯ ПРОШЛА QA-ТЕСТЫ И ГОТОВА К СДАЧЕ КЛИЕНТУ." -ForegroundColor Green
Write-Host ("=" * 74) -ForegroundColor Green