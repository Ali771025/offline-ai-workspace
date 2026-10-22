param(
  [string]$TarPath="",
  [string]$DistroName="Ubuntu-Offline",
  [string]$InstallDir="D:\WSL\Ubuntu-Offline"
)
$ErrorActionPreference="Stop"
$Root=Split-Path -Parent $PSScriptRoot
if (-not $TarPath) {$TarPath="$Root\wsl\Ubuntu-WSL2.tar"}
if (-not (Test-Path $TarPath)) {throw "WSL TAR not found: $TarPath"}

$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {throw "Run PowerShell as Administrator."}

dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart | Out-Null
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart | Out-Null
wsl --set-default-version 2 | Out-Null

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
wsl --import $DistroName $InstallDir $TarPath --version 2
if ($LASTEXITCODE -ne 0) {throw "WSL import failed."}
wsl -l -v
