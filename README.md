# Boot ISO

Tiny local launcher: pick an ISO → QEMU window. No disk, RAM, or network wizards.

The Linux and Windows installers are separate. The Linux curl one-liner will **not** work on Windows.

## Install (Linux / Omarchy)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/endergamershard-ctrl/simple-iso-vm/master/install.sh)
```

Clones into `~/.local/share/simple-iso-vm`, puts `boot-iso` on your PATH via `~/.local/bin`, and adds **Boot ISO** (Matrix green disc icon) to the app menu.

Re-run the same command anytime to update.

### Usage (Linux)

```bash
boot-iso                  # Walker picker over ~/Downloads
boot-iso /path/to.iso     # skip picker
```

Or open **Boot ISO** from Super+Space.

First run installs `qemu-desktop` and `edk2-ovmf` via `omarchy-pkg-add` if needed (Arch / Omarchy).

## Install (Windows)

In **PowerShell**:

```powershell
irm https://raw.githubusercontent.com/endergamershard-ctrl/simple-iso-vm/master/install.ps1 | iex
```

That will:

- install **Git** and **QEMU** via winget if missing
- clone into `%LOCALAPPDATA%\simple-iso-vm`
- add that folder to your user **PATH** (`boot-iso` / `boot-iso.cmd`)
- add **Boot ISO** to the Start Menu

Re-run the same command to update.

### Usage (Windows)

```powershell
boot-iso
boot-iso D:\ISOs\omarchy.iso
```

Or open **Boot ISO** from the Start Menu (no console window).

For better speed, enable **Windows Hypervisor Platform** (Optional features). Without it, QEMU uses TCG and will feel slower.

## Shared behavior

- Works with UEFI **and** BIOS-only ISOs: the firmware is auto-detected per ISO (OVMF/UEFI when the ISO ships an x64 EFI loader, otherwise SeaBIOS/legacy BIOS)
- Each ISO gets its own persistent 40G virtual disk (sparse) under the cache dir, so installers have somewhere to install. First run boots the ISO; once something is installed, later runs boot the disk with the ISO as fallback (press Esc for the boot menu)
- VM runs detached — closing the installer/shell does not stop it; close the QEMU window instead
- Defaults: ~half host RAM (4–8G), half host CPUs (2–6), virtio, user networking
- Linux: KVM + host CPU + GTK/GL, disks in `~/.cache/simple-iso-vm/disks/`
- Windows: WHPX when available, else TCG + GTK, disks in `%LOCALAPPDATA%\simple-iso-vm\disks\`

## Manual / from a clone

**Linux**

```bash
git clone https://github.com/endergamershard-ctrl/simple-iso-vm.git
cd simple-iso-vm
./install.sh
```

**Windows**

```powershell
git clone https://github.com/endergamershard-ctrl/simple-iso-vm.git
cd simple-iso-vm
.\install.ps1
```
