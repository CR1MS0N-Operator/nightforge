#!/bin/bash
# Keybind cheat sheet — NightForge
# Source of truth: ~/.config/niri/includes/keybinds.kdl
# Aliases source: ~/.config/zsh/aliases.zsh

CHEATSHEET="/tmp/niri-keybinds.html"
MATUGEN_CSS="$HOME/.config/matugen/colors.css"

if [[ -f "$MATUGEN_CSS" ]]; then
    BG=$(grep -oP '(?<=background: )#[0-9a-fA-F]{6}' "$MATUGEN_CSS" | head -1 || echo "#0D0F1A")
    FG=$(grep -oP '(?<=foreground: )#[0-9a-fA-F]{6}' "$MATUGEN_CSS" | head -1 || echo "#E6EAF0")
    ACCENT=$(grep -oP '(?<=primary: )#[0-9a-fA-F]{6}' "$MATUGEN_CSS" | head -1 || echo "#8B6FEF")
else
    BG="#0D0F1A"
    FG="#E6EAF0"
    ACCENT="#8B6FEF"
fi

cat > "$CHEATSHEET" << HTML
<!DOCTYPE html>
<html>
<head>
    <title>NightForge Keybind Reference</title>
    <style>
        * { box-sizing: border-box; margin: 0; padding: 0; }
        body {
            font-family: 'JetBrains Mono', 'Fira Code', monospace;
            background: ${BG};
            color: ${FG};
            padding: 24px;
            max-width: 1400px;
            margin: 0 auto;
            font-size: 13px;
        }
        h1 { color: ${ACCENT}; border-bottom: 2px solid ${ACCENT}; padding-bottom: 10px; margin-bottom: 4px; font-size: 1.3rem; }
        .subtitle { opacity: 0.45; font-size: 0.78rem; margin-bottom: 24px; }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 0 48px; }
        h2 { color: ${ACCENT}; margin: 24px 0 8px 0; font-size: 0.78rem; text-transform: uppercase; letter-spacing: 0.1em; opacity: 0.85; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 4px; }
        th, td { padding: 6px 8px; text-align: left; border-bottom: 1px solid rgba(255,255,255,0.06); }
        th { background: rgba(255,255,255,0.04); color: ${ACCENT}; font-size: 0.72rem; text-transform: uppercase; letter-spacing: 0.05em; }
        .k {
            background: rgba(255,255,255,0.1);
            padding: 2px 6px;
            border-radius: 3px;
            font-weight: bold;
            color: ${ACCENT};
            white-space: nowrap;
            font-size: 0.78rem;
        }
        .cmd { color: ${ACCENT}; opacity: 0.85; font-size: 0.78rem; }
        .note { background: rgba(255,255,255,0.04); padding: 5px 10px; margin: 6px 0 10px 0; border-left: 3px solid ${ACCENT}; font-size: 0.78rem; opacity: 0.75; }
        footer { margin-top: 32px; text-align: center; opacity: 0.3; font-size: 0.72rem; }
    </style>
</head>
<body>
    <h1>NightForge Keybind Reference</h1>
    <p class="subtitle">Niri + DMS &nbsp;·&nbsp; ~/.config/niri/includes/keybinds.kdl</p>

    <div class="grid">
    <div>

    <h2>Navigation</h2>
    <div class="note">Mod+J/K: focus window if present, else switch workspace</div>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">Mod+H / L</span></td><td>Focus column left / right</td></tr>
        <tr><td><span class="k">Mod+J / K</span></td><td>Focus down/up or workspace down/up</td></tr>
        <tr><td><span class="k">Mod+U / I</span></td><td>Workspace previous / next</td></tr>
        <tr><td><span class="k">Mod+1–5</span></td><td>Focus workspace 1–5</td></tr>
        <tr><td><span class="k">Mod+Tab</span></td><td>Next workspace</td></tr>
        <tr><td><span class="k">Mod+Space</span></td><td>Toggle overview</td></tr>
        <tr><td><span class="k">Mod+Alt+Left / Right</span></td><td>Focus monitor left / right</td></tr>
    </table>

    <h2>Window Movement</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">Mod+Shift+H / L</span></td><td>Move column left / right</td></tr>
        <tr><td><span class="k">Mod+Shift+J / K</span></td><td>Move window down/up or to workspace</td></tr>
        <tr><td><span class="k">Mod+Shift+Left / Right</span></td><td>Move column to monitor left / right</td></tr>
        <tr><td><span class="k">Mod+Shift+1–5</span></td><td>Move column to workspace 1–5</td></tr>
    </table>

    <h2>Window Management</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">Mod+Q</span></td><td>Close window</td></tr>
        <tr><td><span class="k">Mod+Shift+Space</span></td><td>Float window</td></tr>
        <tr><td><span class="k">Mod+G</span></td><td>Toggle float</td></tr>
        <tr><td><span class="k">Mod+Shift+F</span></td><td>Fullscreen</td></tr>
        <tr><td><span class="k">Mod+Shift+X</span></td><td>Maximize column</td></tr>
        <tr><td><span class="k">Mod+W</span></td><td>Toggle tabbed display</td></tr>
        <tr><td><span class="k">Mod+C</span></td><td>Center column</td></tr>
        <tr><td><span class="k">Mod+Alt+C</span></td><td>Center window</td></tr>
        <tr><td><span class="k">Mod+R</span></td><td>Cycle preset column widths</td></tr>
        <tr><td><span class="k">Mod+Ctrl+H / L</span></td><td>Resize width −/+10%</td></tr>
        <tr><td><span class="k">Mod+Ctrl+J / K</span></td><td>Resize height −/+10%</td></tr>
    </table>

    <h2>Column Management</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">Mod+[</span></td><td>Consume / expel window left</td></tr>
        <tr><td><span class="k">Mod+]</span></td><td>Consume / expel window right</td></tr>
        <tr><td><span class="k">Mod+.</span></td><td>Expel window from column</td></tr>
    </table>

    <h2>System</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">Mod+Escape</span></td><td>Toggle keyboard shortcuts inhibit</td></tr>
        <tr><td><span class="k">Mod+Shift+C</span></td><td>Reload niri config</td></tr>
        <tr><td><span class="k">Mod+Shift+E</span></td><td>Quit niri</td></tr>
        <tr><td><span class="k">Mod+/</span></td><td>Open this cheatsheet</td></tr>
        <tr><td><span class="k">Mod+Shift+/</span></td><td>Niri hotkey overlay</td></tr>
    </table>

    <h2>Aliases — Navigation</h2>
    <table>
        <tr><th>Alias</th><th>Expands to</th></tr>
        <tr><td><span class="k">vault</span></td><td class="cmd">cd ~/Documents/azrael-vault</td></tr>
        <tr><td><span class="k">ops</span></td><td class="cmd">cd ~/Documents/azrael-ops</td></tr>
        <tr><td><span class="k">research</span></td><td class="cmd">cd ~/Github/security-research</td></tr>
        <tr><td><span class="k">engage</span></td><td class="cmd">cd ~/engage/current</td></tr>
        <tr><td><span class="k">loot / recon / notes</span></td><td class="cmd">cd ~/engage/current/{loot,recon,notes}</td></tr>
        <tr><td><span class="k">.. / ... / ....</span></td><td class="cmd">cd up 1 / 2 / 3 levels</td></tr>
    </table>

    <h2>Aliases — System</h2>
    <table>
        <tr><th>Alias</th><th>Expands to</th></tr>
        <tr><td><span class="k">update</span></td><td class="cmd">reflector + pacman -Syu + paru -Sua</td></tr>
        <tr><td><span class="k">aur</span></td><td class="cmd">paru -S</td></tr>
        <tr><td><span class="k">aurupdate</span></td><td class="cmd">paru -Sua</td></tr>
        <tr><td><span class="k">ports</span></td><td class="cmd">sudo ss -tulpn</td></tr>
        <tr><td><span class="k">myip</span></td><td class="cmd">curl -s ifconfig.me</td></tr>
        <tr><td><span class="k">stow</span></td><td class="cmd">stow --dir ~/Github/nightforge/dotfiles --target ~</td></tr>
    </table>

    </div>
    <div>

    <h2>Applications</h2>
    <table>
        <tr><th>Keybind</th><th>Application</th></tr>
        <tr><td><span class="k">Mod+Return</span></td><td>Terminal (Ghostty)</td></tr>
        <tr><td><span class="k">Mod+T</span></td><td>Tmux session picker</td></tr>
        <tr><td><span class="k">Mod+D</span></td><td>Launcher (DMS spotlight)</td></tr>
        <tr><td><span class="k">Mod+B</span></td><td>Browser (Firefox)</td></tr>
        <tr><td><span class="k">Mod+F</span></td><td>File manager (Yazi)</td></tr>
        <tr><td><span class="k">Mod+N</span></td><td>DMS notepad</td></tr>
        <tr><td><span class="k">Mod+V</span></td><td>DMS clipboard</td></tr>
        <tr><td><span class="k">Mod+M</span></td><td>DMS process list</td></tr>
        <tr><td><span class="k">Mod+,</span></td><td>DMS settings</td></tr>
        <tr><td><span class="k">Mod+Shift+N</span></td><td>DMS notifications</td></tr>
    </table>

    <h2>Obsidian</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">Mod+Shift+D</span></td><td>Open daily note</td></tr>
        <tr><td><span class="k">Mod+Shift+O</span></td><td>Search vault</td></tr>
        <tr><td><span class="k">Mod+O</span></td><td>Open azrael-vault</td></tr>
    </table>

    <h2>Screenshots</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">Mod+S</span></td><td>Area → PiP + save</td></tr>
        <tr><td><span class="k">Mod+Shift+S</span></td><td>Area → clipboard</td></tr>
        <tr><td><span class="k">Mod+Ctrl+S</span></td><td>Area → edit</td></tr>
        <tr><td><span class="k">Mod+Alt+S</span></td><td>Full screen → save</td></tr>
        <tr><td><span class="k">Mod+Alt+Shift+S</span></td><td>Full screen → clipboard</td></tr>
        <tr><td><span class="k">Mod+Alt+W</span></td><td>Window screenshot</td></tr>
        <tr><td><span class="k">Mod+Shift+R</span></td><td>Rename last screenshot</td></tr>
    </table>

    <h2>Media Keys</h2>
    <table>
        <tr><th>Key</th><th>Action</th></tr>
        <tr><td><span class="k">Vol+</span></td><td>Volume +3</td></tr>
        <tr><td><span class="k">Vol−</span></td><td>Volume −3</td></tr>
        <tr><td><span class="k">Mute</span></td><td>Toggle mute</td></tr>
        <tr><td><span class="k">MicMute</span></td><td>Toggle mic mute</td></tr>
    </table>

    <h2>Neovim</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">C-w h/j/k/l</span></td><td>Navigate windows</td></tr>
        <tr><td><span class="k">Space</span></td><td>Leader key (which-key)</td></tr>
        <tr><td><span class="k">Space+e</span></td><td>File explorer (neo-tree)</td></tr>
        <tr><td><span class="k">Space+f</span></td><td>Live grep (telescope)</td></tr>
        <tr><td><span class="k">gd / gr</span></td><td>Go to definition / references</td></tr>
        <tr><td><span class="k">K</span></td><td>Hover documentation</td></tr>
        <tr><td><span class="k">Space+r</span></td><td>Rename symbol</td></tr>
        <tr><td><span class="k">Space+c a</span></td><td>Code action (LSP)</td></tr>
        <tr><td><span class="k">Space+t</span></td><td>Toggle terminal</td></tr>
        <tr><td><span class="k">Space+s</span></td><td>Session manager</td></tr>
    </table>

    <h2>AI Agents</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">Mod+H</span></td><td>Hermes CLI</td></tr>
        <tr><td><span class="k">Mod+Shift+H</span></td><td>Hermes Desktop</td></tr>
        <tr><td><span class="k">Mod+P</span></td><td>Pi Agent (pia)</td></tr>
        <tr><td><span class="k">Mod+Alt+P</span></td><td>Pi Agent via 9Router</td></tr>
    </table>

    <h2>Aliases — Network &amp; Security</h2>
    <table>
        <tr><th>Alias</th><th>Expands to</th></tr>
        <tr><td><span class="k">wgup</span></td><td class="cmd">resolvconf -u &amp;&amp; wg-quick up wg0</td></tr>
        <tr><td><span class="k">wgdown</span></td><td class="cmd">wg-quick down wg0</td></tr>
        <tr><td><span class="k">wgstat</span></td><td class="cmd">sudo wg show</td></tr>
        <tr><td><span class="k">mesh</span></td><td class="cmd">wg show + ping cerberus/tairn/hermes</td></tr>
        <tr><td><span class="k">nftstat</span></td><td class="cmd">sudo nft list ruleset</td></tr>
        <tr><td><span class="k">nftreload</span></td><td class="cmd">sudo nft -f /etc/nftables.conf</td></tr>
        <tr><td><span class="k">scan</span></td><td class="cmd">nmap -T4 -sV</td></tr>
        <tr><td><span class="k">scan-quick</span></td><td class="cmd">nmap -T4 -F -sV</td></tr>
        <tr><td><span class="k">scan-full</span></td><td class="cmd">nmap -T4 -p- -sV</td></tr>
        <tr><td><span class="k">scan-deep</span></td><td class="cmd">nmap -T4 -A -p-</td></tr>
    </table>

    <h2>Tmux — Prefix: Ctrl+a</h2>
    <table>
        <tr><th>Keybind</th><th>Action</th></tr>
        <tr><td><span class="k">C-a |</span></td><td>Split horizontal</td></tr>
        <tr><td><span class="k">C-a -</span></td><td>Split vertical</td></tr>
        <tr><td><span class="k">C-a h/j/k/l</span></td><td>Navigate panes</td></tr>
        <tr><td><span class="k">C-a H/J/K/L</span></td><td>Resize panes</td></tr>
        <tr><td><span class="k">C-a c</span></td><td>New window (current path)</td></tr>
        <tr><td><span class="k">C-a Tab</span></td><td>Last window</td></tr>
        <tr><td><span class="k">C-a C-h / C-l</span></td><td>Previous / next window</td></tr>
        <tr><td><span class="k">C-a [</span></td><td>Scroll / copy mode</td></tr>
        <tr><td><span class="k">C-a x</span></td><td>Kill pane</td></tr>
        <tr><td><span class="k">C-a &amp;</span></td><td>Kill window</td></tr>
        <tr><td><span class="k">C-a r</span></td><td>Reload config</td></tr>
        <tr><td><span class="k">C-a D</span></td><td>Daily layout</td></tr>
        <tr><td><span class="k">C-a E</span></td><td>Engagement layout</td></tr>
        <tr><td><span class="k">C-a V</span></td><td>Research layout</td></tr>
    </table>

    <h2>Aliases — Git &amp; Tmux</h2>
    <table>
        <tr><th>Alias</th><th>Expands to</th></tr>
        <tr><td><span class="k">gs / ga / gc / gp / gl</span></td><td class="cmd">git status / add / commit / push / log</td></tr>
        <tr><td><span class="k">ts</span></td><td class="cmd">tmux session picker</td></tr>
        <tr><td><span class="k">ta / tl / tn</span></td><td class="cmd">tmux attach / list / new</td></tr>
    </table>

    <h2>Aliases — Containers</h2>
    <table>
        <tr><th>Alias</th><th>Expands to</th></tr>
        <tr><td><span class="k">cls / clsa</span></td><td class="cmd">podman ps / ps -a</td></tr>
        <tr><td><span class="k">cstop / crm</span></td><td class="cmd">stop all / remove all containers</td></tr>
    </table>

    </div>
    </div>

    <footer>NightForge · Azrael Security · Niri + DMS</footer>
</body>
</html>
HTML

xdg-open "$CHEATSHEET"
