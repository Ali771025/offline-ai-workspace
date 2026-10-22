$ErrorActionPreference="Stop"
$Root=Split-Path -Parent $PSScriptRoot
Get-ChildItem "$Root\docker-images" -Recurse -Filter *.tar | ForEach-Object {
  Write-Host "Loading $($_.Name)" -ForegroundColor Cyan
  docker load -i $_.FullName
  if ($LASTEXITCODE -ne 0) {throw "docker load failed: $($_.Name)"}
}
Write-Host "[OK] All Docker images loaded." -ForegroundColor Green
