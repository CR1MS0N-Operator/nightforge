# nightforge — Agent Rules

## Purpose
Operator workstation for CR1MS0N-Operator operations. Hosts T5 code tooling (OpenCode) and local development environment.

## Session Strategy
- `--fork` — branch session for exploratory work
- `--continue` — resume prior session
- Use handoff docs between sessions for context transfer

## GSD Workflow
- `.planning/` directory for task breakdowns
- STATE.md tracks progress
- Execute in order: lint -> typecheck -> test -> build

## Model Routing ($20/mo)
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

## Reference
- Global rules: ~/.config/opencode/AGENTS.md
- CR1MS0N context: ~/Documents/cr1ms0n-ops/CLAUDE.md

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **nightforge** (799 symbols, 802 relationships, 0 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/nightforge/context` | Codebase overview, check index freshness |
| `gitnexus://repo/nightforge/clusters` | All functional areas |
| `gitnexus://repo/nightforge/processes` | All execution flows |
| `gitnexus://repo/nightforge/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
