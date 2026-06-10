---
forge_pattern: "dependency-install-gate"
category: "security"
reusability: "high"
maturity: "implemented"
authored: "2026-04-12"
implementation_phase: "SCAG v2 (post-DSW)"
---

# FORGE Pattern: Dependency Install Gate

## Problem

An AI agent that can autonomously run shell commands can install external packages without any human awareness. `pip install malicious-pkg` or `claude mcp add untrusted-server` runs silently, executes install hooks, and lands code on the machine before anyone reviews it. The supply-chain audit skill (SCAG) exists, but if it isn't enforced mechanically, it's advisory — a motivated agent or a rushed session can bypass it.

The pattern `dependency-install-gate` solves this by wiring a hard pre-tool-use hook that blocks every package install command until a verified SCAG approval token exists on disk. The token is one-shot: it is consumed at install time, forcing a fresh audit cycle for each new dependency.

## When to use this pattern

- Any agentic environment where Claude (or another agent) can autonomously run shell commands
- Projects that have adopted `supply-chain-audit-triad` and want to enforce it mechanically, not just by convention
- Environments where autonomous package installs represent a meaningful blast radius (production infra, governance-sensitive repos)

## When NOT to use this pattern

- Pure read-only agent environments with no shell access
- CI/CD pipelines that only run pinned lock-file installs (`pip install -r requirements.lock` from a pre-audited manifest)
- Environments where SCAG is not yet implemented (the gate blocks without a path to unblock — implement SCAG first)

## Generic architecture

### Components

```
┌──────────────────────────────────────────────┐
│  pre-tool-use hook                           │
│                                              │
│  Detects install verb in Bash command        │
│  → checks .skill-locks/scag-approved         │
│     present  → allow + consume token         │
│     absent   → block + print instructions   │
└──────────────────────────────────────────────┘
           ↑ token produced by ↓
┌──────────────────────────────────────────────┐
│  /supply-chain-audit (SCAG skill)            │
│                                              │
│  IBA → Triad → APPROVE/CONDITIONAL           │
│  Step 5a: touch .skill-locks/scag-approved   │
└──────────────────────────────────────────────┘
```

### Token lifecycle

1. **Session start**: no `scag-approved` token exists (gitignored, session-scoped)
2. **User/agent runs `/supply-chain-audit {pkg}`**: IBA + triad execute
3. **On APPROVE or CONDITIONAL verdict**: skill creates `.skill-locks/scag-approved`
4. **Agent runs install command**: hook detects install verb, finds token, deletes it, allows command
5. **Next install**: requires its own SCAG cycle (token was consumed)

### Install verbs gated

| Ecosystem | Commands intercepted |
|---|---|
| Python | `pip install`, `pip3 install`, `uv install`, `uv add` |
| Node | `npm install`, `npm i`, `yarn add`, `pnpm add`, `bun add` |
| MCP servers | `claude mcp add` |

### Bypass path (pre-approved packages)

Packages listed in `.claude/allowlists/mcp-preapproved.json` are exempt from SCAG. For those, the user can create the token directly:

```bash
mkdir -p .skill-locks && touch .skill-locks/scag-approved
```

This is the documented bypass — explicit, auditable, not hidden.

## {{PROJECT}} implementation

- **Hook**: `.claude/hooks/pre-tool-use.sh` — SCAG gate block (lines 93–115)
- **Skill step**: `.claude/skills/supply-chain-audit/SKILL.md` Step 5a — creates token on APPROVE/CONDITIONAL
- **Token location**: `.skill-locks/scag-approved` (session-scoped, gitignored)
- **CARL rule**: `{{PROJECT}}TECH_RULE_17` — AI-side awareness, paired with hook for defense in depth
- **Reference rule**: `.claude/rules/supply-chain-audit.md`
- **Architecture doc**: `docs/architecture/security/supply-chain-controls.md`

## Design decisions

| Decision | Rationale | Alternative rejected |
|---|---|---|
| One-shot token (consumed at install) | Forces a fresh audit cycle per install — no "one approval, many installs" drift | Persistent token per session (allows bypassing SCAG for subsequent installs without re-audit) |
| Hook blocks, not just warns | Enforces the gate even under autonomous execution — a warning can be ignored | Soft warning only (insufficient for autonomous agents) |
| Token in `.skill-locks/` | Reuses existing session-scoped gitignored mechanism from skill gate | New directory (unnecessary fragmentation) |
| Bypass via explicit `touch` | Preserves human agency for pre-approved packages — documented, traceable | No bypass path (too rigid; pre-approved packages are a valid use case) |
| CARL rule + hook (defense in depth) | Hook catches all Bash installs; CARL rule catches design-level decisions before Claude writes any command | Hook alone (misses the case where Claude proposes but doesn't execute) |

## Complementary patterns

- `supply-chain-audit-triad` — the audit mechanism that produces the APPROVE/CONDITIONAL verdict
- `skill-gate` (`.claude/rules/skill-gate.md`) — same token pattern for domain-protected files
- `dependency-surveillance-watch` (DSW) — continuous CVE monitoring after install (what this pattern doesn't cover)
