$r=Split-Path -Parent $PSScriptRoot; Set-Location $r; docker compose up -d; docker compose ps
