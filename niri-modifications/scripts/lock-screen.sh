#!/bin/bash
# NightForge lock screen launcher
# Tries lockers in order: gtklock > swaylock > simple fallback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try gtklock first (best theming support)
if command -v gtklock >/dev/null 2>&1; then
    # Random wallpaper on each lock
    BG="${HOME}/.cache/current_wallpaper"
    SPECIFIC=$(find "${HOME}/Pictures/wallpapers" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.jpeg' \) 2>/dev/null | shuf -n1)
    [ -z "$SPECIFIC" ] && SPECIFIC="${HOME}/Pictures/wallpapers/mokka-tree.jpg"
    if [ -f "$SPECIFIC" ]; then
        BG_ARG="$SPECIFIC"
    elif [ -f "$BG" ]; then
        BG_ARG="$(cat "$BG")"
    else
        BG_ARG=""
    fi
    exec gtklock \
        --style "${HOME}/Github/nightforge/dotfiles/gtklock/style.css" \
        --time-format "%H:%M" \
        --date-format "%A, %B %d" \
        --start-hidden \
        ${BG_ARG:+--background "$BG_ARG"} \
        "$@"
fi

# Fallback to swaylock-effects or swaylock
if command -v swaylock >/dev/null 2>&1; then
    exec swaylock \
        --color 1e1e2e \
        --clock \
        --datestr "%a, %b %d" \
        --font "JetBrains Mono" \
        --inside-color 313244 \
        --line-color cba6f7 \
        --ring-color cba6f7 \
        --inside-ver-color 89b4fa \
        --ring-ver-color 89b4fa \
        --inside-wrong-color f38ba8 \
        --ring-wrong-color f38ba8 \
        --key-hl-color a6e3a1 \
        --text-color cdd6f4 \
        --text-ver-color cdd6f4 \
        --text-wrong-color cdd6f4 \
        "$@"
fi

# Final fallback: notify and do nothing
echo "No lock screen tool found. Install gtklock or swaylock."
exit 1
