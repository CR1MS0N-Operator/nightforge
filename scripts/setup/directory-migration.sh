#!/bin/bash
# scripts/setup/directory-migration.sh
# Phase 10: Safe directory reorganization – FINAL

set -euo pipefail

LOG_FILE="$HOME/directory-migration-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "Starting directory migration at $(date)"

# Function to move and log
move_dir() {
    local src="$1"
    local dst="$2"
    if [[ -e "$src" ]]; then
        mkdir -p "$(dirname "$dst")"
        mv -v "$src" "$dst"
    else
        echo "Source $src does not exist, skipping."
    fi
}

# --- Remove old engagement/test dirs ---
rm -rfv ~/engage/nightowl
rm -rfv ~/engage/TEST
rm -rfv ~/engage/test-company-2026

# --- Create target directories ---
mkdir -pv ~/engage/archive \
         ~/engage/templates \
         ~/engage/current \
         ~/lab/ad \
         ~/lab/linux \
         ~/lab/web \
         ~/lab/exploitdev \
         ~/lab/c2 \
         ~/lab/VMs \
         ~/Personal/Archives \
         ~/Personal/backups \
         ~/tmp

# --- Move lab & engagement directories ---
move_dir ~/engage/portswigger-labs   ~/lab/web/portswigger-labs
move_dir ~/exploitdev                 ~/lab/exploitdev
move_dir ~/c2                         ~/lab/c2
move_dir ~/VMs                         ~/lab/VMs

# Move contents of ~/Labs into ~/lab/ (manual sorting may be needed)
if [[ -d ~/Labs ]]; then
    echo "Moving contents of ~/Labs into ~/lab/ – please manually sort later."
    mv -v ~/Labs/* ~/lab/ 2>/dev/null || true
    rmdir ~/Labs 2>/dev/null || echo "$HOME/Labs not empty after move, check manually."
fi

# --- Move personal directories (Archives, Backups, github-backups) ---
move_dir ~/Archives                ~/Personal/Archives/
move_dir ~/Backups                 ~/Personal/backups/
move_dir ~/github-backups          ~/Personal/backups/github-backups

# --- Notes & Loot stay top-level (we'll handle per-engagement later) ---
echo "Notes and loot remain at ~/notes and ~/loot."

# --- Set permissions on sensitive dirs ---
chmod 700 ~/engage/archive
chmod 700 ~/lab

echo "Migration complete. Please review $LOG_FILE"
