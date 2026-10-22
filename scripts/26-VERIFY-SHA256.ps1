$ErrorActionPreference="Stop"
$Root=Split-Path -Parent $PSScriptRoot
$sum="$Root\SHA256SUMS.txt"
if (-not (Test-Path $sum)) {throw "SHA256SUMS.txt not found."}
$failed=0
Get-Content $sum | ForEach-Object {
  if ($_ -match '^([A-Fa-f0-9]{64})\s+(.+)$') {
    $expected=$matches[1].ToUpper()
    $path=Join-Path $Root $matches[2]
    if (-not (Test-Path $path)) {$failed++; Write-Host "[MISSING] $($matches[2])" -ForegroundColor Red}
    else {
      $actual=(Get-FileHash $path -Algorithm SHA256).Hash.ToUpper()
      if ($actual -ne $expected) {$failed++; Write-Host "[FAIL] $($matches[2])" -ForegroundColor Red}
      else {Write-Host "[OK] $($matches[2])" -ForegroundColor Green}
    }
  }
}
if ($failed -gt 0) {throw "$failed verification errors."}
