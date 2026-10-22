param(
    [string]$PostgresContainer = "",
    [string]$RedisContainer = "",
    [string]$QdrantContainer = "",
    [string]$WslDistro = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

function Ask([string]$Value, [string]$Prompt) {
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return (Read-Host $Prompt)
    }
    return $Value
}

function Get-ContainerInfo([string]$Container) {
    $raw = docker inspect $Container 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $raw) {
        throw "Container not found: $Container"
    }
    return (($raw | Out-String) | ConvertFrom-Json)[0]
}

function Ensure-ContainerRunning([string]$Container) {
    $info = Get-ContainerInfo $Container
    $wasRunning = [bool]$info.State.Running

    if (-not $wasRunning) {
        Write-Host "Starting stopped container: $Container" -ForegroundColor Yellow
        docker start $Container | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Could not start container: $Container"
        }

        for ($i=0; $i -lt 30; $i++) {
            Start-Sleep -Seconds 1
            $info = Get-ContainerInfo $Container
            if ($info.State.Running) {
                return $false   # false means it was NOT running before
            }
        }

        throw "Container did not become running: $Container"
    }

    return $true   # true means it was already running
}

function Restore-PreviousState([string]$Container, [bool]$WasRunning) {
    if (-not $WasRunning) {
        Write-Host "Returning container to previous stopped state: $Container" -ForegroundColor DarkYellow
        docker stop $Container | Out-Null
    }
}

function Write-Utf8NoBom([string]$Path, [string[]]$Lines) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllLines($Path, $Lines, $utf8NoBom)
}

Write-Host "=== Offline AI Hub v3.1 FULL Builder ===" -ForegroundColor Cyan

docker version | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "Docker Desktop is not running."
}

$PostgresContainer = Ask $PostgresContainer "Existing PostgreSQL container name or ID"
$RedisContainer    = Ask $RedisContainer    "Existing Redis container name or ID"
$QdrantContainer  = Ask $QdrantContainer  "Existing Qdrant container name or ID"

if ([string]::IsNullOrWhiteSpace($WslDistro)) {
    Write-Host "`nAvailable WSL distributions:" -ForegroundColor Cyan
    wsl -l -v
    $WslDistro = Read-Host "WSL distro name to export (example: Ubuntu-24.04)"
}

# Validate
$pgInfo = Get-ContainerInfo $PostgresContainer
$redisInfo = Get-ContainerInfo $RedisContainer
$qInfo = Get-ContainerInfo $QdrantContainer

$AiDir    = Join-Path $Root "docker-images\ai"
$InfraDir = Join-Path $Root "docker-images\infrastructure"
$PgDir    = Join-Path $Root "backups\postgres"
$RedisDir = Join-Path $Root "backups\redis"
$QDir     = Join-Path $Root "backups\qdrant"
$WslDir   = Join-Path $Root "wsl"
$TempDir  = Join-Path $Root "_pack-temp"

New-Item -ItemType Directory -Force -Path `
    $AiDir,$InfraDir,$PgDir,$RedisDir,$QDir,$WslDir,$TempDir | Out-Null

# ------------------------------------------------------------
# 1. AI IMAGES
# ------------------------------------------------------------
Write-Host "`n[1/8] AI images" -ForegroundColor Cyan

$AiList = Join-Path $Root "images-ai.txt"
if (-not (Test-Path $AiList)) {
    throw "images-ai.txt not found: $AiList"
}

$aiImages = Get-Content $AiList | Where-Object { $_.Trim() -ne "" }

foreach ($img in $aiImages) {
    Write-Host "Pulling $img" -ForegroundColor DarkCyan
    docker pull $img
    if ($LASTEXITCODE -ne 0) {
        throw "Pull failed: $img"
    }

    $safe = $img.Replace("/","_").Replace(":","__")
    $dest = Join-Path $AiDir "$safe.tar"

    Write-Host "Saving $img -> $dest" -ForegroundColor DarkCyan
    docker save -o $dest $img
    if ($LASTEXITCODE -ne 0) {
        throw "docker save failed: $img"
    }
}

# ------------------------------------------------------------
# 2. EXISTING INFRASTRUCTURE IMAGES
# ------------------------------------------------------------
Write-Host "`n[2/8] Existing infrastructure images" -ForegroundColor Cyan

$pgInfo = Get-ContainerInfo $PostgresContainer
$redisInfo = Get-ContainerInfo $RedisContainer
$qInfo = Get-ContainerInfo $QdrantContainer

$pgImage = [string]$pgInfo.Config.Image
$redisImage = [string]$redisInfo.Config.Image
$qdrantImage = [string]$qInfo.Config.Image

Write-Host "PostgreSQL image: $pgImage"
Write-Host "Redis image     : $redisImage"
Write-Host "Qdrant image    : $qdrantImage"

docker save -o (Join-Path $InfraDir "postgres.tar") $pgImage
if ($LASTEXITCODE -ne 0) { throw "Saving PostgreSQL image failed." }

docker save -o (Join-Path $InfraDir "redis.tar") $redisImage
if ($LASTEXITCODE -ne 0) { throw "Saving Redis image failed." }

docker save -o (Join-Path $InfraDir "qdrant.tar") $qdrantImage
if ($LASTEXITCODE -ne 0) { throw "Saving Qdrant image failed." }

@"
POSTGRES_IMAGE=$pgImage
REDIS_IMAGE=$redisImage
QDRANT_IMAGE=$qdrantImage
"@ | Set-Content (Join-Path $Root "detected-images.env") -Encoding UTF8

# ------------------------------------------------------------
# 3. POSTGRESQL BACKUP
# ------------------------------------------------------------
Write-Host "`n[3/8] PostgreSQL backup" -ForegroundColor Cyan

$pgWasRunning = Ensure-ContainerRunning $PostgresContainer

try {
    $pgUser = Read-Host "PostgreSQL user for pg_dumpall (default postgres)"
    if ([string]::IsNullOrWhiteSpace($pgUser)) {
        $pgUser = "postgres"
    }

    $pgFile = Join-Path $PgDir "postgres-all.sql"

    Write-Host "Running pg_dumpall..." -ForegroundColor DarkCyan

    $dumpOutput = & docker exec $PostgresContainer pg_dumpall -U $pgUser 2>&1
    $exit = $LASTEXITCODE

    if ($exit -ne 0) {
        Write-Host ($dumpOutput | Out-String) -ForegroundColor Red
        throw "pg_dumpall failed. Check PostgreSQL username/password/authentication."
    }

    Write-Utf8NoBom $pgFile $dumpOutput
    Write-Host "[OK] PostgreSQL backup: $pgFile" -ForegroundColor Green
}
finally {
    Restore-PreviousState $PostgresContainer $pgWasRunning
}

# ------------------------------------------------------------
# 4. REDIS BACKUP
# ------------------------------------------------------------
Write-Host "`n[4/8] Redis backup" -ForegroundColor Cyan

$redisWasRunning = Ensure-ContainerRunning $RedisContainer

try {
    Write-Host "Requesting Redis SAVE..." -ForegroundColor DarkCyan
    $saveResult = docker exec $RedisContainer redis-cli SAVE 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Host "[WARN] redis-cli SAVE failed; copying /data anyway." -ForegroundColor Yellow
        Write-Host ($saveResult | Out-String)
    }

    $redisTemp = Join-Path $TempDir "redis-data"
    if (Test-Path $redisTemp) {
        Remove-Item $redisTemp -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $redisTemp | Out-Null

    Write-Host "Copying Redis /data..." -ForegroundColor DarkCyan
    docker cp "${RedisContainer}:/data/." $redisTemp
    if ($LASTEXITCODE -ne 0) {
        throw "docker cp failed for Redis /data."
    }

    $redisArchive = Join-Path $RedisDir "redis-data.tar.gz"
    if (Test-Path $redisArchive) {
        Remove-Item $redisArchive -Force
    }

    tar.exe -czf $redisArchive -C $redisTemp .
    if ($LASTEXITCODE -ne 0) {
        throw "Creating Redis tar.gz failed."
    }

    Write-Host "[OK] Redis backup: $redisArchive" -ForegroundColor Green
}
finally {
    Restore-PreviousState $RedisContainer $redisWasRunning
}

# ------------------------------------------------------------
# 5. QDRANT BACKUP
# ------------------------------------------------------------
Write-Host "`n[5/8] Qdrant backup" -ForegroundColor Cyan

$qWasRunning = [bool](Get-ContainerInfo $QdrantContainer).State.Running

if ($qWasRunning) {
    Write-Host "Stopping Qdrant temporarily for a consistent storage copy..." -ForegroundColor Yellow
    docker stop $QdrantContainer | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Could not stop Qdrant."
    }
}

try {
    $qTemp = Join-Path $TempDir "qdrant-storage"
    if (Test-Path $qTemp) {
        Remove-Item $qTemp -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $qTemp | Out-Null

    Write-Host "Copying Qdrant /qdrant/storage..." -ForegroundColor DarkCyan
    docker cp "${QdrantContainer}:/qdrant/storage/." $qTemp

    if ($LASTEXITCODE -ne 0) {
        throw "docker cp failed for Qdrant storage."
    }

    $qArchive = Join-Path $QDir "qdrant-storage.tar.gz"
    if (Test-Path $qArchive) {
        Remove-Item $qArchive -Force
    }

    tar.exe -czf $qArchive -C $qTemp .
    if ($LASTEXITCODE -ne 0) {
        throw "Creating Qdrant tar.gz failed."
    }

    Write-Host "[OK] Qdrant backup: $qArchive" -ForegroundColor Green
}
finally {
    if ($qWasRunning) {
        docker start $QdrantContainer | Out-Null
    }
}

# ------------------------------------------------------------
# 6. WSL EXPORT
# ------------------------------------------------------------
Write-Host "`n[6/8] WSL export" -ForegroundColor Cyan

$wslTar = Join-Path $WslDir "Ubuntu-WSL2.tar"

$knownDistros = (wsl -l -q) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

if ($knownDistros -notcontains $WslDistro) {
    Write-Host "Available WSL distributions:" -ForegroundColor Yellow
    $knownDistros | ForEach-Object { Write-Host " - $_" }
    throw "WSL distro '$WslDistro' was not found."
}

Write-Host "Exporting WSL distro '$WslDistro'..." -ForegroundColor DarkCyan
wsl --shutdown
wsl --export $WslDistro $wslTar

if ($LASTEXITCODE -ne 0) {
    throw "WSL export failed."
}

Write-Host "[OK] WSL export: $wslTar" -ForegroundColor Green

# ------------------------------------------------------------
# 7. SHA256
# ------------------------------------------------------------
Write-Host "`n[7/8] SHA256" -ForegroundColor Cyan

$shaFile = Join-Path $Root "SHA256SUMS.txt"
Remove-Item $shaFile -ErrorAction SilentlyContinue

Get-ChildItem $Root -Recurse -File |
    Where-Object {
        $_.Name -ne "SHA256SUMS.txt" -and
        $_.FullName -notlike "$TempDir*"
    } |
    ForEach-Object {
        $h = Get-FileHash $_.FullName -Algorithm SHA256
        $rel = $_.FullName.Substring($Root.Length + 1)
        "$($h.Hash)  $rel" | Add-Content $shaFile
    }

Write-Host "[OK] SHA256 manifest generated." -ForegroundColor Green

# Remove temp before packaging
if (Test-Path $TempDir) {
    Remove-Item $TempDir -Recurse -Force
}

# ------------------------------------------------------------
# 8. ZIP
# ------------------------------------------------------------
Write-Host "`n[8/8] Final package" -ForegroundColor Cyan

$parent = Split-Path $Root -Parent
$zip = Join-Path $parent "Offline-AI-Hub-v3.1-FULL-PORTABLE.zip"

if (Test-Path $zip) {
    Remove-Item $zip -Force
}

# Compress-Archive may fail for huge packs; try it first.
try {
    Compress-Archive -Path "$Root\*" -DestinationPath $zip -CompressionLevel Optimal
    Write-Host "[DONE] ZIP created:" -ForegroundColor Green
    Write-Host $zip -ForegroundColor Green
}
catch {
    Write-Host "[WARN] Windows Compress-Archive failed, usually because the pack is very large." -ForegroundColor Yellow

    if (Get-Command 7z.exe -ErrorAction SilentlyContinue) {
        $sevenZip = Join-Path $parent "Offline-AI-Hub-v3.1-FULL-PORTABLE.7z"
        if (Test-Path $sevenZip) {
            Remove-Item $sevenZip -Force
        }

        & 7z.exe a -t7z $sevenZip "$Root\*" -mx=5
        if ($LASTEXITCODE -ne 0) {
            throw "7-Zip packaging failed."
        }

        Write-Host "[DONE] 7z created:" -ForegroundColor Green
        Write-Host $sevenZip -ForegroundColor Green
    }
    else {
        Write-Host "All exported files are already inside:" -ForegroundColor Yellow
        Write-Host $Root -ForegroundColor Yellow
        Write-Host "Install/use 7-Zip and archive this folder manually." -ForegroundColor Yellow
    }
}
