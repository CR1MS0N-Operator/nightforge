#!/usr/bin/env python3
"""Parses Niri KDL keybind configs and outputs JSON for Quickshell."""
import json, sys, re, os

def humanize(action, args):
    a = action
    arg = args.strip().strip('"')
    if a == "spawn":
        parts = [p.strip('"') for p in re.findall(r'"[^"]*"|\S+', arg)]
        cmd = parts[0] if parts else arg
        rest = " ".join(parts[1:]) if len(parts) > 1 else ""
        if rest:
            return "Run: " + cmd + " " + rest
        return "Run: " + cmd
    mapping = {
        "close-window": "Close window",
        "toggle-overview": "Toggle overview",
        "toggle-window-floating": "Toggle floating",
        "maximize-column": "Maximize column",
        "center-column": "Center column",
        "center-window": "Center window",
        "focus-column-left": "Focus left",
        "focus-column-right": "Focus right",
        "focus-window-or-workspace-down": "Focus down",
        "focus-window-or-workspace-up": "Focus up",
        "focus-workspace-previous": "Prev workspace",
        "focus-workspace-down": "Workspace down",
        "focus-workspace-up": "Workspace up",
        "move-column-left": "Move left",
        "move-column-right": "Move right",
        "move-window-down-or-to-workspace-down": "Move down",
        "move-window-up-or-to-workspace-up": "Move up",
        "switch-preset-column-width": "Cycle column width",
        "move-column-to-monitor-left": "Move to monitor L",
        "move-column-to-monitor-right": "Move to monitor R",
        "focus-monitor-left": "Focus monitor L",
        "focus-monitor-right": "Focus monitor R",
        "consume-or-expel-window-left": "Consume/expel left",
        "consume-or-expel-window-right": "Consume/expel right",
        "expel-window-from-column": "Expel from column",
        "toggle-column-tabbed-display": "Toggle tabbed",
        "screenshot": "Screenshot",
        "screenshot-window": "Screenshot window",
        "show-hotkey-overlay": "Hotkey overlay",
        "quit": "Quit niri",
    }
    if a in mapping:
        return mapping[a]
    if a == "focus-workspace":
        return "Workspace " + arg.strip('"')
    if a == "move-column-to-workspace":
        return "Move to ws " + arg.strip('"')
    if a == "set-window-width":
        return "Resize width " + arg.strip('"')
    if a == "set-window-height":
        return "Resize height " + arg.strip('"')
    return (a + " " + arg.strip('"')).strip()

def parse_keybinds(filepath):
    entries = []
    current_section = "Keybinds"
    in_binds = False
    try:
        with open(filepath, "r") as f:
            for line in f:
                stripped = line.strip()
                if not stripped:
                    continue
                if stripped.startswith("//"):
                    sec = re.search(r'===+\s*(.+?)\s*===+', stripped)
                    if sec:
                        current_section = sec.group(1).strip()
                    continue
                if stripped == "binds {":
                    in_binds = True
                    continue
                if stripped == "}" and in_binds:
                    in_binds = False
                    continue
                if not in_binds:
                    continue
                key_m = re.match(r'^([\w+_-]+)', stripped)
                if not key_m:
                    continue
                key_combo = key_m.group(1)
                action_m = re.search(r'\{(.+?)\}', stripped)
                if not action_m:
                    continue
                action_str = action_m.group(1).strip().rstrip(";").strip()
                if action_str.startswith("spawn"):
                    rest = action_str[5:].strip()
                    action_name = "spawn"
                    action_args = rest
                else:
                    parts = action_str.split(None, 1)
                    action_name = parts[0] if parts else action_str
                    action_args = parts[1] if len(parts) > 1 else ""
                human = humanize(action_name, action_args)
                entries.append({
                    "key": key_combo,
                    "action": human,
                    "section": current_section,
                    "type": "bind",
                    "mods": "",
                    "dispatcher": action_name,
                    "command": action_args
                })
    except FileNotFoundError:
        pass
    return entries

if __name__ == "__main__":
    niri_dir = os.path.expanduser("~/.config/niri")
    keybinds_file = os.path.join(niri_dir, "includes", "keybinds.kdl")
    entries = parse_keybinds(keybinds_file)
    print(json.dumps(entries, ensure_ascii=False))