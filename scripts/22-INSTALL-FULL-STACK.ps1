$ErrorActionPreference="Stop"
$Root=Split-Path -Parent $PSScriptRoot
Set-Location $Root
if (-not (Test-Path ".env")) {Copy-Item ".env.example" ".env"}

$txt=Get-Content ".env" -Raw
if (Test-Path "detected-images.env") {
  $det=@{}
  Get-Content "detected-images.env" | ForEach-Object {
    if ($_ -match '^\s*([^=]+)=(.*)$') {$det[$matches[1]]=$matches[2]}
  }
  foreach($key in @("POSTGRES_IMAGE","REDIS_IMAGE","QDRANT_IMAGE")) {
    if ($det[$key]) {$txt=$txt -replace "(?m)^$key=.*$","$key=$($det[$key])"}
  }
}
Set-Content ".env" $txt -Encoding UTF8

if ($txt -match 'POSTGRES_PASSWORD=CHANGE_ME') {
  Write-Host "Edit .env and set POSTGRES_PASSWORD first." -ForegroundColor Red
  exit 2
}

docker compose -f docker-compose.full.yml up -d
docker compose -f docker-compose.full.yml ps
