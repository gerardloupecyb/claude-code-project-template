---
name: security-audit
description: >
  On-demand security audit of Claude Code configuration via AgentShield.
  Scans .claude/ for hardcoded secrets, permission issues, hook injection,
  and supply chain risks. Run before merging or shipping.
  Triggers on: security-audit, audit security, agentshield.
---

# Security Audit — AgentShield On-Demand Scanner

Runs AgentShield against `.claude/` to detect configuration security issues.
Use before merge/ship — not a continuous hook.

Requires: `npx` (Node.js). Not a project dependency — downloaded on demand.

---

## Usage

```
/security-audit
/security-audit --fix
```

---

## Process

### Step 1 — Check npx

```bash
command -v npx >/dev/null 2>&1
```

If not available:
```
AgentShield requires npx (Node.js).
  Install: https://nodejs.org  or  brew install node
  Then retry: /security-audit
```
Stop here.

### Step 2 — Run scan

```bash
npx ecc-agentshield scan --path .claude/
# With --fix:
npx ecc-agentshield scan --path .claude/ --fix
```

### Step 3 — Present results

Format:
```
Security Grade: B (74/100)

CRITICAL (0) — none
HIGH (1)
  • .claude/settings.json:12 — npx -y without version pin (supply chain risk)
MEDIUM: 2  LOW: 3
```

Rules:
- CRITICAL → list all, with file:line + description + fix
- HIGH → list all, with file:line + description
- MEDIUM/LOW → counts only

### Step 4 — Next steps

If CRITICAL or HIGH exist:
- Suggest `/security-audit --fix` if not already run
- List manual fixes for issues that can't be auto-corrected

If grade A or B with no CRITICAL/HIGH:
```
Config sécurisée. Aucune action requise.
```

---

## Notes

- Scans `.claude/` only (project-level). For global config: pass `--path ~/.claude/`
- `--fix` auto-corrects simple issues (hardcoded secrets → env var refs)
- The `npx` download is cached after first run
