# Boot ISO

Tiny local launcher: pick an ISO → QEMU window. No disk, RAM, or network wizards.

## Usage

```bash
./boot-iso                  # Walker picker over ~/Downloads
./boot-iso /path/to.iso     # skip picker
```

Or open **Boot ISO** from Super+Space.

First run installs `qemu-desktop` and `edk2-ovmf` via `omarchy-pkg-add` if needed.

The VM runs detached (no terminal). Closing a shell will not stop it — close the QEMU window instead.

Defaults: ~half host RAM (4–8G), half host CPUs (2–6), KVM + host CPU, UEFI, virtio + GTK/GL, CD-only boot, user networking.
