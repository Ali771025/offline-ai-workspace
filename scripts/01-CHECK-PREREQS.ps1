$ErrorActionPreference = "Stop"
Write-Host "=== Offline AI Hub v2 prerequisite check ===" -ForegroundColor Cyan

foreach ($cmd in @("docker","ollama")) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) {
        Write-Host "[OK] $cmd" -ForegroundColor Green
    } else {
        Write-Host "[MISSING] $cmd" -ForegroundColor Red
        exit 1
    }
}

docker version | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Docker Desktop engine is not running." }

try {
    Invoke-RestMethod "http://127.0.0.1:11434/api/tags" -TimeoutSec 5 | Out-Null
    Write-Host "[OK] Ollama API" -ForegroundColor Green
} catch {
    Write-Host "[WARN] Ollama API is not reachable on 11434." -ForegroundColor Yellow
}

Write-Host "`nDetected IPv4 addresses:" -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object {$_.IPAddress -ne "127.0.0.1" -and $_.IPAddress -notlike "169.254*"} |
  Select-Object InterfaceAlias,IPAddress |
  Format-Table -AutoSize
