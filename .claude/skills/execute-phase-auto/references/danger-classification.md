# Danger Classification — Step 1 Detail

> Loaded by `/execute-phase-auto` Step 1. Single risk axis = **danger**.
> Danger is the ONLY trigger for human solicitation. Everything non-dangerous
> the orchestrator handles autonomously.

## What "danger" means

A plan is `danger=yes` if its execution can cause an irreversible or
externally-visible effect on a live system. The danger surfaces:

| Surface | Why it is dangerous |
|---------|---------------------|
| **Production** | Any change to a running prod service, prod config, prod data |
| **Client tenant** | Any operation against a client {{IDENTITY_PLATFORM}} / {{CLOUD_PROVIDER}} / {{CRM_PLATFORM}} tenant |
| **Secret / credential** | Creating, rotating, reading, or wiring a secret, API key, app registration, certificate |
| **Deploy / publish** | Publishing a workflow, deploying code, activating a workflow, pushing to a live endpoint |
| **Data migration** | Schema change, data backfill, cutover, irreversible delete |
| **AA runbook promotion** | Promoting an {{CLOUD_PROVIDER}} Automation runbook through environments |
| **Protected paths** | Files under a skill-gate domain (`{{cloud_provider}}`, `{{WORKFLOW_ENGINE}}`, `{{crm_platform}}`) or promotion/deploy scripts |

If a plan touches none of these, it is `danger=no` — the orchestrator
executes it without prompting.

## Danger signals / keywords

Scan each `*-PLAN.md` for these signals. Presence of any one → `danger=yes`.

- **Path signals**: `.ps1`, `.psm1`, `.psd1`, `scripts/runbooks/`, `{{WORKFLOW_ENGINE}}/workflows/`,
  `scripts/` (promotion/deploy), `infra/`, `*.bicep`, `config/*.json` touching prod
- **Verb signals**: `deploy`, `publish`, `promote`, `activate`, `cutover`, `migrate`,
  `rotate`, `backfill`, `drop`, `purge`, `provision`, `grant`
- **Target signals**: `prod`, `production`, `client tenant`, `{{PROD_AUTOMATION_ACCOUNT}}`,
  `tenant`, `Key Vault`, `secret`, `credential`, `app registration`, `GDAP`,
  `webhook URL`, `RBAC`, `Graph scope`
- **Frontmatter signals**: a plan whose frontmatter declares a protected domain,
  a promotion target, or `risk:` MEDIUM+

When in doubt, classify `danger=yes` — false positives cost one confirmation;
false negatives cost an unsupervised dangerous action.

## How to scan PLAN files — deterministic scan

Step 1 runs a **fixed pattern scan**, not a judgment call. The same PLAN
content always produces the same danger map — the LLM does not "read and
decide". Run this verbatim; do not substitute a mental scan:

```bash
# {GLOB} = the phase PLAN files, e.g. .planning/phases/*/{N}-*/*-PLAN.md
DANGER_RE='\.ps[md]?1|scripts/runbooks//workflows/|\.bicep|infra/|config/[a-z0-9_-]*\.json|\b(deploy|publish|promote|activate|cutover|migrate|migration|rotate|rotation|backfill|provision|purge|drop|grant)\b|\b(production|tenant|gdap|rbac|webhook|secret|credential)\b|\bprod\b|key ?vault|app registration|graph scope|risk: *(medium|high|critical)'
for f in {GLOB}; do
  hits=$(rg -in "$DANGER_RE" "$f" | head -6)
  if [ -n "$hits" ]; then
    printf 'DANGER=yes  %s\n' "$f"
    printf '%s\n' "$hits" | sed 's/^/    /'
  else
    printf 'DANGER=no   %s\n' "$f"
  fi
done
```

### Authority rules — the scan output is binding

1. A plan the scan marks `yes` **is** `yes`. The LLM **cannot downgrade** a
   scan `yes` to `no` — not for any reason.
2. The LLM **may escalate** a scan `no` to `yes` if it sees a danger the
   pattern missed (a semantic danger expressed without any keyword above).
   Escalation only — never the reverse.
3. Record per plan: plan id, title, `danger`, and the **matched line(s)** the
   scan printed (or the escalation reason) as the named trigger. Never assert
   danger without naming why.
4. A plan with zero scan hits **and** no LLM escalation is `danger=no`.

> The deterministic scan closes the "LLM mis-reads a PLAN" gap for any danger
> expressed as a keyword. It does **not** cover a danger with no keyword at all
> — that is what rule 2 (escalation) is for. When unsure whether to escalate,
> escalate: a false positive costs one confirmation, a false negative costs an
> unsupervised dangerous action.

## Danger-map output format

Present the result as a table before any execution:

```
## Danger Map — Phase {N}

| Plan | Title | Danger | Trigger |
|------|-------|--------|---------|
| 01 | {title} | no  | — |
| 02 | {title} | yes | publishes {{WORKFLOW_ENGINE}} workflow to prod (verb: publish, path: {{WORKFLOW_ENGINE}}/workflows/) |
| 03 | {title} | yes | client tenant Graph call (target: client tenant, GDAP) |

Non-dangerous plans: {count} — run autonomously.
Dangerous plans: {count} — hard-stop + human solicitation at each boundary.
```

- **Interactive mode**: present the map and ask the user once to confirm or
  amend it before Step 2. If the user re-classifies a plan, honor their call.
- **Autonomous mode**: present the map for the record, then proceed directly
  to Step 2 — no confirmation prompt. The hard-stops still fire at runtime.

## Relationship to the skill gate

This classification is the skill's own risk lens — it does **not** replace the
hard skill-gate hooks (`pre-tool-use.sh`, `pre-mcp-gate.sh`). A plan under a
protected domain is `danger=yes` here AND still subject to the marker hook at
write time. The two layers are complementary, not redundant.
