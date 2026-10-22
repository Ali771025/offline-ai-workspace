$Root=Split-Path -Parent $PSScriptRoot
$sql="$Root\backups\postgres\postgres-all.sql"
if (-not (Test-Path $sql)) {throw "Backup not found."}
$user=Read-Host "Target PostgreSQL user (default postgres)"
if (-not $user) {$user="postgres"}
Get-Content $sql -Raw | docker exec -i ai-postgres psql -U $user
