# /review — Pre-Commit Review Gate

CR1MS0N-Operator pre-commit review for the security-research repo.
Scoped to: research writeups, PoC scripts, methodology documentation, tool code.

**Fix-first discipline:**
- AUTO-FIX — apply directly, no approval needed (formatting, obvious errors, style)
- ASK — present finding and proposed fix, wait for approval before touching
- FLAG — informational only, no fix proposed

Read the full diff before commenting. Do not flag issues already addressed in the diff.
Be terse. One line problem, one line fix. No preamble.

---

## Step 1: Diff
```bash
git diff --stat HEAD
git diff HEAD
```

If no diff against HEAD, check staged:
```bash
git diff --cached --stat
git diff --cached
```

If no diff at all, report: "Nothing to review — no changes staged or unstaged."

---

## Step 2: Structured Review Pass

Check the diff against these categories in order:

**OPSEC (ASK)**
- Internal IPs (10.0.0.x, 192.168.x.x) hardcoded in scripts or writeups
- Veil node hostnames (cerberus, nightforge, tairn) in public-facing content
- Real credentials, tokens, or keys referenced anywhere
- Internal path structure revealing infrastructure layout

**Research completeness (FLAG)**
- Finding documented without reproduction steps
- PoC script present but methodology writeup missing or stub
- Claims made without evidence or citation
- Research question not stated or answered

**Code correctness (AUTO-FIX or ASK)**
- Shell scripts: missing error handling, unquoted variables, incorrect shebangs
- Python: unhandled exceptions on critical paths, missing argument validation
- Go: unchecked errors, resource leaks
- Any language: hardcoded paths that should be variables

**Documentation (AUTO-FIX)**
- Trailing whitespace, inconsistent heading levels
- Broken markdown links
- Missing or inconsistent code block language tags

---

## Step 3: Adversarial Pass

Dispatch a fresh review with no checklist bias from Step 2.

Subagent prompt:
"Read the diff with `git diff HEAD` (or `git diff --cached` if nothing unstaged).
You are reviewing offensive security research content. Think like a defender reading
this research: what would they learn about the author's infrastructure? Think like a
peer reviewer: what claims are unsupported, what methodology gaps exist, what would
make this unpublishable? Think like an attacker reading the PoC: does it work as
described, are there errors that would cause it to fail silently?
Report findings only. No compliments. Classify each as CRITICAL, INFORMATIONAL."

Present findings under `ADVERSARIAL PASS:` header.
CRITICAL findings from the adversarial pass feed into the ASK pipeline.
INFORMATIONAL findings are presented as FLAG items.

---

## Step 4: Output
```
REVIEW SUMMARY
════════════════════════════════════════
AUTO-FIXED: N items
  - [description] — [file:line]

ASK: N items
  - [description] — [file:line]
    Proposed fix: [one line]
    Approve? Y/N

FLAG: N items
  - [description] — [file:line]

ADVERSARIAL PASS: [CLEAN | N findings]
════════════════════════════════════════
```

Work through ASK items one at a time. Do not batch approvals.

---

## Important Rules

- Read the full diff before commenting
- Never commit or push — that is the operator's job
- AUTO-FIX only on items with no ambiguity
- ASK on anything touching research content, findings, or methodology
- OPSEC findings are always ASK regardless of how obvious the fix seems
- If review finds nothing: "REVIEW CLEAN — no findings."
