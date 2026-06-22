#!/bin/bash
# Weekly Cleanup & Update Script
# Run: Every Sunday evening
# Purpose: System updates, safe cleanup with confirmations

set -e

echo "🧹 Weekly Cleanup & Update - $(date)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. System Updates
echo "[1/7] Checking for system updates..."
UPDATES=$(checkupdates 2>/dev/null | wc -l)
if [ "$UPDATES" -gt 0 ]; then
    echo "  📦 $UPDATES updates available:"
    checkupdates | head -10
    [ "$UPDATES" -gt 10 ] && echo "  ... and $((UPDATES - 10)) more"
    echo ""
    read -p "  Update system now? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        sudo pacman -Syu
        echo "  ✓ System updated"
    else
        echo "  ⏭  Skipped"
    fi
else
    echo "  ✓ System up to date"
fi

# 2. AUR Updates
echo "[2/7] Checking AUR packages..."
if command -v yay &> /dev/null; then
    AUR_UPDATES=$(yay -Qua 2>/dev/null | wc -l)
    if [ "$AUR_UPDATES" -gt 0 ]; then
        echo "  📦 $AUR_UPDATES AUR updates available"
        yay -Qua | head -5
        [ "$AUR_UPDATES" -gt 5 ] && echo "  ... and $((AUR_UPDATES - 5)) more"
        echo ""
        read -p "  Update AUR packages? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            yay -Sua
            echo "  ✓ AUR packages updated"
        else
            echo "  ⏭  Skipped"
        fi
    else
        echo "  ✓ AUR packages up to date"
    fi
fi

# 3. Review old Downloads (with archive option)
echo "[3/7] Reviewing old downloads (30+ days)..."
if [ -d ~/Downloads ]; then
    OLD_FILES=$(find ~/Downloads -type f -mtime +30 2>/dev/null)
    OLD_COUNT=$(echo "$OLD_FILES" | grep -c '^' 2>/dev/null || echo 0)
    
    if [ "$OLD_COUNT" -gt 0 ]; then
        echo "  📁 Found $OLD_COUNT old files"
        echo "$OLD_FILES" | head -10 | sed 's|.*/||' | sed 's/^/    - /'
        [ "$OLD_COUNT" -gt 10 ] && echo "    ... and $((OLD_COUNT - 10)) more"
        echo ""
        echo "  Options:"
        echo "    [1] Archive to ~/Archives/downloads-$(date +%Y%m%d)"
        echo "    [2] Delete permanently"
        echo "    [3] Skip"
        read -p "  Choice [1/2/3]: " -n 1 -r
        echo
        
        case $REPLY in
            1)
                ARCHIVE_DIR="$HOME/Archives/downloads-$(date +%Y%m%d)"
                mkdir -p "$ARCHIVE_DIR"
                echo "$OLD_FILES" | while read -r file; do
                    mv "$file" "$ARCHIVE_DIR/" 2>/dev/null || true
                done
                echo "  ✓ Archived to $ARCHIVE_DIR"
                ;;
            2)
                echo "$OLD_FILES" | while read -r file; do
                    rm "$file" 2>/dev/null || true
                done
                echo "  ✓ Deleted $OLD_COUNT files"
                ;;
            *)
                echo "  ⏭  Skipped"
                ;;
        esac
    else
        echo "  ✓ No old files to review"
    fi
fi

# 4. Clean package cache (keep last 3 versions)
echo "[4/7] Cleaning package cache..."
sudo paccache -rk3 -q
echo "  ✓ Package cache cleaned (kept last 3 versions)"

# 5. Remove orphaned packages
echo "[5/7] Checking for orphaned packages..."
ORPHANS=$(pacman -Qdtq 2>/dev/null)
if [ -n "$ORPHANS" ]; then
    ORPHAN_COUNT=$(echo "$ORPHANS" | wc -l)
    echo "  📦 Found $ORPHAN_COUNT orphaned packages:"
    # shellcheck disable=SC2001 # variable subst doesn't handle multiline well
    echo "$ORPHANS" | sed 's/^/    - /'
    echo ""
    read -p "  Remove these packages? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo pacman -Rns "$ORPHANS" --noconfirm
        echo "  ✓ Orphans removed"
    else
        echo "  ⏭  Skipped"
    fi
else
    echo "  ✓ No orphaned packages"
fi

# 6. Clean systemd journal (keep 2 weeks)
echo "[6/7] Cleaning systemd journal..."
BEFORE=$(journalctl --disk-usage 2>/dev/null | awk '{print $7}')
sudo journalctl --vacuum-time=2weeks --quiet
AFTER=$(journalctl --disk-usage 2>/dev/null | awk '{print $7}')
echo "  ✓ Journal cleaned: $BEFORE → $AFTER"

# 7. Clean container images
echo "[7/7] Checking container images..."
OLD_IMAGES=$(podman images -f "dangling=true" -q 2>/dev/null | wc -l)
if [ "$OLD_IMAGES" -gt 0 ]; then
    echo "  🐳 Found $OLD_IMAGES dangling images"
    read -p "  Remove dangling images? [y/N] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        podman image prune -f
        echo "  ✓ Dangling images removed"
    else
        echo "  ⏭  Skipped"
    fi
else
    echo "  ✓ No dangling images"
fi

echo ""
echo "✨ Weekly cleanup complete!"
echo ""
echo "📊 Current disk usage:"
df -h / /home | tail -n +2
