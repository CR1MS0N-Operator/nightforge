# /investigate — Systematic Root Cause Debugging

CR1MS0N-Operator debugging discipline. Scoped to: Veil infrastructure issues,
PoC script behavior, container boundary research anomalies, C2 agent issues on Tairn.

**Iron Law: NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**
Fixing symptoms creates whack-a-mole debugging. Find the root cause, then fix it.

---

## Phase 1: Root Cause Investigation

Gather context before forming any hypothesis.

1. **Collect symptoms** — read error messages, logs, reproduction steps. If insufficient
   context, ask ONE question at a time before proceeding.

2. **Trace the path** — follow the execution path from symptom back to potential causes.
   Read code, configs, and logs. On Veil nodes:
   - Services: `journalctl -u <service> -n 100 --no-pager`
   - Containers: `podman logs <container>`
   - Network: `wg show`, `nft list ruleset`, `ss -tlnp`

3. **Check recent changes:**
```bash
   git log --oneline -20 -- <affected-files>
```
   Was this working before? What changed? A regression means the root cause is in the diff.

4. **Reproduce** — trigger the bug deterministically before forming any hypothesis.
   If it cannot be reproduced, gather more evidence. Do not proceed without reproduction.

**Output:** `Root cause hypothesis: [specific, testable claim about what is wrong and why]`

---

## Phase 2: Pattern Analysis

Match against known failure patterns:

| Pattern | Signature | Where to look |
|---|---|---|
| Privilege boundary violation | Unexpected capability, namespace escape | OCI hooks, seccomp, capability sets |
| Race condition | Intermittent, timing-dependent | Concurrent access, async paths |
| Configuration drift | Works on one node, fails on another | Env vars, kernel version, mount state |
| Network isolation failure | Traffic reaching wrong destination | nftables rules, WireGuard routing, hairpin |
| Container runtime bug | Unexpected host-side behavior | OCI hook execution, cgroup state |
| Service dependency failure | Timeout, unexpected state | Systemd unit ordering, socket activation |

Recurring failures in the same component are an architectural signal, not coincidence.

---

## Phase 3: Hypothesis Testing

Before writing any fix, verify the hypothesis.

1. **Confirm** — add a temporary log, assertion, or debug output at the suspected root
   cause. Run the reproduction. Does evidence match the hypothesis?

2. **If wrong** — return to Phase 1. Gather more evidence. Do not guess.

3. **3-strike rule** — if 3 hypotheses fail, STOP:
```
   3 hypotheses tested, none confirmed.
   
   A) Continue — new hypothesis: [describe]
   B) Escalate — this needs deeper investigation outside this session
   C) Instrument — add logging and capture it next occurrence
```

**Red flags — slow down if you see these:**
- Proposing a fix before tracing execution — that is guessing
- Each fix reveals a new failure elsewhere — wrong layer, not wrong code
- "Quick fix for now" — there is no for now. Fix it right or escalate.

---

## Phase 4: Implementation

Once root cause is confirmed:

1. **Fix the root cause, not the symptom** — smallest change that eliminates the actual problem
2. **Minimal diff** — fewest files touched, fewest lines changed. Do not refactor adjacent code.
3. **Verify the fix** — reproduce the original scenario and confirm it no longer triggers.
4. **If fix touches >3 files** — flag blast radius before proceeding:
```
   This fix touches N files.
   A) Proceed — root cause genuinely spans these files
   B) Split — fix the critical path now, defer the rest
   C) Rethink — there may be a more targeted approach
```

---

## Phase 5: Verification and Report

Fresh verification is not optional. Reproduce the original scenario and confirm resolution.

Output a structured debug report:
```
DEBUG REPORT
════════════════════════════════════════
Symptom:      [what was observed]
Root cause:   [what was actually wrong, with file:line or component reference]
Fix:          [what was changed]
Evidence:     [log output, reproduction attempt confirming fix]
Node:         [Cerberus | NightForge | Tairn]
Related:      [prior issues in same area, architectural notes, troubleshooting.md entry]
Status:       DONE | DONE_WITH_CONCERNS | BLOCKED
════════════════════════════════════════
```

If DONE_WITH_CONCERNS or BLOCKED, use escalation format:
```
STATUS: BLOCKED | DONE_WITH_CONCERNS
REASON: [1-2 sentences]
ATTEMPTED: [what was tried]
RECOMMENDATION: [what Darrius should do next]
```

If the issue is new and resolved, add it to `~/Github/veil/docs/troubleshooting.md`
before the session closes. Format: Issue → Root cause → Resolution → Lesson.

---

## Important Rules

- Never say "this should fix it." Verify and prove it.
- Never apply a fix that cannot be verified in this session.
- 3 failed hypotheses → STOP. Wrong architecture, not failed hypothesis.
- Blast radius >3 files → ask before proceeding.
- DONE requires: root cause confirmed, fix applied, fix verified.
