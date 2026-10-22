$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env")) { throw "Server .env not found." }

$c=@{}
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {$c[$matches[1]]=$matches[2]}
}

$clientDir=Join-Path $root "client-pack"
$server=$c["SERVER_IP"]
$key=$c["LITELLM_MASTER_KEY"]

@"
SERVER_IP=$server
OPENWEBUI_URL=http://$server`:3000
LITELLM_BASE_URL=http://$server`:4000/v1
OLLAMA_BASE_URL=http://$server`:11434
FORGEJO_URL=http://$server`:3001
FORGEJO_SSH_PORT=2222
LITELLM_API_KEY=$key
DEFAULT_CHAT_MODEL=qwen-local
DEFAULT_OLLAMA_MODEL=qwen3:8b
DEFAULT_EMBED_MODEL=embedding-local
"@ | Set-Content (Join-Path $clientDir ".env") -Encoding UTF8

Write-Host "[OK] client-pack\.env generated." -ForegroundColor Green
Write-Host "Copy only the client-pack folder to authorized PCs." -ForegroundColor Cyan
