# Pi Agent — NightForge Context
# Auto-loaded by Pi Agent when running in NightForge project

## Project
- **NightForge**: Operator workstation for Azrael Security
- **Stack**: Arch Linux, Niri (Wayland), zsh
- **Location**: ~/Github/nightforge

## Conventions
- Container ops: podman (not docker) — see aliases: pn, pnp, pc
- Git: micro-commits mandatory, use `gs` (status), `gl` (log), `ga` (add), `gc` (commit)
- Shell: zsh with zinit plugin manager
- Security: never run destructive commands without confirmation

## Key Paths
- Dotfiles: ~/.config/niri/, ~/.config/ghostty/, ~/.config/zsh/
- Containers: ~/Github/nightforge/modules/container/
- Scripts: ~/Github/nightforge/scripts/
- Manifests: ~/Github/nightforge/manifests/
- Docs: ~/Documents/azrael-ops/

## Model Routing (OpenCode Go)
- Free tier first: opencode/deepseek-v4-flash-free
- Paid: opencode-go/deepseek-v4-pro
- Fallback: opencode-go/kimi-k2.6
