#!/bin/bash
# focus-or-spawn.sh - Focus an existing window or spawn a new one
# Supports: --app-id, -t (scratchpad), -l N (instance limit), --verbose
# Usage:
#   focus-or-spawn.sh --app-id firefox
#   focus-or-spawn.sh -t --app-id ghostty ghostty
#   focus-or-spawn.sh -l 3 --app-id obsidian obsidian

set -euo pipefail

# === OPTIONS ===
VERBOSE=0
SCRATCH=0
LIMIT=0
APP_ID=""
COMMAND=()

log() {
    if [[ "$VERBOSE" -eq 1 ]]; then
        echo "[focus-or-spawn] $*" >&2
    fi
}

die() {
    echo "[focus-or-spawn] ERROR: $*" >&2
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --verbose)
            VERBOSE=1
            shift
            ;;
        -t)
            SCRATCH=1
            shift
            ;;
        -l)
            LIMIT="$2"
            shift 2
            ;;
        --app-id)
            APP_ID="$2"
            shift 2
            ;;
        --)
            shift
            COMMAND=("$@")
            break
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            COMMAND=("$@")
            break
            ;;
    esac
done

if [[ -z "$APP_ID" ]] || [[ ${#COMMAND[@]} -eq 0 ]]; then
    die "Usage: $0 [--verbose] [-t] [-l N] --app-id <id> <command...>"
fi

# Verify Niri is running
if ! pgrep -x niri >/dev/null 2>&1; then
    die "Niri is not running"
fi

log "Looking for windows with app-id: $APP_ID"

# Get windows JSON
WINDOWS_JSON=$(niri msg --json windows 2>/dev/null) || die "Failed to query niri windows"

# Find matching windows
MATCHING_IDS=$(echo "$WINDOWS_JSON" | jq -r --arg app_id "$APP_ID" '
    [.[] | select(.app_id | contains($app_id)) | .id] | if length > 0 then .[] else empty end
')

MATCH_COUNT=$(echo "$MATCHING_IDS" | grep -c '^' || true)
if [[ -z "$MATCHING_IDS" ]]; then
    MATCH_COUNT=0
fi

log "Found $MATCH_COUNT matching window(s)"

# If we have matching windows, focus the most recently used one (first in JSON order)
if [[ "$MATCH_COUNT" -gt 0 ]]; then
    if [[ "$LIMIT" -gt 0 && "$MATCH_COUNT" -ge "$LIMIT" ]]; then
        log "Instance limit ($LIMIT) reached, focusing existing window"
    fi

    FIRST_ID=$(echo "$MATCHING_IDS" | head -n 1)
    log "Focusing window id: $FIRST_ID"
    niri msg action focus-window --id "$FIRST_ID" || die "Failed to focus window $FIRST_ID"
    exit 0
fi

# No matching window — spawn the command
log "Spawning: ${COMMAND[*]}"
"${COMMAND[@]}" &

# If scratchpad mode, wait a moment for the window to appear, then move it
if [[ "$SCRATCH" -eq 1 ]]; then
    log "Waiting for window to appear for scratchpad move..."
    for _ in {1..20}; do
        sleep 0.1
        NEW_WINDOWS_JSON=$(niri msg --json windows 2>/dev/null) || die "Failed to query niri windows"
        NEW_ID=$(echo "$NEW_WINDOWS_JSON" | jq -r --arg app_id "$APP_ID" '
            [.[] | select(.app_id | contains($app_id)) | .id] | if length > 0 then last else empty end
        ')
        if [[ -n "$NEW_ID" ]]; then
            log "Moving window $NEW_ID to workspace 'scratch'"
            niri msg action move-window-to-workspace --id "$NEW_ID" "scratch" || log "Failed to move window to scratch workspace"
            break
        fi
    done
fi

exit 0
