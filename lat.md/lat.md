# nightforge

Operator workstation for Azrael Security operations. Hosts T5 code tooling (OpenCode) and local development environment.

## Purpose

Anchors agent context and workflow conventions for the Azrael Security operator workstation.

- Hosts T5 code tooling (OpenCode) and local development environment.
- Provides agent context, session strategy, and GSD workflow for Azrael projects.

## Session Strategy

Defines how agents branch, resume, and hand off sessions.

- `--fork` — branch session for exploratory work.
- `--continue` — resume prior session.
- Use handoff docs between sessions for context transfer.

## GSD Workflow

Standard execution order for task completion.

1. `.planning/` directory for task breakdowns.
2. `STATE.md` tracks progress.
3. Execute in order: `lint -> typecheck -> test -> build`.

## Model Routing ($20/mo)

Cost-aware model routing table for agent tasks.

| Task / Agent | Model | Provider | Cost |
|---|---|---|---|
| Quick tasks | Big Pickle (GLM-4.6) | OpenCode Go FREE | $0 |
| Council/Oracle/Designer | kimi-k2.6 | OpenCode Go | $0 (sub) |
| Councillor/Fixer | deepseek-v4-flash | OpenRouter | ~$0.28/M out |
| General | glm-5.1 | OpenCode Go | $0 (sub) |
| Explore | mistral-nemo | OpenRouter | ~$0.03/M out |
| Explorer/Librarian | nemotron-3-nano | NVIDIA NIM (free) | $0 |
| Architecture | kimi-k2.6 | OpenCode Go | $0 (sub) |

**Pattern:** Free tier first → OpenCode Go sub → OpenRouter fallback → NVIDIA NIM (free)

## GitNexus Integration

This project is indexed by GitNexus for structural codebase awareness.

- Use `gitnexus://repo/nightforge/context` for codebase overview.
- Run `gitnexus_impact` before editing symbols.
- Run `gitnexus_detect_changes` before committing.

## Hermes Skills Inventory

Audited and pruned from 91 to ~75 skills. 16 removed (Apple, gaming, pure novelty). External dirs added for superpowers, code-archaeology, autoresearch, autoship.

External skill directories configured in Hermes `skills.external_dirs` for cross-tool skill sharing.

- `~/.cache/.../superpowers/skills` — brainstorming, dispatching, executing-plans, finishing-a, receiving-code-review, using-git-worktrees, using-superpowers, verification-before-completion, writing-skills
- `~/.cache/.../opencode-code-archaeology/skills` — code-archaeology
- `~/.agents/skills` — azrael-project, caveman
- `~/Github/AutoResearch/skills` — autoresearch
- `~/Github/AutoShip` + `~/Github/AutoShip/skills` — autoship (11 sub-skills)
- `~/Github/Code-Archaeology/skills` — code-archaeology

## Invariants

Rules that must remain true across all agent operations.

- AGENTS.md must exist at project root and stay up-to-date.
- All agent-driven changes must update corresponding AGENTS.md sections.
- Plugin order in `opencode.json` must be: `RTK` → `context-mode` → `ECC` → `Superpowers` → `GitNexus`.
- Never commit tokens, keys, or credentials.
- Never write outside project dir or modify `~/.ssh`, `/etc/wireguard`, `/etc/nftables.conf`.
