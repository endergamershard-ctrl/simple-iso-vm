#Requires -Version 5.1
<#
.SYNOPSIS
  Install Boot ISO for Windows (QEMU + Start Menu + optional PATH).
.DESCRIPTION
  Usage (PowerShell):
    irm https://raw.githubusercontent.com/endergamershard-ctrl/simple-iso-vm/master/install.ps1 | iex
#>
[CmdletBinding()]
param(
  [string]$RepoUrl = $(if ($env:SIMPLE_ISO_VM_REPO) { $env:SIMPLE_ISO_VM_REPO } else { 'https://github.com/endergamershard-ctrl/simple-iso-vm.git' }),
  [string]$RepoRef = $(if ($env:SIMPLE_ISO_VM_REF) { $env:SIMPLE_ISO_VM_REF } else { 'master' })
)

$ErrorActionPreference = 'Stop'

$InstallDir = Join-Path $env:LOCALAPPDATA 'simple-iso-vm'
$StartMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$ShortcutPath = Join-Path $StartMenu 'Boot ISO.lnk'
$LauncherPs1 = Join-Path $InstallDir 'boot-iso.ps1'
$LauncherCmd = Join-Path $InstallDir 'boot-iso.cmd'

Write-Host "Installing Boot ISO → $InstallDir"

function Ensure-Git {
  if (Get-Command git -ErrorAction SilentlyContinue) { return }
  Write-Host 'git not found; installing Git via winget...'
  winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
    [System.Environment]::GetEnvironmentVariable('Path', 'User')
  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'git still missing after install. Open a new PowerShell and re-run install.ps1.'
  }
}

function Ensure-Qemu {
  $qemu = Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
  if ($qemu) { return }
  $bundled = Join-Path ${env:ProgramFiles} 'qemu\qemu-system-x86_64.exe'
  if (Test-Path -LiteralPath $bundled) { return }

  Write-Host 'Installing QEMU via winget (SoftwareFreedomConservancy.QEMU)...'
  winget install -e --id SoftwareFreedomConservancy.QEMU --accept-package-agreements --accept-source-agreements
  $env:Path = [System.Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
    [System.Environment]::GetEnvironmentVariable('Path', 'User')
}

Ensure-Git
Ensure-Qemu

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

if (Test-Path (Join-Path $InstallDir '.git')) {
  git -C $InstallDir fetch --quiet origin $RepoRef
  git -C $InstallDir checkout --quiet -B $RepoRef "origin/$RepoRef"
  git -C $InstallDir reset --hard --quiet "origin/$RepoRef"
  git -C $InstallDir clean -fd --quiet
} else {
  if (Test-Path $InstallDir) {
    Remove-Item -Recurse -Force $InstallDir
  }
  git clone --quiet --branch $RepoRef --depth 1 $RepoUrl $InstallDir
}

# PATH-friendly wrapper (opens picker, no lingering console when launched via shortcut).
@(
  '@echo off'
  "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$LauncherPs1`" %*"
) | Set-Content -Encoding ASCII -Path $LauncherCmd

# User PATH: add install dir if missing
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($userPath -notlike "*$InstallDir*") {
  [Environment]::SetEnvironmentVariable('Path', "$InstallDir;$userPath", 'User')
  $env:Path = "$InstallDir;$env:Path"
  Write-Host "Added to user PATH: $InstallDir"
}

# Start Menu shortcut (hidden PowerShell host → only the QEMU window).
$iconIco = Join-Path $InstallDir 'icon.ico'
$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($ShortcutPath)
$sc.TargetPath = 'powershell.exe'
$sc.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$LauncherPs1`""
$sc.WorkingDirectory = $InstallDir
$sc.Description = 'Pick an ISO and boot it in QEMU'
if (Test-Path -LiteralPath $iconIco) {
  $sc.IconLocation = "$iconIco,0"
} else {
  $sc.IconLocation = 'shell32.dll,167'
}
$sc.Save()

Write-Host ''
Write-Host 'Installed.'
Write-Host '  Command:  boot-iso   (new terminal)  or  boot-iso.cmd'
Write-Host '  Start Menu: Boot ISO'
Write-Host ''
Write-Host 'For best speed, enable Windows Hypervisor Platform:'
Write-Host '  Settings → Apps → Optional features → More Windows features → Windows Hypervisor Platform'
Write-Host 'Without it, QEMU falls back to TCG (slower).'
