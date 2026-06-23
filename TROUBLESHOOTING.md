# NightForge Troubleshooting

## Quickshell

### "Too many open files" / Process crash
**Symptom:** Quickshell crashes with GLib-ERROR "Creating pipes for GWakeup: Too many open files"
**Root cause:** A Process element polling too frequently (every 1s) reading a non-existent file, or a watcher script referencing a wrong path
**Fix:**
```bash
# Check for leaking processes
lsof -p $(pgrep -x quickshell) | wc -l
# Common culprits: MatugenColors (polling), Scaler (settings watcher)
# Check for wrong script paths
grep -rn "/quickshell/quickshell/" ~/.config/quickshell/
```
**Prevention:** Set reasonable polling intervals (>2s), ensure all script paths exist

### IPC command processed twice
**Symptom:** Widget flashes on screen then disappears
**Root cause:** IPC command processed twice — once by ipcWatcher (inotifywait) and once by ipcPoller (timer)
**Fix:** Ensure only one IPC method is active. Check which is enabled in the Quickshell config.

---

## Niri Compositor

### Blue window borders / focus ring visible
**Symptom:** Windows have a blue border or visible focus ring despite being disabled
**Root cause:** The nightforge `compositor.kdl` has `border { width 0 }` instead of `border { off }` and is missing `focus-ring { off }`
**Fix:**
```bash
# Replace width 0 with off for borders
sed -i 's/        width 0/        off/' ~/.config/niri/includes/compositor.kdl
# Add focus-ring block after shadow block if missing
# Edit compositor.kdl and add inside the layout block after shadows
```
**Prevention:** After any `git checkout` of compositor.kdl from nightforge, run the sed command above.

### Niri config invalid after changes
**Symptom:** `niri validate` shows parse errors
**Root cause:** `focus-ring { }` must be inside the `layout { }` block, not at file level
**Fix:** Move focus-ring inside layout block, after the shadow section
**Verify:** Run `niri validate` — should print "config is valid" with no errors

---

## Kitty Terminal

### Not transparent or wrong colors
**Symptom:** Kitty has solid background instead of transparent, or colors are wrong
**Root cause:** 
1. Kitty is not running (`pgrep -a kitty` returns nothing)
2. matugen colors haven't been regenerated
**Fix:**
```bash
# Launch Kitty
kitty &
# Regenerate matugen colors
~/.local/bin/matugen-sync.sh
```
**Verify:** Kitty window should show transparency (background_opacity 0.95) with matugen-themed colors

### Kitty config symlink broken
**Symptom:** Kitty loses all config
**Root cause:** Config file at `~/.config/kitty/kitty.conf` is deleted or replaced
**Fix:**
```bash
ls -la ~/.config/kitty/kitty.conf  # Check if symlink exists
# If broken, restore from backup or nightforge
cp ~/.config/kitty/kitty.conf.bak ~/.config/kitty/kitty.conf 2>/dev/null
kitty --reload-in=all
```

---

## Ghostty

### Config reverts to non-transparent / wrong settings
**Symptom:** Ghostty loses transparency, window decoration settings, or matugen colors
**Root cause:** `matugen-sync.sh` uses `mv` in its `append_ghostty_colors()` function, which replaces the symlink with a regular file
**Fix:**
```bash
# Restore the symlink
rm -f ~/.config/ghostty/config
ln -s ~/Github/nightforge/dotfiles/ghostty/.config/ghostty/config ~/.config/ghostty/config
# Re-inject matugen colors through the symlink
~/.local/bin/matugen-sync.sh
# Restart Ghostty (close + reopen)
```
**Permanent fix:** Edit `~/.local/bin/matugen-sync.sh` — change `mv "$tmp_ghostty" "$ghostty_config"` to `cp "$tmp_ghostty" "$ghostty_config"` in the `append_ghostty_colors()` function.
**Prevention:** After every wallpaper rotation (matugen run), check that Ghostty config is still a symlink: `stat -c '%F' ~/.config/ghostty/config` should say "symbolic link".

---

## Agent Tools

### Codex CLI returns 401 "User not found"
**Symptom:** Codex interactive mode fails with 401 on `/api/v1/responses`
**Root cause:** Stale cached goal in `~/.codex/attachments/`
**Fix:**
```bash
rm -rf ~/.codex/attachments/*
```
**Prevention:** Use `codex exec "prompt"` instead of interactive mode for fresh sessions.

### OMP returns 401 "User not found"
**Symptom:** OMP fails immediately with 401
**Root cause:** OpenRouter guardrail blocking the request. Has occurred intermittently since S037.
**Fix:**
```bash
# Pass API key explicitly
omp -p "prompt" --api-key "$OPENROUTER_API_KEY"
```
**Alternative:** Switch OMP to OpenCode API by setting `OPENCODE_GO_API_KEY` env var.

### Hermes compression fails with 401
**Symptom:** "Compression aborted: Error code: 401"
**Root cause:** Compression auxiliary model uses `qwen2.5-coder:3b` on OpenRouter — not a valid OpenRouter model ID
**Fix:**
```bash
hermes config set compression.enabled false
```
**Rationale:** Daily driver model has 1M+ context window — compression is unnecessary.

### "GlassPanel is not a type" error
**Symptom:** Widget fails to load, GlassPanel component not found
**Root cause:** Missing `qmldir` in `components/` directory — QML engine can't resolve the import
**Fix:** Create `components/qmldir` with:
```
GlassPanel 1.0 GlassPanel.qml
```

### "FolderListModel is not defined"
**Symptom:** Wallpaper picker grid doesn't load
**Root cause:** Quickshell blocks `Qt.labs.folderlistmodel` import
**Fix:** Replaced with Process-based scanner using `find` command + ListModel

### QML cache issues
**Symptom:** Changes to .qml files don't take effect after restart
**Fix:**
```bash
rm -rf ~/.cache/quickshell/qmlcache/
pkill quickshell
```

## Niri

### Blue border/tint on focused window
**Symptom:** Active window has a blue border or blue tint that won't go away
**Root cause:** Niri's built-in window decoration/focus indicator. Controlled by `border` setting but may still show even with `width 0`
**Check:**
```bash
niri validate
grep -A5 "border" ~/.config/niri/includes/compositor.kdl
cat ~/.config/niri/includes/colors.kdl
```
**Fix:** Set both to `width 0` with transparent colors. If still visible, it's Niri's hardcoded focus ring — not configurable.

### Config validation error: "unexpected node border"
**Symptom:** `niri validate` fails on `border` in colors.kdl
**Root cause:** `colors.kdl` has `border` at top level but it's inside `layout {}` in compositor.kdl
**Fix:** Wrap border in `layout { }`:
```kdl
layout {
    border {
        width 0
    }
}
```

## Audio

### No sound from speakers (ALC897 codec)
**Symptom:** Audio sink shows 100% volume, unmuted, but no sound
**Root cause:** ALC897 codec hardware jack detection — Headphone channel at 0% or analog profile not selected
**Diagnosis:**
```bash
~/audio-diag.sh
amixer | grep Headphone
cat /proc/asound/card0/codec#0 | grep "Pin Default" | grep "Line Out"
```
**Fix:**
```bash
# Check if Headphone is muted/zero
amixer set Headphone unmute
amixer set Headphone 87%
# Or use hdajackretask
sudo pacman -S alsa-tools
hdajackretask  # Override pin 0x14 to "Line Out"
```

### Browser audio not playing
**Symptom:** MPD audio works, Firefox/YouTube doesn't
**Check:**
```bash
pactl list sink-inputs | grep -E "application.name|sink:"
# Move Firefox to active sink
pactl move-sink-input <input-id> <sink-id>
```
**Fix:** Firefox may be routed to different sink. Set default:
```bash
wpctl set-default <sink-id>
```

## Firefox

### MPRIS not working (music widget doesn't show browser audio)
**Check:**
```bash
playerctl -l  # Should show firefox
```
**Fix:** Enable in about:config: `media.hardwaremediakeys.enabled = true`

### Firefox not using Wayland
**Check:**
```bash
grep -c "Wayland" ~/.mozilla/firefox/*.default-release/user.js
```
**Fix:** Use the Wayland wrapper:
```bash
~/.local/bin/firefox-wayland.sh
```
Or set env vars: `MOZ_ENABLE_WAYLAND=1 GDK_BACKEND=wayland`

## Environment

### Zsh startup slow (>100ms)
**Symptom:** Terminal takes noticeable time to start
**Diagnosis:**
```bash
time zsh -i -c exit
```
**Fix:** Check Zinit plugins for sync loading. Ensure autosuggestions and syntax-highlighting are turbo-loaded.
Current startup: ~0.08s on warmed cache (first run ~3s due to cmatrix splash).

### Starship not showing
**Symptom:** No prompt or default zsh prompt
**Fix:**
```bash
eval "$(starship init zsh)"
```
Should be in `~/.zshrc`.

## General

### "sudo: a terminal is required" error
**Symptom:** sudo commands in scripts fail
**Root cause:** Scripts running in non-interactive context
**Fix:** Prefer `sudo` commands that prompt via UI, or use `pkexec` for GUI dialogs. For automation, consider passwordless sudo for specific commands.

### CPU 0% in system info
**Symptom:** Bar shows CPU: 0%
**Root cause:** `top -bn1` output format differs across systems. The awk parsing uses `%Cpu` pattern and column 8 (idle).
**Fix:** Test locally:
```bash
top -bn1 | grep '%Cpu' | awk '{print int(100-$8)}'
```

### Clipboard history stale
**Symptom:** `Mod+V` shows old clipboard items
**Fix:** Ensure cliphist daemon is running:
```bash
systemctl --user status cliphist.service
# Restart if needed:
systemctl --user restart cliphist.service
```
