# Tools Inventory

Complete tooling snapshot for NightForge operator workstation. All tools are either system-installed or version-controlled in `~/Repos/3rd-party/` or `~/Tools/`.

## Core Workflow

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| zsh | ✅ | /usr/bin/zsh | Shell environment |
| tmux | ✅ | /usr/bin/tmux | Terminal multiplexer |
| neovim | ✅ | /usr/bin/nvim | Primary editor |
| git | ✅ | /usr/bin/git | Version control |
| gh | ✅ | /usr/bin/gh | GitHub CLI |
| starship | ✅ | /usr/bin/starship | Cross-shell prompt |
| yazi | ✅ | /usr/bin/yazi | Terminal file manager |
| jq | ✅ | /usr/bin/jq | JSON processor |

## Search & Navigation

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| rg (ripgrep) | ✅ | /usr/bin/rg | Fast regex search |
| fd | ✅ | /usr/bin/fd | Fast file finder |
| bat | ✅ | /usr/bin/bat | Syntax-highlighted cat |
| fzf | ✅ | /usr/bin/fzf | Fuzzy finder |

## Container & VM

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| podman | ✅ | /usr/bin/podman | Container runtime (rootless) |
| libvirt | ✅ | /usr/bin/virsh | VM management |
| virt-install | ✅ | /usr/bin/virt-install | VM provisioning |

## Networking

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| tcpdump | ✅ | /usr/bin/tcpdump | Packet capture |
| wireshark-cli (tshark) | ✅ | /usr/bin/tshark | CLI packet analysis |
| nmcli | ✅ | /usr/bin/nmcli | NetworkManager CLI |
| ip | ✅ | /usr/bin/ip | Network configuration |
| ss | ✅ | /usr/bin/ss | Socket statistics |
| resolvectl | ✅ | /usr/bin/resolvectl | DNS resolver control |
| ethtool | ✅ | /usr/bin/ethtool | Ethernet device control |

## Recon

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| nmap | ✅ | /usr/bin/nmap | Network mapping |
| masscan | ✅ | /usr/bin/masscan | Fast port scanner |
| nuclei | ✅ | /usr/bin/nuclei | Vulnerability scanner |
| recon-ng | ✅ | /usr/bin/recon-ng | Web reconnaissance |
| ldapsearch | ✅ | /usr/bin/ldapsearch | LDAP directory search |

## AD & Windows

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| RustHound-CE | ✅ | ~/Repos/3rd-party/RustHound-CE | BloodHound equivalent |
| Rubeus | ✅ | ~/Repos/3rd-party/Rubeus | Kerberos manipulation |

## Web Security

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| gobuster | ✅ | /usr/bin/gobuster | Directory/DNS brute force |
| caido | ✅ | ~/Repos/3rd-party/caido/ | Web proxy + testing framework; CLI binary to reinstall when needed |

## Exploit Dev

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| msfconsole | ✅ | /usr/bin/msfconsole | Metasploit framework |
| msfvenom | ✅ | /usr/bin/msfvenom | Exploit payload generator |
| hashcat | ✅ | /usr/bin/hashcat | Password cracking |
| gef | ✅ | ~/Repos/3rd-party/gef | Primary GDB enhancer |
| pwndbg | ✅ | ~/Repos/3rd-party/pwndbg | Secondary GDB enhancer |

## Reverse Engineering

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| ghidra | ✅ | ~/Tools/suites/ghidra_12.0.1_PUBLIC | Full install; launcher at ~/Tools/bin/ghidra |

## AI & LLM

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| claude | ✅ | Claude Code CLI | API access via claude.ai or CLI |
| llmfit | ✅ | ~/Repos/3rd-party/llmfit → /usr/local/bin/llmfit | Symlinked; GTX 1650 4GB VRAM |
| ccsm | ✅ | ~/Repos/3rd-party/ccsm | Model selection and management |

## Package Management

| Tool | Installed | Location | Notes |
|------|:---------:|----------|-------|
| uv | ✅ | /usr/bin/uv | Python package manager |
| yay | ✅ | /usr/bin/yay | AUR helper |

## Missing / To Install

| Tool | Status | Notes |
|------|:------:|-------|
| wireshark-qt | ❌ | GUI frontend for packet analysis; install if GUI workflow needed (CLI tools already present) |

## ~/Repos/3rd-party/ Inventory
Last audited: 2026-03-29 (S040)

| Repo | Purpose | Status | Notes |
|---|---|---|---|
| caido | Caido web proxy API scripts, prompts, workflow examples | Keep — reference | Extract when web assessment work starts |
| ccsm | Claude Code session manager TUI (tmux-aware) | Active | Installed and documented |
| DT-Wallpapers | DistroTube wallpaper collection (327 nature/landscape images) | Keep | matugen-compatible |
| gef | GDB Enhanced Features — exploit dev and RE | Active — RE track | Multi-arch, Python3 API, preferred over pwndbg |
| gstack | YC/Garry Tan Claude Code workflow patterns | Reference — read-only | /investigate and /review extracted S029 |
| llmfit | LLM hardware fit scoring tool | Active | Installed at /usr/local/bin/llmfit, GTX 1650 4GB detected |
| maxhu08-dotfiles | Stow-managed dotfiles reference (tmux, zsh, nvim configs) | Reference | Compare before removing |
| maxhu08-wallpapers | Anime wallpaper collection | Keep | |
| Mythic | Mythic C2 framework upstream source | Reference | v3.4.0.45, tracking upstream master — reference for Tairn deployment updates |
| obsidian-skills | kepano/obsidian-skills agent skills for vault work | Active | Source clone, installed at cr1ms0n-vault/.claude/skills/ |
| recon-ng | Web-based OSINT reconnaissance framework | Active | Red team / threat intel E-shape depth |
| Rubeus | C# Kerberos interaction and abuse toolset (harmj0y) | Active — CRTA | Kerberoasting, AS-REP roasting, ticket operations |
| RustHound-CE | BloodHound Community Edition collector in Rust | Active — CRTA | AD enumeration, cross-platform |
