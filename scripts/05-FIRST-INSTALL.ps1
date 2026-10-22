$ErrorActionPreference="Stop"
$root=Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
}

$txt = Get-Content ".env" -Raw

function New-Secret([string]$prefix="") {
    $b=New-Object byte[] 32
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
    return $prefix + ([Convert]::ToHexString($b)).ToLower()
}

$ip=(Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "169.254*" -and
        $_.IPAddress -ne "127.0.0.1" -and
        $_.InterfaceAlias -notmatch "vEthernet|WSL|Loopback"
    } | Select-Object -First 1 -ExpandProperty IPAddress)
if (-not $ip) {$ip="127.0.0.1"}

$txt=$txt -replace '(?m)^SERVER_IP=.*$',"SERVER_IP=$ip"
if ($txt -match 'LITELLM_MASTER_KEY=sk-CHANGE_ME') {
    $txt=$txt -replace 'LITELLM_MASTER_KEY=sk-CHANGE_ME',("LITELLM_MASTER_KEY="+(New-Secret "sk-"))
}
if ($txt -match 'LITELLM_SALT_KEY=sk-CHANGE_ME') {
    $txt=$txt -replace 'LITELLM_SALT_KEY=sk-CHANGE_ME',("LITELLM_SALT_KEY="+(New-Secret "sk-"))
}
if ($txt -match 'WEBUI_SECRET_KEY=CHANGE_ME') {
    $txt=$txt -replace 'WEBUI_SECRET_KEY=CHANGE_ME',("WEBUI_SECRET_KEY="+(New-Secret))
}
Set-Content ".env" $txt -Encoding UTF8

if ($txt -match 'POSTGRES_PASSWORD=CHANGE_ME') {
    Write-Host "Edit .env and set your EXISTING PostgreSQL credentials first." -ForegroundColor Red
    exit 2
}

docker compose up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

Start-Sleep 5
docker compose ps

$envMap=@{}
Get-Content ".env" | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)=(.*)$') {$envMap[$matches[1]]=$matches[2]}
}
$server=$envMap["SERVER_IP"]
Write-Host "`nOpen WebUI : http://$server`:3000" -ForegroundColor Green
Write-Host "Forgejo    : http://$server`:3001"
Write-Host "LiteLLM    : http://$server`:4000"
Write-Host "Gateway    : http://$server`:8080"
