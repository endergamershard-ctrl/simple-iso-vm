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

- VM runs detached — closing the installer/shell does not stop it; close the QEMU window instead
- Defaults: ~half host RAM (4–8G), half host CPUs (2–6), UEFI, virtio, CD-only boot, user networking
- Linux: KVM + host CPU + GTK/GL  
- Windows: WHPX when available, else TCG + GTK

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
