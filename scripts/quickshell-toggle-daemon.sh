#!/bin/bash
# Quickshell toggle daemon — watches /tmp/quickshell-toggle via inotifywait
# Usage: Run as background process (e.g., via niri spawn-at-startup)

TOGGLE_FILE="/tmp/quickshell-toggle"
TRIGGER_FILE="$HOME/.local/state/quickshell/toggle-trigger"

# Ensure trigger file exists
mkdir -p "$(dirname "$TRIGGER_FILE")"
: > "$TRIGGER_FILE"

# Check if inotifywait is available
if ! command -v inotifywait &>/dev/null; then
    # Fallback: simple polling loop (1s interval)
    LAST_CONTENT=""
    while true; do
        if [[ -f "$TOGGLE_FILE" ]]; then
            CONTENT=$(cat "$TOGGLE_FILE" 2>/dev/null)
            if [[ "$CONTENT" != "$LAST_CONTENT" && -n "$CONTENT" ]]; then
                echo "$CONTENT" >> "$TRIGGER_FILE"
                : > "$TOGGLE_FILE"
                LAST_CONTENT="$CONTENT"
            fi
        fi
        sleep 1
    done
else
    # Use inotifywait for instant, zero-CPU monitoring
    while true; do
        inotifywait -e modify "$TOGGLE_FILE" 2>/dev/null
        CONTENT=$(cat "$TOGGLE_FILE" 2>/dev/null)
        if [[ -n "$CONTENT" ]]; then
            echo "$CONTENT" >> "$TRIGGER_FILE"
            : > "$TOGGLE_FILE"
        fi
    done
fi
