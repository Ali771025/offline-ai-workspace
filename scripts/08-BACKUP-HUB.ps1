$ErrorActionPreference="Stop"
$r=Split-Path -Parent $PSScriptRoot
Set-Location $r
$s=Get-Date -Format "yyyyMMdd-HHmmss"
$d=Join-Path $r "backups\$s"
New-Item -ItemType Directory -Force -Path $d | Out-Null

docker compose stop

$vols=docker volume ls --format "{{.Name}}" | Where-Object {$_ -like "offline-ai-hub_*"}
foreach($v in $vols){
  $name=$v.Replace("offline-ai-hub_","")+".tar.gz"
  docker run --rm -v "${v}:/source:ro" -v "${d}:/backup" alpine:3.23 `
      sh -c "cd /source && tar czf /backup/$name ."
}
Copy-Item ".env" $d -ErrorAction SilentlyContinue
Copy-Item "docker-compose.yml" $d
Copy-Item "config" $d -Recurse
docker compose start

Write-Host "NOTE: Existing PostgreSQL/Redis/Qdrant data is not backed up by this script." -ForegroundColor Yellow
Write-Host "AI Hub backup: $d" -ForegroundColor Green
