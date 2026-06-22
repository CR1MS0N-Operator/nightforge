#!/bin/bash
# matugen-sync.sh - Wallpaper to theme pipeline for NightForge
# Generates colors from wallpaper, exports env vars, syncs all configs
# Usage: ./matugen-sync.sh [wallpaper_path]
# Matugen v4 syntax: matugen image <path> | matugen color hex <hex>

set -euo pipefail

# === CONFIGURATION ===
WALLPAPER="${1:-}"
FALLBACK_COLOR="${MATUGEN_FALLBACK:-#1a1b26}"
MATUGEN_BIN="/usr/sbin/matugen"
CONFIG_PATH="$HOME/.config/matugen/config.toml"
TMP_DIR="/tmp/matugen"
ENV_FILE="$HOME/.config/environment.d/98-matugen.conf"
BACKUP_DIR="$HOME/.local/share/matugen/backups"

# === FUNCTIONS ===
log_info()  { echo "[+] $*"; }
log_warn()  { echo "[!] $*"; }
log_error() { echo "[-] $*"; }

check_matugen() {
    if [[ ! -x "$MATUGEN_BIN" ]]; then
        log_error "matugen not found at $MATUGEN_BIN"
        exit 1
    fi
}

check_config() {
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log_warn "matugen config not found at $CONFIG_PATH"
        log_warn "Run: stow -d ~/nightforge/dotfiles matugen"
        return 1
    fi
    return 0
}

run_matugen() {
    local source="$1"
    mkdir -p "$TMP_DIR"

    if [[ -f "$source" ]]; then
        log_info "Generating theme from wallpaper: $source"
        "$MATUGEN_BIN" image "$source" --source-color-index 0
    else
        log_warn "No wallpaper found, using fallback color: $FALLBACK_COLOR"
        "$MATUGEN_BIN" color hex "$FALLBACK_COLOR"
    fi
}

backup_existing() {
    local file="$1"
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        local backup
        backup="$BACKUP_DIR/$(basename "$file").$(date +%Y%m%d_%H%M%S)"
        cp "$file" "$backup"
        log_info "Backed up $(basename "$file")"
    fi
}

# Generic copy helper with null-safe fallback
copy_generated() {
    local generated="$1"
    local target="$2"
    local description="${3:-$(basename "$target")}"

    if [[ ! -f "$generated" ]]; then
        log_warn "$description not generated, skipping"
        return
    fi

    mkdir -p "$(dirname "$target")"

    # If target is a symlink, remove it so we don't overwrite the source
    if [[ -L "$target" ]]; then
        rm "$target"
    fi

    backup_existing "$target"
    cp "$generated" "$target"
    log_info "Updated $description"
}

# Append ghostty colors as a block
append_ghostty_colors() {
    local ghostty_config="$HOME/.config/ghostty/config"
    local generated="$TMP_DIR/ghostty-colors.conf"

    if [[ ! -f "$generated" ]]; then
        log_warn "ghostty colors not generated, skipping"
        return
    fi

    mkdir -p "$(dirname "$ghostty_config")"

    # Remove old matugen block if present
    if [[ -f "$ghostty_config" ]]; then
        local tmp_ghostty
        tmp_ghostty="$(mktemp)"
        awk '/^# === Matugen Colors BEGIN ===$/{skip=1;next} /^# === Matugen Colors END ===$/{skip=0;next} !skip{print}' "$ghostty_config" > "$tmp_ghostty"
        mv "$tmp_ghostty" "$ghostty_config"
    fi

    # Append new block
    {
        echo ""
        echo "# === Matugen Colors BEGIN ==="
        cat "$generated"
        echo "# === Matugen Colors END ==="
    } >> "$ghostty_config"

    log_info "Updated ghostty config"
}

# Append starship colors as a block (preserves base config)
append_starship_colors() {
    local starship_config="$HOME/.config/starship.toml"
    local generated="$TMP_DIR/starship-colors.toml"

    if [[ ! -f "$generated" ]]; then
        log_warn "starship colors not generated, skipping"
        return
    fi

    mkdir -p "$(dirname "$starship_config")"

    # Remove old matugen block if present
    if [[ -f "$starship_config" ]]; then
        local tmp_starship
        tmp_starship="$(mktemp)"
        awk '/^# === Matugen Colors BEGIN ===$/{skip=1;next} /^# === Matugen Colors END ===$/{skip=0;next} !skip{print}' "$starship_config" > "$tmp_starship"
        mv "$tmp_starship" "$starship_config"
    fi

    # Append new block
    {
        echo ""
        echo "# === Matugen Colors BEGIN ==="
        cat "$generated"
        echo "# === Matugen Colors END ==="
    } >> "$starship_config"

    log_info "Updated starship config"
}

# Inject fastfetch colors into user's config.jsonc (preserves dice art and other settings)
inject_fastfetch_colors() {
    local config="$HOME/.config/fastfetch/config.jsonc"
    local generated="$TMP_DIR/fastfetch-config.jsonc"

    if [[ ! -f "$generated" ]]; then
        log_warn "fastfetch colors not generated, skipping"
        return
    fi

    mkdir -p "$(dirname "$config")"

    # Remove dangling symlink before writing
    if [[ -L "$config" && ! -e "$config" ]]; then
        rm "$config"
    fi

    if [[ ! -f "$config" ]]; then
        cp "$generated" "$config"
        log_info "Created fastfetch config"
        return
    fi

    python3 -c "
import json, re

with open('$generated') as f:
    colors = json.load(f)

with open('$config') as f:
    content = f.read()

# Strip JSONC comments for parsing
clean = re.sub(r'//.*', '', content)
clean = re.sub(r'/\*.*?\*/', '', clean, flags=re.DOTALL)
data = json.loads(clean)

# Merge colors
if 'logo' not in data:
    data['logo'] = {}
if 'display' not in data:
    data['display'] = {}

data['logo']['color'] = colors.get('logo', {}).get('color', {})
data['display']['color'] = colors.get('display', {}).get('color', {})

with open('$config', 'w') as f:
    json.dump(data, f, indent=4)
"

    log_info "Updated fastfetch config"
}

export_env_vars() {
    local colors_json="$TMP_DIR/colors.json"

    if [[ ! -f "$colors_json" ]]; then
        log_warn "nightforge-colors.json not generated, skipping env export"
        return
    fi

    # Null-safe jq parsing: if key missing, outputs empty string
    local primary surface on_surface outline surface_variant error secondary tertiary
    primary=$(jq -r '.colors.primary // empty' "$colors_json" 2>/dev/null || true)
    surface=$(jq -r '.colors.surface // empty' "$colors_json" 2>/dev/null || true)
    on_surface=$(jq -r '.colors.onSurface // empty' "$colors_json" 2>/dev/null || true)
    outline=$(jq -r '.colors.outline // empty' "$colors_json" 2>/dev/null || true)
    surface_variant=$(jq -r '.colors.surfaceVariant // empty' "$colors_json" 2>/dev/null || true)
    error=$(jq -r '.colors.error // empty' "$colors_json" 2>/dev/null || true)
    secondary=$(jq -r '.colors.secondary // empty' "$colors_json" 2>/dev/null || true)
    tertiary=$(jq -r '.colors.tertiary // empty' "$colors_json" 2>/dev/null || true)

    mkdir -p "$(dirname "$ENV_FILE")"
    backup_existing "$ENV_FILE"

    {
        echo "# Matugen colors — generated $(date +%Y-%m-%d_%H:%M:%S)"
        echo "MATUGEN_COLORS=$TMP_DIR/colors.json"
        echo "MATUGEN_QS_COLORS=/tmp/qs_colors.json"
        [[ -n "$primary" ]] && echo "MATUGEN_PRIMARY=$primary"
        [[ -n "$surface" ]] && echo "MATUGEN_SURFACE=$surface"
        [[ -n "$on_surface" ]] && echo "MATUGEN_ON_SURFACE=$on_surface"
        [[ -n "$outline" ]] && echo "MATUGEN_OUTLINE=$outline"
        [[ -n "$surface_variant" ]] && echo "MATUGEN_SURFACE_VARIANT=$surface_variant"
        [[ -n "$error" ]] && echo "MATUGEN_ERROR=$error"
        [[ -n "$secondary" ]] && echo "MATUGEN_SECONDARY=$secondary"
        [[ -n "$tertiary" ]] && echo "MATUGEN_TERTIARY=$tertiary"
    } > "$ENV_FILE"

    log_info "Exported colors to $ENV_FILE"
}

# === MAIN ===
check_matugen
check_config || true  # warn but don't exit

# Resolve wallpaper path
if [[ -z "$WALLPAPER" ]]; then
    WALLPAPER="${HOME}/.cache/current_wallpaper"
    if [[ -f "$WALLPAPER" ]]; then
        WALLPAPER=$(cat "$WALLPAPER")
    else
        WALLPAPER=""
    fi
fi

run_matugen "$WALLPAPER"

# --- Quickshell Colors ---
# Transform matugen output (Material Design) → Catppuccin-like format for QML
if [[ -f "$TMP_DIR/colors.json" ]]; then
    jq -r '
    .colors as $c |
    {
        "base":        ($c.surface // "#1e1e2e"),
        "mantle":      ($c.surface // "#181825"),
        "crust":       ($c.surfaceVariant // "#11111b"),
        "text":        ($c.onSurface // "#cdd6f4"),
        "subtext0":    ($c.onSurface // "#a6adc8"),
        "subtext1":    ($c.onSurface // "#bac2de"),
        "surface0":    ($c.surfaceVariant // "#313244"),
        "surface1":    ($c.surfaceVariant // "#45475a"),
        "surface2":    ($c.outline // "#585b70"),
        "overlay0":    ($c.outline // "#6c7086"),
        "overlay1":    ($c.outline // "#7f849c"),
        "overlay2":    ($c.outline // "#9399b2"),
        "blue":        ($c.secondary // "#89b4fa"),
        "sapphire":    ($c.secondary // "#74c7ec"),
        "peach":       ($c.tertiary // "#fab387"),
        "green":       ($c.tertiary // "#a6e3a1"),
        "red":         ($c.error // "#f38ba8"),
        "mauve":       ($c.primary // "#cba6f7"),
        "pink":        ($c.primary // "#f5c2e7"),
        "yellow":      ($c.tertiary // "#f9e2af"),
        "maroon":      ($c.error // "#eba0ac"),
        "teal":        ($c.tertiary // "#94e2d5")
    }' "$TMP_DIR/colors.json" > /tmp/qs_colors.json
    log_info "Transformed matugen colors → /tmp/qs_colors.json"
else
    log_warn "colors.json not generated, /tmp/qs_colors.json not updated"
fi

# --- Niri Window Border Colors ---
if [[ -f "$TMP_DIR/colors.json" ]]; then
    active_color=$(jq -r '.colors.primary // "#cba6f7"' "$TMP_DIR/colors.json")
    inactive_color=$(jq -r '.colors.surfaceVariant // "#313244"' "$TMP_DIR/colors.json")
    cat > "$HOME/.config/niri/includes/colors.kdl" << NIRI_EOF
// Auto-generated by matugen-sync.sh — do not edit
layout {
    border {
        width 0
        // Colors stored for future use if border is re-enabled
        active-color "$active_color"
        inactive-color "$inactive_color"
    }
}
NIRI_EOF
    log_info "Updated niri window border colors (active: $active_color)"
fi

# --- Fuzzel Launcher Colors ---
if [[ -f "$TMP_DIR/colors.json" ]]; then
    bg=$(jq -r '.colors.surface // "#1e1e2e"' "$TMP_DIR/colors.json" | sed 's/^#//')
    fg=$(jq -r '.colors.onSurface // "#cdd6f4"' "$TMP_DIR/colors.json" | sed 's/^#//')
    accent=$(jq -r '.colors.primary // "#cba6f7"' "$TMP_DIR/colors.json" | sed 's/^#//')
    match=$(jq -r '.colors.tertiary // "#fab387"' "$TMP_DIR/colors.json" | sed 's/^#//')
    cat > "$HOME/.config/fuzzel/colors.ini" << FUZZEL_EOF
[colors]
background=${bg}a6
text=${fg}ff
prompt=${accent}ff
placeholder=6C7086aa
input=${fg}ff
match=${match}ff
selection=${accent}33
selection-text=${fg}ff
selection-match=${match}ff
border=${accent}77
FUZZEL_EOF
    log_info "Updated fuzzel launcher colors (accent: #${accent})"
fi

# --- Firefox Browser Theme ---
if [[ -f "$TMP_DIR/colors.json" ]]; then
    base=$(jq -r '.colors.surface // "#1e1e2e"' "$TMP_DIR/colors.json")
    mantle=$(jq -r '.colors.surface // "#181825"' "$TMP_DIR/colors.json")
    crust=$(jq -r '.colors.surfaceVariant // "#11111b"' "$TMP_DIR/colors.json")
    text=$(jq -r '.colors.onSurface // "#cdd6f4"' "$TMP_DIR/colors.json")
    surface0=$(jq -r '.colors.surfaceVariant // "#313244"' "$TMP_DIR/colors.json")
    surface1=$(jq -r '.colors.outline // "#45475a"' "$TMP_DIR/colors.json")
    overlay0=$(jq -r '.colors.outline // "#6c7086"' "$TMP_DIR/colors.json")
    mauve=$(jq -r '.colors.primary // "#cba6f7"' "$TMP_DIR/colors.json")
    profile=$(find "$HOME/.mozilla/firefox/" -maxdepth 1 -name '*.default-release' -print -quit 2>/dev/null)
    
    if [[ -n "$profile" ]]; then
        cat > "$profile/chrome/userChrome.css" << FOX_EOF
/* NightForge Firefox Theme — Auto-generated by matugen-sync.sh */
:root {
  --nf-base: $base;
  --nf-mantle: $mantle;
  --nf-crust: $crust;
  --nf-text: $text;
  --nf-subtext0: $text;
  --nf-surface0: $surface0;
  --nf-surface1: $surface1;
  --nf-overlay0: $overlay0;
  --nf-mauve: $mauve;
}
.tabbrowser-tab[selected] .tab-background { background-color: $mauve !important; }
.tabbrowser-tab[selected] .tab-label { color: $base !important; }
#urlbar-background { background-color: $surface0 !important; border-color: $overlay0 !important; }
#urlbar:focus-within #urlbar-background { border-color: $mauve !important; }
#nav-bar { background-color: $mantle !important; }
#sidebar-box { background-color: $base !important; }
menupopup, .panel-arrowcontent { background-color: $surface0 !important; color: $text !important; }
#PersonalToolbar { background-color: $mantle !important; }
:root { scrollbar-color: $surface1 $base !important; }
*::selection { background-color: $mauve !important; color: $base !important; }
FOX_EOF
        log_info "Updated Firefox browser theme"
    fi
fi

# --- Core outputs ---
append_ghostty_colors
copy_generated "$TMP_DIR/rofi-theme.rasi" "$HOME/.config/rofi/matugen-theme.rasi" "rofi theme"
copy_generated "$TMP_DIR/gtk-colors.css" "$HOME/.cache/matugen/colors-gtk.css" "gtk colors"

# --- Terminal / Editor ---
copy_generated "$TMP_DIR/nvim-colors.lua" "$HOME/.config/nvim/lua/matugen-theme.lua" "neovim colors"

# --- Qt theming ---
copy_generated "$TMP_DIR/qt5ct-colors.conf" "$HOME/.config/qt5ct/colors/matugen.conf" "qt5ct colors"
copy_generated "$TMP_DIR/qt6ct-colors.conf" "$HOME/.config/qt6ct/colors/matugen.conf" "qt6ct colors"
copy_generated "$TMP_DIR/qt5-style.qss" "$HOME/.config/qt5ct/qss/matugen-style.qss" "qt5 style"
copy_generated "$TMP_DIR/qt6-style.qss" "$HOME/.config/qt6ct/qss/matugen-style.qss" "qt6 style"

# --- System UI ---
copy_generated "$TMP_DIR/cava-colors.ini" "$HOME/.config/cava/colors" "cava colors"
copy_generated "$TMP_DIR/swayosd-style.css" "$HOME/.config/swayosd/style.css" "swayosd style"
copy_generated "$TMP_DIR/mako.config" "$HOME/.config/mako/config" "mako config"
copy_generated "$TMP_DIR/hyprlock.conf" "$HOME/.config/hyprlock/hyprlock.conf" "hyprlock config"

# --- Shell / Prompt ---
copy_generated "$TMP_DIR/btop-colors.theme" "$HOME/.config/btop/themes/nightforge.theme" "btop theme"
if [[ -f "$HOME/.config/btop/btop.conf" ]]; then
    sed -i 's/^color_theme = .*/color_theme = "nightforge"/' "$HOME/.config/btop/btop.conf"
    log_info "Set btop color_theme to nightforge"
fi
append_starship_colors
inject_fastfetch_colors

export_env_vars

log_info "Matugen sync complete"
