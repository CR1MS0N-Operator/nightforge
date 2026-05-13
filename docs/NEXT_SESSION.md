# NightForge Session Handoff — Agent Sessions Dashboard v1

## Decisions Made

| Decision | Rationale |
|----------|----------|
| File-based IPC for session-tracker | Consistent with ops-data.sh pattern — no HTTP server |
| DashboardWidget.qml tracked in dotfiles/ | Reproducible deploys, symlink to ~/.config/quickshell |
| QML tabs for Mermaid graphs | Separate views: Timeline, Tool Usage, Model Routing |
| mermaid-rs-renderer v0.2.2 | Pure Rust, 100-1400x faster than mermaid-cli |

## Completed

- **DashboardWidget.qml** — tracked in dotfiles, 6 `font.size`→`font.pixelSize` bugs fixed, `Layout.preferredHeight` binding loop resolved, 146-line Agent Sessions section added (SVG tabs + session list)
- **Rust session-tracker** — reads OpenCode `stats-pid-*.json` + Hermes `session_*.json`, generates 3 Mermaid SVGs, writes `/tmp/session-tracker.*` atomically
- **niri-modifications/README.md** — reproducible setup docs
- **opencode upgraded** — 1.14.46 → 1.14.48 via AUR

## Open Issues

### Priority 1: Dashboard Widget Text Overlapping

**Root cause:** Operations sub-rectangles have zero implicitHeight. Inner ColumnLayout uses `anchors.fill: parent` on a 0-height parent, so text overflows into the next section.

**Fix needed in `dotfiles/quickshell/.config/quickshell/modules/widgets/DashboardWidget.qml`:**

Apply this pattern to 3 sub-rectangles:

1. **Network & Environment** (line ~410):
```qml
// BEFORE:
Rectangle {
    Layout.fillWidth: true; radius: 10
    color: mocha.surface1
    ColumnLayout {
        anchors.fill: parent; anchors.margins: 12; spacing: 8
        // ...
    }
}
// AFTER:
Rectangle {
    Layout.fillWidth: true; radius: 10
    implicitHeight: networkCol.implicitHeight + 24
    color: mocha.surface1
    ColumnLayout {
        id: networkCol
        anchors.left: parent.left; anchors.right: parent.right
        anchors.top: parent.top; anchors.margins: 12
        spacing: 8
        // ...
    }
}
```

2. **Service Status** (line ~439) — same pattern, `id: svcCol`

3. **C2 Frameworks** (line ~466) — same pattern, `id: c2Col`

Also fix the Containers+VMs layout (line ~238):
```qml
// BEFORE: Layout.fillHeight: true (steals all space from Operations)
// AFTER:
Layout.fillHeight: false
Layout.preferredHeight: 250
```

This ensures Operations section gets consistent space. ListViews already scroll internally.

### Priority 2: Settings Keybinds Text Overlapping

File: `~/.config/quickshell/settings/SettingsPopup.qml` (3273 lines)
Likely same `anchors.fill: parent` pattern on zero-height containers in the `kbListView` delegate or keybinds tab layout. Needs investigation.

### Priority 3: Waterfox Video/LinkedIn Issues

- Video loading fails on cyberwarfare.live / labs.cyberwarfare.live (but YouTube works)
- LinkedIn textboxes broken
- Waterfox Phase 3-6 (hardening, codecs, userChrome) planned but not executed
- Likely cause: Enhanced Tracking Protection blocking cross-origin media or Widevine DRM not set up

## Git Commits

```
b933ad0 feat(qml): add agent sessions section with Mermaid SVG tabs to dashboard
50bd571 feat(rust): add session-tracker backend for agent session data
5dd8859 fix(qml): copy DashboardWidget.qml to repo, fix font bindings and layout loop
9d6762d docs(niri): add niri-modifications README for reproducible setup
```

Pushed to origin/main.

## Next Session Prompt

```
Continue from session handoff at docs/NEXT_SESSION.md.
Fix the Operations section text overlapping in DashboardWidget.qml.

Root cause: sub-rectangles have zero implicitHeight because inner ColumnLayout
uses anchors.fill:parent. Fix pattern: add implicitHeight: <colId>.implicitHeight + 24
to each Rectangle, change anchors.fill:parent → anchors.left/right/top:parent.

Also investigate SettingsPopup.qml keybinds overlapping (same pattern likely).
```
