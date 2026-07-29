# ============================================================
# Web projesindeki kelime verisini iOS projesine taşır.
#
# Kelime listesinin TEK kaynağı web projesidir. Burada elle düzenleme
# yapmayın: bir sonraki eşitlemede değişiklik sessizce kaybolur.
#
# Kullanım (PowerShell, bu klasörde):
#     .\tools\sync_web_data.ps1
#
# Yeni kelime eklemek istediğinizde sıra şu:
#   1. C:\Kelime_Ezberle\src\words_*.json içine ekleyin
#   2. Web projesinde derle.bat çalıştırıp testlerin geçtiğini görün
#   3. Burada bu betiği çalıştırın
#   4. Değişikliği işleyip (commit) etiketleyin — CI derlemeyi başlatır
# ============================================================

$ErrorActionPreference = 'Stop'

$WebSource = 'C:\Kelime_Ezberle\src'
$Root = Split-Path -Parent $PSScriptRoot
$RawDir = Join-Path $Root 'tools\rawdata'

if (-not (Test-Path $WebSource)) {
    Write-Error "Web projesi bulunamadı: $WebSource`nYol değiştiyse betiğin başındaki `$WebSource satırını güncelleyin."
}

New-Item -ItemType Directory -Force -Path $RawDir | Out-Null

$patterns = @('words_*.json', 'phrasals_*.json', 'examples2_*.json', 'irregular.json')
$copied = 0
foreach ($pattern in $patterns) {
    Get-ChildItem -Path (Join-Path $WebSource $pattern) | ForEach-Object {
        Copy-Item $_.FullName -Destination $RawDir -Force
        $copied++
    }
}
Write-Host "$copied dosya kopyalandı." -ForegroundColor Green

Push-Location $Root
try {
    python tools/prepare_data.py
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Veri doğrulaması başarısız. Yukarıdaki hataları web projesinde düzeltip tekrar deneyin."
    }
    Write-Host "`nResources/Data/deck.json güncellendi." -ForegroundColor Green
    Write-Host "Şimdi: git add Resources/Data/deck.json && git commit" -ForegroundColor Cyan
} finally {
    Pop-Location
}
