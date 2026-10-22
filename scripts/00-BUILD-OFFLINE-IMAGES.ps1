$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$imagesDir = Join-Path $root "offline-images"
$listFile = Join-Path $root "images.txt"
New-Item -ItemType Directory -Force -Path $imagesDir | Out-Null

$images = Get-Content $listFile | Where-Object { $_.Trim() -ne "" }

Write-Host "Only AI Hub images will be downloaded." -ForegroundColor Cyan
Write-Host "PostgreSQL, Redis and Qdrant are intentionally excluded." -ForegroundColor Yellow

foreach ($img in $images) {
    Write-Host "`nPulling $img ..." -ForegroundColor Cyan
    docker pull $img
    if ($LASTEXITCODE -ne 0) { throw "docker pull failed: $img" }

    $safe = $img.Replace("/", "_").Replace(":", "__")
    $dest = Join-Path $imagesDir "$safe.tar"
    docker save -o $dest $img
    if ($LASTEXITCODE -ne 0) { throw "docker save failed: $img" }
}

$sumFile = Join-Path $imagesDir "SHA256SUMS.txt"
Remove-Item $sumFile -ErrorAction SilentlyContinue
Get-ChildItem $imagesDir -Filter *.tar | ForEach-Object {
    $h = Get-FileHash $_.FullName -Algorithm SHA256
    "$($h.Hash)  $($_.Name)" | Add-Content $sumFile
}
Write-Host "`n[DONE] Offline bundle created." -ForegroundColor Green
