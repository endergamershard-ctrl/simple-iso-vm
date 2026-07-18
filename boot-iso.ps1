#Requires -Version 5.1
<#
.SYNOPSIS
  Pick an ISO and boot it in a QEMU window (Windows).
.DESCRIPTION
  No wizards. Detached GTK window. Uses WHPX when available, else TCG.
#>
[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Iso
)

$ErrorActionPreference = 'Stop'

$CacheDir = Join-Path $env:LOCALAPPDATA 'simple-iso-vm'
$LogFile = Join-Path $CacheDir 'qemu.log'
New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null

function Find-Qemu {
  $cmd = Get-Command qemu-system-x86_64.exe -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $candidates = @(
    (Join-Path ${env:ProgramFiles} 'qemu\qemu-system-x86_64.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'qemu\qemu-system-x86_64.exe')
  )
  foreach ($p in $candidates) {
    if (Test-Path -LiteralPath $p) { return $p }
  }
  return $null
}

function Find-Ovmf {
  $shareRoots = @(
    (Join-Path ${env:ProgramFiles} 'qemu\share'),
    (Join-Path ${env:ProgramFiles(x86)} 'qemu\share')
  )

  $codeNames = @(
    'edk2-x86_64-code.fd',
    'edk2\x64\OVMF_CODE.4m.fd',
    'OVMF_CODE.fd'
  )
  $varsNames = @(
    'edk2-i386-vars.fd',
    'edk2-x86_64-vars.fd',
    'edk2\x64\OVMF_VARS.4m.fd',
    'OVMF_VARS.fd'
  )

  $code = $null
  $vars = $null
  foreach ($root in $shareRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    foreach ($name in $codeNames) {
      $p = Join-Path $root $name
      if (Test-Path -LiteralPath $p) { $code = $p; break }
    }
    foreach ($name in $varsNames) {
      $p = Join-Path $root $name
      if (Test-Path -LiteralPath $p) { $vars = $p; break }
    }
    if ($code -and $vars) { break }
  }

  if (-not $code -or -not $vars) {
    throw "OVMF firmware not found under QEMU share/. Reinstall QEMU (winget: SoftwareFreedomConservancy.QEMU)."
  }
  return @{ Code = $code; VarsTemplate = $vars }
}

function Test-Whpx {
  try {
    $feat = Get-WindowsOptionalFeature -Online -FeatureName HypervisorPlatform -ErrorAction SilentlyContinue
    if ($feat -and $feat.State -eq 'Enabled') { return $true }
  } catch {}
  # Also present when Hyper-V / WSL2 hypervisor is active
  if (Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue) {
    try {
      $hv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-Hypervisor -ErrorAction SilentlyContinue
      if ($hv -and $hv.State -eq 'Enabled') { return $true }
    } catch {}
  }
  return $false
}

function Select-Iso {
  param([string]$Path)
  if ($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
      throw "Not a file: $Path"
    }
    return (Resolve-Path -LiteralPath $Path).Path
  }

  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title = 'Select ISO'
  $dialog.Filter = 'ISO images (*.iso)|*.iso|All files (*.*)|*.*'
  $downloads = Join-Path $env:USERPROFILE 'Downloads'
  if (Test-Path -LiteralPath $downloads) {
    $dialog.InitialDirectory = $downloads
  }
  if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    exit 0
  }
  return $dialog.FileName
}

function Get-VmCpus {
  $n = [Math]::Floor((Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors / 2)
  if ($n -lt 2) { $n = 2 }
  if ($n -gt 6) { $n = 6 }
  return [int]$n
}

function Get-VmRamMb {
  $totalMb = [Math]::Floor((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1MB)
  $halfGb = [Math]::Floor(($totalMb / 1024) / 2)
  if ($halfGb -lt 4) { $halfGb = 4 }
  if ($halfGb -gt 8) { $halfGb = 8 }
  return [int]($halfGb * 1024)
}

# 'uefi' if the ISO carries an x64 UEFI loader, else 'bios'. Our OVMF is x64,
# so ia32-only / BIOS-only media must boot via SeaBIOS instead.
function Get-FirmwareForIso {
  param([string]$Path)
  $img = $null
  try {
    $img = Mount-DiskImage -ImagePath $Path -PassThru -ErrorAction Stop
    $vol = ($img | Get-Volume -ErrorAction Stop)
    $drive = $vol.DriveLetter
    if ($drive) {
      $loader = Join-Path ($drive + ':\') 'EFI\BOOT\BOOTX64.EFI'
      if (Test-Path -LiteralPath $loader) { return 'uefi' }
    }
    return 'bios'
  } catch {
    # If we cannot inspect it, assume UEFI (covers the common case).
    return 'uefi'
  } finally {
    if ($img) { Dismount-DiskImage -ImagePath $Path -ErrorAction SilentlyContinue | Out-Null }
  }
}

$qemu = Find-Qemu
if (-not $qemu) {
  Add-Type -AssemblyName System.Windows.Forms | Out-Null
  [System.Windows.Forms.MessageBox]::Show(
    "QEMU not found. Run install.ps1 first (or: winget install -e --id SoftwareFreedomConservancy.QEMU).",
    'Boot ISO',
    'OK',
    'Error'
  ) | Out-Null
  throw 'QEMU not found'
}

$isoPath = Select-Iso -Path $Iso
$cpus = Get-VmCpus
$ramMb = Get-VmRamMb
$accel = if (Test-Whpx) { 'whpx' } else { 'tcg' }
$firmware = Get-FirmwareForIso -Path $isoPath

# Persistent per-ISO disk so installers have a target. Fresh disk: boot the CD.
# Existing disk: boot it first (installed system), ISO as fallback.
$diskDir = Join-Path $CacheDir 'disks'
New-Item -ItemType Directory -Force -Path $diskDir | Out-Null
$disk = Join-Path $diskDir ([System.IO.Path]::GetFileNameWithoutExtension($isoPath) + '.qcow2')
if (Test-Path -LiteralPath $disk) {
  $bootOrder = 'c'
} else {
  $bootOrder = 'd'
  $qemuImg = Join-Path (Split-Path -Parent $qemu) 'qemu-img.exe'
  & $qemuImg create -f qcow2 $disk 40G | Out-Null
}

$qemuArgs = @(
  '-machine', "q35,accel=$accel"
  '-m', "$ramMb"
  '-smp', "$cpus"
)

# UEFI guests need OVMF pflash; BIOS guests use QEMU's built-in SeaBIOS.
if ($firmware -eq 'uefi') {
  $ovmf = Find-Ovmf
  $varsFile = Join-Path $CacheDir 'ovmf-vars.fd'
  Copy-Item -LiteralPath $ovmf.VarsTemplate -Destination $varsFile -Force
  $qemuArgs += @(
    '-drive', "if=pflash,format=raw,readonly=on,file=$($ovmf.Code)"
    '-drive', "if=pflash,format=raw,file=$varsFile"
  )
}

$qemuArgs += @(
  '-drive', "file=$isoPath,media=cdrom,readonly=on,if=none,id=cd0,cache=unsafe"
  '-device', 'virtio-scsi-pci,id=scsi0'
  '-device', 'scsi-cd,drive=cd0'
  '-drive', "file=$disk,format=qcow2,if=virtio,discard=unmap"
  '-boot', "order=$bootOrder,menu=on"
  '-device', 'virtio-vga'
  '-display', 'gtk'
  '-netdev', 'user,id=net0'
  '-device', 'virtio-net-pci,netdev=net0'
  '-name', "Boot ISO: $(Split-Path -Leaf $isoPath)"
)

if ($accel -eq 'whpx') {
  $qemuArgs = @('-cpu', 'max') + $qemuArgs
} else {
  $qemuArgs = @('-cpu', 'qemu64') + $qemuArgs
}

# Detached GUI process (not tied to this PowerShell window).
$proc = Start-Process -FilePath $qemu -ArgumentList $qemuArgs -PassThru

Start-Sleep -Milliseconds 800
if ($proc.HasExited) {
  "QEMU exited immediately (accel=$accel, exit=$($proc.ExitCode)) at $(Get-Date -Format o)" |
    Set-Content -Path $LogFile
  throw "QEMU exited immediately (accel=$accel). See $LogFile"
}
