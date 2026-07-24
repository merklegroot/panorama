# Package the Flutter Windows release into an Inno Setup installer.
# Usage (from repo root, on Windows with ISCC available):
#   powershell -File scripts/package-windows.ps1 -Version 1.0.6
param(
  [Parameter(Mandatory = $true)]
  [string]$Version,

  [string]$SourceDir = "",
  [string]$OutputDir = "",
  [string]$IssPath = "",
  [switch]$SkipVcRedist
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot

if (-not $SourceDir) {
  $SourceDir = Join-Path $RepoRoot "flutter_app\build\windows\x64\runner\Release"
}
if (-not $OutputDir) {
  $OutputDir = Join-Path $RepoRoot "release"
}
if (-not $IssPath) {
  $IssPath = Join-Path $RepoRoot "flutter_app\windows\packaging\panorama.iss"
}

$Exe = Join-Path $SourceDir "panorama.exe"
if (-not (Test-Path $Exe)) {
  Write-Error "Missing Windows release at: $SourceDir`nBuild first: (cd flutter_app; flutter build windows --release)"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$IsccCandidates = @(
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
  "ISCC.exe"
)
$Iscc = $IsccCandidates | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue } | Select-Object -First 1
if (-not $Iscc) {
  foreach ($c in $IsccCandidates) {
    if (Test-Path $c) { $Iscc = $c; break }
  }
}
if (-not $Iscc) {
  Write-Error "Inno Setup compiler (ISCC.exe) not found. Install with: choco install innosetup -y"
}

$Defines = @(
  "/DMyAppVersion=$Version",
  "/DMyAppSource=$SourceDir",
  "/DMyOutputDir=$OutputDir",
  "/DMyOutputBase=Panorama-$Version-windows-x64-setup"
)

if (-not $SkipVcRedist) {
  $VcRedist = Join-Path $OutputDir "vc_redist.x64.exe"
  if (-not (Test-Path $VcRedist)) {
    Write-Host "Downloading Visual C++ Redistributable…"
    Invoke-WebRequest -Uri "https://aka.ms/vs/17/release/vc_redist.x64.exe" -OutFile $VcRedist
  }
  $Defines += "/DMyVcRedist=$VcRedist"
}

Write-Host "Compiling installer with $Iscc"
& $Iscc @Defines $IssPath
if ($LASTEXITCODE -ne 0) {
  Write-Error "ISCC failed with exit code $LASTEXITCODE"
}

$Installer = Join-Path $OutputDir "Panorama-$Version-windows-x64-setup.exe"
if (-not (Test-Path $Installer)) {
  Write-Error "Expected installer not found: $Installer"
}
Write-Host "Wrote $Installer"
