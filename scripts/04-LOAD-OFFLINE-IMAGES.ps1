$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
$dir=Join-Path $root "offline-images"
$files=Get-ChildItem $dir -Filter *.tar -ErrorAction SilentlyContinue
if (-not $files) { throw "No .tar images found. Run 00-BUILD-OFFLINE-IMAGES.ps1 on an online PC." }

$sum=Join-Path $dir "SHA256SUMS.txt"
if (Test-Path $sum) {
    $expected=@{}
    Get-Content $sum | ForEach-Object {
        if ($_ -match '^([A-Fa-f0-9]{64})\s+(.+)$') {$expected[$matches[2]]=$matches[1].ToUpper()}
    }
    foreach ($f in $files) {
        if ($expected.ContainsKey($f.Name)) {
            $actual=(Get-FileHash $f.FullName -Algorithm SHA256).Hash.ToUpper()
            if ($actual -ne $expected[$f.Name]) { throw "SHA256 mismatch: $($f.Name)" }
        }
    }
    Write-Host "[OK] SHA256 verification passed." -ForegroundColor Green
}

foreach ($f in $files) {
    docker load -i $f.FullName
    if ($LASTEXITCODE -ne 0) { throw "docker load failed: $($f.Name)" }
}
Write-Host "[DONE] All AI Hub images loaded." -ForegroundColor Green
