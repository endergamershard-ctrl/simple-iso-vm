#!/usr/bin/env bash
# Install Boot ISO to ~/.local (bin + app menu).
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/endergamershard-ctrl/simple-iso-vm/master/install.sh)

set -euo pipefail

REPO_URL="${SIMPLE_ISO_VM_REPO:-https://github.com/endergamershard-ctrl/simple-iso-vm.git}"
REPO_REF="${SIMPLE_ISO_VM_REF:-master}"
INSTALL_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/simple-iso-vm"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
BIN_PATH="$BIN_DIR/boot-iso"

echo "Installing Boot ISO → $INSTALL_DIR"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required." >&2
  exit 1
fi

mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$APP_DIR"

if [[ -d $INSTALL_DIR/.git ]]; then
  git -C "$INSTALL_DIR" fetch --quiet origin "$REPO_REF"
  git -C "$INSTALL_DIR" checkout --quiet "$REPO_REF"
  git -C "$INSTALL_DIR" pull --ff-only --quiet origin "$REPO_REF"
else
  # Fresh install (or replace a non-git copy)
  if [[ -e $INSTALL_DIR ]] && [[ ! -d $INSTALL_DIR/.git ]]; then
    rm -rf "$INSTALL_DIR"
  fi
  git clone --quiet --branch "$REPO_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/boot-iso"
ln -sfn "$INSTALL_DIR/boot-iso" "$BIN_PATH"

# Desktop entry always points at the installed binary (not a dev checkout path).
cat >"$APP_DIR/boot-iso.desktop" <<EOF
[Desktop Entry]
Name=Boot ISO
Comment=Pick an ISO and boot it in QEMU
Exec=uwsm app -- $BIN_PATH
Icon=media-optical
Terminal=false
Type=Application
Categories=System;Emulator;
Keywords=qemu;iso;vm;virtual;
EOF

update-desktop-database "$APP_DIR" 2>/dev/null || true

if [[ :$PATH: != *:$BIN_DIR:* ]]; then
  echo
  echo "Add this to your shell config so \`boot-iso\` works in a terminal:"
  echo "  export PATH=\"$BIN_DIR:\$PATH\""
fi

echo
echo "Installed."
echo "  Command:  boot-iso"
echo "  App menu: Boot ISO (Super+Space)"
echo
echo "QEMU packages install on first run if missing."
