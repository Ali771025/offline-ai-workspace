$ErrorActionPreference = "Stop"
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $admin) { throw "Run PowerShell as Administrator." }

[Environment]::SetEnvironmentVariable("OLLAMA_HOST","0.0.0.0:11434","Machine")

$name="Offline AI Hub - Ollama 11434 Private"
Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName $name -Direction Inbound -Protocol TCP -LocalPort 11434 -Action Allow -Profile Private | Out-Null

Write-Host "[OK] OLLAMA_HOST=0.0.0.0:11434" -ForegroundColor Green
Write-Host "[OK] Firewall opened on Private network only." -ForegroundColor Green
Write-Host "Exit Ollama completely and start it again." -ForegroundColor Yellow
