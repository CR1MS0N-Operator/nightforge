#!/usr/bin/env python3
"""Parses startup entries from Niri config and systemd user services."""
import json, sys, os, re, subprocess

def parse_niri_spawn(filepath):
    entries = []
    try:
        with open(filepath, "r") as f:
            for line in f:
                stripped = line.strip()
                if not stripped.startswith("spawn-at-startup"):
                    continue
                m = re.match(r'^spawn-at-startup\s+(.+)$', stripped)
                if not m:
                    continue
                args_str = m.group(1).strip()
                parts = [p.strip('"') for p in re.findall(r'"[^"]*"|\S+', args_str)]
                if not parts:
                    continue
                cmd = " ".join(parts)
                name = ""
                if parts[0] in ("bash", "sh") and "-c" in parts:
                    idx = parts.index("-c")
                    if idx + 1 < len(parts):
                        shell_cmd = parts[idx + 1]
                        cleaned = re.sub(r'^sleep\s+\d+\s*&&\s*', '', shell_cmd)
                        cleaned = cleaned.split("&")[0].strip()
                        if "quickshell" in cleaned and "TopBar" not in cleaned:
                            name = "Quickshell overlay"
                        elif "TopBar" in cleaned:
                            name = "Quickshell TopBar"
                        elif "matugen" in cleaned.lower():
                            name = "Theme sync (Matugen)"
                        elif "dbus" in cleaned.lower():
                            name = "DBus env activation"
                        else:
                            name = cleaned.split()[0] if cleaned.split() else cleaned[:40]
                            base = os.path.basename(name)
                            if base:
                                name = base
                elif parts[0] == "systemctl":
                    svc = parts[-1] if parts[-1].endswith((".service", ".timer")) else parts[-1]
                    if "podman" in svc:
                        name = "Podman auto-restart"
                    elif "wallpaper" in svc:
                        name = "Wallpaper rotation timer"
                    elif "mpd" in svc:
                        name = "MPD music daemon"
                    else:
                        name = svc.replace(".service", "").replace(".timer", "")
                elif parts[0] == "awww-daemon":
                    name = "Wallpaper daemon (awww)"
                else:
                    name = os.path.basename(parts[0])
                entries.append({
                    "name": name,
                    "command": cmd,
                    "source": "niri"
                })
    except FileNotFoundError:
        pass
    return entries

def parse_systemd():
    entries = []
    try:
        result = subprocess.run(
            ["systemctl", "--user", "list-unit-files", "--state=enabled", "--no-legend", "--type=service"],
            capture_output=True, text=True, timeout=10
        )
        for line in result.stdout.strip().split("\n"):
            if not line.strip():
                continue
            parts = line.split()
            if not parts:
                continue
            unit_name = parts[0]
            if not unit_name.endswith(".service"):
                continue
            name = unit_name.replace(".service", "")
            desc = name
            try:
                prop_result = subprocess.run(
                    ["systemctl", "--user", "show", unit_name, "--property=Description", "--value"],
                    capture_output=True, text=True, timeout=5
                )
                if prop_result.stdout.strip():
                    desc = prop_result.stdout.strip()
            except Exception:
                pass
            entries.append({
                "name": desc,
                "command": "systemctl --user start " + unit_name,
                "source": "systemd"
            })
    except Exception:
        pass
    return entries

def parse_autostart():
    entries = []
    autostart_dir = os.path.expanduser("~/.config/autostart")
    if not os.path.isdir(autostart_dir):
        return entries
    for fname in os.listdir(autostart_dir):
        if not fname.endswith(".desktop"):
            continue
        fpath = os.path.join(autostart_dir, fname)
        name = fname.replace(".desktop", "")
        exec_cmd = ""
        try:
            with open(fpath, "r") as f:
                for line in f:
                    line = line.strip()
                    if line.startswith("Name="):
                        name = line.split("=", 1)[1]
                    elif line.startswith("Exec="):
                        exec_cmd = line.split("=", 1)[1]
        except Exception:
            continue
        if exec_cmd:
            entries.append({
                "name": name,
                "command": exec_cmd,
                "source": "autostart"
            })
    return entries

if __name__ == "__main__":
    niri_config = os.path.expanduser("~/.config/niri/config.kdl")
    all_entries = []
    all_entries.extend(parse_niri_spawn(niri_config))
    all_entries.extend(parse_systemd())
    all_entries.extend(parse_autostart())
    print(json.dumps(all_entries, ensure_ascii=False))