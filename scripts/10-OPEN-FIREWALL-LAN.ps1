$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw "Run PowerShell as Administrator." }

foreach($p in @(3000,3001,4000,8080,2222)){
 $n="Offline AI Hub - TCP $p Private"
 Get-NetFirewallRule -DisplayName $n -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
 New-NetFirewallRule -DisplayName $n -Direction Inbound -Protocol TCP -LocalPort $p -Action Allow -Profile Private | Out-Null
 Write-Host "[OK] LAN TCP $p" -ForegroundColor Green
}

Write-Host "PostgreSQL/Redis/Qdrant firewall rules are NOT changed by this pack." -ForegroundColor Yellow
