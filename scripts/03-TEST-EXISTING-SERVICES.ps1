$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host ".env created from .env.example." -ForegroundColor Yellow
    Write-Host "Edit PostgreSQL/Redis/Qdrant credentials before continuing." -ForegroundColor Yellow
}

$cfg=@{}
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') { $cfg[$matches[1]]=$matches[2] }
}

function Test-Port($label,$hostName,$port) {
    if ($hostName -eq "host.docker.internal") { $hostName="127.0.0.1" }
    $ok = Test-NetConnection -ComputerName $hostName -Port ([int]$port) -InformationLevel Quiet
    if ($ok) { Write-Host "[OK] $label $hostName`:$port" -ForegroundColor Green }
    else { Write-Host "[FAIL] $label $hostName`:$port" -ForegroundColor Red }
}

Test-Port "PostgreSQL" $cfg["POSTGRES_HOST"] $cfg["POSTGRES_PORT"]
Test-Port "Redis" $cfg["REDIS_HOST"] $cfg["REDIS_PORT"]
Test-Port "Qdrant" $cfg["QDRANT_HOST"] $cfg["QDRANT_PORT"]

try {
    $qhost=$cfg["QDRANT_HOST"]
    if ($qhost -eq "host.docker.internal") {$qhost="127.0.0.1"}
    $headers=@{}
    if ($cfg["QDRANT_API_KEY"]) {$headers["api-key"]=$cfg["QDRANT_API_KEY"]}
    Invoke-RestMethod "http://$qhost`:$($cfg['QDRANT_PORT'])/collections" -Headers $headers -TimeoutSec 5 | Out-Null
    Write-Host "[OK] Qdrant REST API" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Qdrant port may be open but REST API test failed: $($_.Exception.Message)" -ForegroundColor Yellow
}
