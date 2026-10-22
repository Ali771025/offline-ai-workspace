$ErrorActionPreference="Continue"
$r=Split-Path -Parent $PSScriptRoot
Set-Location $r
docker compose ps

$tests=@(
 @{n="Ollama";u="http://127.0.0.1:11434/api/tags"},
 @{n="Open WebUI";u="http://127.0.0.1:3000"},
 @{n="LiteLLM";u="http://127.0.0.1:4000/health"},
 @{n="Forgejo";u="http://127.0.0.1:3001"},
 @{n="Gateway";u="http://127.0.0.1:8080"}
)
foreach($t in $tests){
 try {
   $x=Invoke-WebRequest -UseBasicParsing -Uri $t.u -TimeoutSec 8
   Write-Host "[OK] $($t.n) HTTP $($x.StatusCode)" -ForegroundColor Green
 } catch {
   Write-Host "[FAIL] $($t.n): $($_.Exception.Message)" -ForegroundColor Red
 }
}
& "$PSScriptRoot\03-TEST-EXISTING-SERVICES.ps1"
