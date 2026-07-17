# Boot ISO

Tiny local launcher: pick an ISO → QEMU window. No disk, RAM, or network wizards.

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/endergamershard-ctrl/simple-iso-vm/master/install.sh)
```

That clones into `~/.local/share/simple-iso-vm`, puts `boot-iso` on your PATH via `~/.local/bin`, and adds **Boot ISO** to the app menu.

Re-run the same command anytime to update.

## Usage

```bash
boot-iso                  # Walker picker over ~/Downloads
boot-iso /path/to.iso     # skip picker
```

Or open **Boot ISO** from Super+Space.

First run installs `qemu-desktop` and `edk2-ovmf` via `omarchy-pkg-add` if needed (Arch / Omarchy).

The VM runs detached (no terminal). Closing a shell will not stop it — close the QEMU window instead.

## Defaults

~half host RAM (4–8G), half host CPUs (2–6), KVM + host CPU, UEFI, virtio + GTK/GL, CD-only boot, user networking.

## Manual / from a clone

```bash
git clone https://github.com/endergamershard-ctrl/simple-iso-vm.git
cd simple-iso-vm
./install.sh
```
