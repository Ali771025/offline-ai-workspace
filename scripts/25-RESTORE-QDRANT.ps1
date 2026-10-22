$Root=Split-Path -Parent $PSScriptRoot
$dir="$Root\backups\qdrant"
$archive="$dir\qdrant-storage.tar.gz"
if (-not (Test-Path $archive)) {throw "Qdrant backup archive not found."}
docker stop ai-qdrant | Out-Null
docker run --rm -v offline-ai-hub-full_qdrant_data:/target -v "${dir}:/backup" alpine:3.23 sh -c "rm -rf /target/* && tar xzf /backup/qdrant-storage.tar.gz -C /target"
docker start ai-qdrant | Out-Null
