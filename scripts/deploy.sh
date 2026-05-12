#!/bin/bash
# NightForge deploy script
# Copies quickshell (Quickshell resolves symlinks) and stows everything else

set -euo pipefail
# Disable pipefail for stow (may fail on conflicts)
set +e

REPO="$(cd "$(dirname "$0")/.." && pwd)"

echo "[*] Deploying NightForge dotfiles..."

# Remove old quickshell files that block stow
rm -f ~/.config/quickshell/main.qml

# Remove conflicting regular files that block stow symlinks
for f in ~/.config/ghostty/config ~/.config/btop/btop.conf; do
    if [[ -f "$f" && ! -L "$f" ]]; then
        rm -f "$f"
        echo "[*] Removed conflicting file: $f"
    fi
done

set -euo pipefail

# Stow all dotfiles packages
for pkg in matugen rofi ghostty systemd niri; do
  if [[ -d "$REPO/dotfiles/$pkg" ]]; then
    echo "[*] Stowing $pkg..."
    stow -d "$REPO/dotfiles" -t ~ "$pkg"
  fi
done

# Copy quickshell (Quickshell resolves symlinks, breaking relative imports)
echo "[*] Copying quickshell..."
mkdir -p ~/.config/quickshell
rsync -av --delete "$REPO/dotfiles/quickshell/.config/quickshell/" ~/.config/quickshell/

echo "[+] Deploy complete. Run: quickshell &"
