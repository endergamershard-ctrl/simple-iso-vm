#!/usr/bin/env bash
# Install Boot ISO to ~/.local (bin + app menu). Linux / Omarchy only.
# Windows: irm https://raw.githubusercontent.com/endergamershard-ctrl/simple-iso-vm/master/install.ps1 | iex
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/endergamershard-ctrl/simple-iso-vm/master/install.sh)

set -euo pipefail

if [[ "$(uname -s)" == MINGW* || "$(uname -s)" == MSYS* || "$(uname -s)" == CYGWIN* ]]; then
  echo "This installer is for Linux. On Windows, run in PowerShell:" >&2
  echo "  irm https://raw.githubusercontent.com/endergamershard-ctrl/simple-iso-vm/master/install.ps1 | iex" >&2
  exit 1
fi
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
  git -C "$INSTALL_DIR" checkout --quiet -B "$REPO_REF" "origin/$REPO_REF"
  git -C "$INSTALL_DIR" reset --hard --quiet "origin/$REPO_REF"
  git -C "$INSTALL_DIR" clean -fd --quiet
else
  # Fresh install (or replace a non-git copy)
  if [[ -e $INSTALL_DIR ]]; then
    rm -rf "$INSTALL_DIR"
  fi
  git clone --quiet --branch "$REPO_REF" --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/boot-iso"
ln -sfn "$INSTALL_DIR/boot-iso" "$BIN_PATH"

# App icon (hicolor theme) + desktop entry
ICON_SRC="$INSTALL_DIR/icon.png"
ICON_NAME="boot-iso"
if [[ -f $ICON_SRC ]] && command -v magick >/dev/null 2>&1; then
  for size in 48 64 128 256 512; do
    icon_dir="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/${size}x${size}/apps"
    mkdir -p "$icon_dir"
    magick "$ICON_SRC" -resize "${size}x${size}" "$icon_dir/${ICON_NAME}.png"
  done
elif [[ -f $ICON_SRC ]]; then
  icon_dir="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps"
  mkdir -p "$icon_dir"
  cp -- "$ICON_SRC" "$icon_dir/${ICON_NAME}.png"
fi

# Desktop entry always points at the installed binary (not a dev checkout path).
cat >"$APP_DIR/boot-iso.desktop" <<EOF
[Desktop Entry]
Name=Boot ISO
Comment=Pick an ISO and boot it in QEMU
Exec=uwsm app -- $BIN_PATH
Icon=$ICON_NAME
Terminal=false
Type=Application
Categories=System;Emulator;
Keywords=qemu;iso;vm;virtual;
EOF

gtk-update-icon-cache -f -t "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" 2>/dev/null || true
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
