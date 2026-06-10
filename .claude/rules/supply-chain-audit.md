---
paths:
  - "pyproject.toml"
  - "requirements.txt"
  - "requirements-*.txt"
  - "package.json"
  - "package-lock.json"
  - ".mcp.json"
  - ".gitmodules"
  - ".claude/allowlists/mcp-preapproved.json"
  - ".claude/skills/**/SKILL.md"
  - "docs/audits/dependencies/**/*"
---

# Supply-Chain Audit Gate (SCAG)

> Source canonique du gate d'audit supply chain.
> Path-scoped : ne se charge que quand Claude touche un fichier de dépendances, MCP config, ou artefact d'audit.
> Complète `governance.md` (enforcement) et `skill-gate.md` (domain gate).

## Principe

Aucune dépendance externe exécutable ne peut être introduite dans le repo sans passer par un audit structuré.
Un audit point-in-time ne couvre pas les CVE post-install — voir `.claude/rules/dependency-surveillance.md` (DSW).

## Triggers

| Trigger | Détection |
|---|---|
| Nouveau package Python/Node | Ajout dans `pyproject.toml`, `requirements*.txt`, `package.json` |
| Nouveau MCP server | Diff de `.mcp.json` ou `.claude/settings.json` |
| Nouveau skill cloné depuis repo externe | Nouveau dossier dans `.claude/skills/` avec origine non-{{PROJECT}} |
| Nouveau git submodule | Diff de `.gitmodules` |
| Script d'install tiers via `curl \| sh` | Pattern dans Bash command |
| CLI tool externe ajouté au workflow | Nouvelle entrée dans `.claude/integrations.md` |

## Exemptions

| Situation | Action | Justification |
|---|---|---|
| MCP server dans `.claude/allowlists/mcp-preapproved.json` | Skip SCAG | Pré-approuvé (Anthropic-published, tier-1 providers) |
| Bump patch/minor d'une dep déjà auditée | Skip SCAG, DSW couvre | Même codebase, diff minimal |
| Bump majeur d'une dep déjà auditée | **Re-trigger SCAG** | Changement de surface d'attaque potentiel |

## Triad d'audit (3 agents en parallèle)

| Agent | Focus | Couverture |
|---|---|---|
| `sast-scanner` | Mécanique | gitleaks (secrets hardcodés), Semgrep (CWE/OWASP patterns), dépendances connues vulnérables |
| `security-sentinel` | Sémantique | SSRF, auth, input validation, boundaries, logique sécurité |
| `adversarial-reviewer` | Offensif | Scénarios d'attaque construits activement, abuse potentiel |

Les 3 agents tournent en **foreground** — leur résultat conditionne la décision.

## Artefacts produits

```
docs/audits/dependencies/{package}-v{version}-{YYYY-MM-DD}/
  ├── AUDIT.md              (verdict consolidé + reco)
  ├── sast-findings.md      (output sast-scanner)
  ├── sentinel-findings.md  (output security-sentinel)
  ├── adversarial.md        (output adversarial-reviewer)
  └── DECISION.md           (approve / conditional / reject)
```

Template : `docs/architecture/templates/dependency-audit-template.md`

## Decision gate

| Verdict | Condition | Signataire |
|---|---|---|
| **Approve** | Les 3 agents reviennent 100% clean | Auto-sign par Claude |
| **Conditional** | Finding(s) non-critiques, mitigation documentée | Humain obligatoire |
| **Reject** | Finding(s) critiques, pas de mitigation viable | Humain obligatoire |

## Post-approve — mise à jour obligatoire dans le même commit

- `.claude/integrations.md` si MCP/tool ajouté
- `docs/codebase/services-and-access.md` si endpoints/accès changent
- `.claude/rules/tool-routing.md` si caps/patterns MCP changent
- `SBOM` (quand implémenté) mis à jour

## Refresh obligatoire

- À chaque bump majeur : re-run triad complet
- À chaque signal externe (CVE, maintainer compromis, fork hostile) : re-run
- Tous les 12 mois : re-run minimal (`sast-scanner` seul)

## Invocation

```
/supply-chain-audit <path-to-cloned-repo> --package <name> --version <version>
```

Skill : `.claude/skills/supply-chain-audit/SKILL.md`

## Ce qui ne va pas ici

- CVE monitoring continu → `.claude/rules/dependency-surveillance.md`
- Patch management SLA → `docs/standards/patch-management-standard.md`
- MCP caps et anti-patterns → `.claude/rules/tool-routing.md`
- Architecture complète supply chain → `docs/architecture/security/supply-chain-controls.md`