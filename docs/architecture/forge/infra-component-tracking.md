---
forge_pattern: "infra-component-tracking"
category: "operations"
reusability: "high"
maturity: "implemented"
authored: "2026-04-12"
implementation_phase: "24 — FORGE pre-extraction"
---

# FORGE Pattern: Infrastructure Component Tracking

## Problem

Les composants d'infrastructure (Docker images, packages uv/npm/pip, binaires, MCP servers, PS modules) evoluent independamment. Sans inventaire structure :

- Personne ne sait quelles versions sont deployees
- Les upgrades arrivent sans prevenir (tokens perdus, breaking changes)
- Pas de patch history auditable
- Pas de lien entre un composant et les skills/systemes qui en dependent
- Pas d'analyse de risque structuree avant un upgrade — decisions ad hoc

Ce pattern resout cela avec un triple inventaire (machine + human + process) et une automatisation de detection drift + scoring risque.

## When to use this pattern

- Projets avec > 3 composants infra externes (Docker, MCP, packages)
- Projets ou un downtime ou un breaking change a un cout reel
- Environnements ou plusieurs operateurs/agents peuvent declencher des upgrades
- Projets qui veulent un audit trail de patches (compliance, SOC 2)

## When NOT to use this pattern

- Projets mono-composant (juste une lib) — overhead pas justifie
- Prototypes temporaires — flexibilite > rigueur
- Composants entierement gerees par un orchestrateur externe (Kubernetes operators, Helm)

## Generic architecture

### 1. Triple inventaire

```
┌──────────────────────────────────────────────────────────┐
│  MACHINE-READABLE                                        │
│  config/infra-components.json                            │
│    — Consomme par scripts de drift/upgrade               │
│    — Source de verite des versions actuelles             │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│  HUMAN-READABLE                                          │
│  docs/codebase/infra-inventory.md                      │
│    — Tables par tier (critique / outils)                 │
│    — Matrice risque × priorite                            │
│    — Patch history                                       │
│    — Backlog upgrades                                    │
└──────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│  PROCESS STANDARD                                        │
│  docs/standards/infra-patch-management.md                │
│    — Scoring risque 5 dimensions (5-25)                  │
│    — Process par niveau (LOW/MEDIUM/HIGH/CRITICAL)       │
│    — Rollback procedures                                 │
│    — Integration DSW (CVE patches)                       │
└──────────────────────────────────────────────────────────┘
```

### 2. Schema JSON standard

Chaque composant a un enregistrement normalise :

```json
{
  "type": "docker | uv-tool | npm-package | binary | mcp-server",
  "package": "{name}",
  "current_version": "{semver}",
  "deployment": "{where it runs}",
  "source_url": "{API endpoint to query latest}",
  "version_selector": "{JSON path to version field}",
  "upgrade_command": "{shell command}",
  "rollback_command": "{shell command}",
  "check_interval": "weekly | monthly",
  "breaking_change_risk": "low | medium | high",
  "refresh_dependent_skills": ["skill1", "skill2"]
}
```

Les champs sont universels — adaptables a tout type de composant externe.

### 3. Detection drift (automatique)

Script `check-infra-drift.sh` :

1. Lit `infra-components.json`
2. Pour chaque composant : HTTP GET sur `source_url`, extrait la version via `version_selector`
3. Compare a `current_version`
4. Si different : emet le delta dans le format `component: current → latest (type)`
5. Run au `session-start` (warn-only) ou cron

### 4. Analyse de risque (scoring 5 dimensions)

Script `analyze-upgrade-risk.sh {component}` :

| Dimension | Score 1 | Score 3 | Score 5 |
|---|---|---|---|
| Surface | Patch | Minor | Major |
| Blast radius | 1 skill | 2-3 skills | Multi + prod |
| Reversibilite | Trivial | Downtime | Irreversible |
| Test coverage | Tests + dev | Dev only | None |
| Signal upstream | Clean changelog | Some breaking | Many breaking |

**Total 5-25 →** LOW / MEDIUM / HIGH / CRITICAL

### 5. Processus par niveau de risque

```
LOW (5-9)      : apply auto apres changelog review
MEDIUM (10-15) : test en dev + rollback plan documente
HIGH (16-20)   : phase GSD formelle + backup + approval
CRITICAL (21-25): arch review + staging + phased rollout
```

### 6. Integration governance

Regle de co-update obligatoire :

> Tout ajout/retrait/upgrade/patch d'un composant infra DOIT mettre a jour `infra-components.json` + `infra-inventory.md` dans le meme commit. Si MEDIUM+, documenter le score de risque dans le commit message.

## {{PROJECT}} implementation

| Composant | Fichier |
|---|---|
| Machine inventory | `config/infra-components.json` — 8 composants |
| Human inventory | `docs/codebase/infra-inventory.md` — tiers, matrice, patch history |
| Process standard | `docs/standards/infra-patch-management.md` — scoring + process |
| Drift check | `scripts/upstream-watch/check-infra-drift.sh` — session-start auto |
| Risk analyzer | `scripts/upstream-watch/analyze-upgrade-risk.sh` — on-demand |
| Governance rule | `.claude/rules/governance.md` § "Mise a jour obligatoire" |
| Dependabot complement | `.github/dependabot.yml` (Python/npm deps) + OSV-Scanner (CVE) |

### Learnings

- **Le drift check au session-start est le trigger naturel** — l'operateur voit les upgrades disponibles au moment ou il ouvre une session, sans pollution des notifications externes
- **Le scoring mecanique bat le jugement intuitif** — "juste un minor bump" peut etre HIGH RISK si le blast radius est large et les tests absents
- **Separer CVE (DSW) et feature upgrades (ce pattern)** — ils ont des SLA et triggers differents, les melanger cree de la confusion
- **Le triple inventaire n'est pas du duplicate** — machine/human/process servent chacun un consommateur different (scripts, operateur, review)

## Design decisions

| Decision | Rationale | Alternative rejetee |
|---|---|---|
| JSON inventory + Markdown inventory | Machine-readable pour automation, human-readable pour review. Un seul format n'aurait pas les deux qualites | YAML only (machine friendly mais verbose pour humain), Markdown only (pas de parsing reliable) |
| Risk scoring a 5 dimensions | Balance entre complexite (signal multi-facettes) et simplicite (calcul en < 2s) | Score binaire (trop simpliste), scoring ML (overkill, pas explicable) |
| Session-start trigger (pas cron) | L'operateur voit les upgrades au moment ou il peut agir dessus | Cron email (noise, ignoree), cron todo creation (add a ignorer la source) |
| Co-update rule dans governance | Force la coherence entre JSON, inventaire, patch history | Laisser a la discretion (drift garantie) |
| Separation CVE/feature upgrades | CVE = securite + SLA strict. Feature = choix + analyse risque. Melanger brouille les signals | Un seul process unifie (SLA CVE ne s'applique pas aux features) |

## Complementary patterns

- `supply-chain-audit-triad` — gate install **initial**, ce pattern gere les upgrades **continus**
- `deterministic-knowledge-sync` — meme philosophie (automation deterministe, zero LLM)
- `upstream-source-watcher` — meme mecanisme (drift detection), applique aux sources legales/docs au lieu des composants infra
- `dependency-install-gate` — le SCAG gate s'applique aux upgrades MAJOR (nouvelle surface d'attaque)
