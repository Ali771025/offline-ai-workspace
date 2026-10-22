$Root=Split-Path -Parent $PSScriptRoot
$dir="$Root\backups\redis"
$archive="$dir\redis-data.tar.gz"
if (-not (Test-Path $archive)) {throw "Redis backup archive not found."}
docker stop ai-redis | Out-Null
docker run --rm -v offline-ai-hub-full_redis_data:/target -v "${dir}:/backup" alpine:3.23 sh -c "rm -rf /target/* && tar xzf /backup/redis-data.tar.gz -C /target"
docker start ai-redis | Out-Null
