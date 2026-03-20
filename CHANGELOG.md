# Changelog

Toutes les modifications notables de ce projet sont documentees dans ce fichier.
Format base sur [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning selon [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] — 2026-03-20

Reference files system — documentation technique structuree en 4 couches.

### Added

#### 4-Layer Reference System (`docs/references/`)
- `architecture-security.md` (L1) — auth decisions, topology, compliance, security rules
- `coding-patterns.md` (L2) — error handling, retry, tests, naming, logging conventions
- `services-and-access.md` (L3) — servers, Docker, secrets, SPs, MCPs, APIs, systemd
- `codebase-context.md` (L3) — modules, schemas, interfaces, config, entry points
- `Reference-files-index-routing.md` — routing decision tree + staleness detection

#### `/reference-audit` skill (8e skill)
- Auto-population par scan du codebase (Dockerfile, .env, package.json, MCP configs)
- Cross-reference MCP : `tool-routing.md` ↔ `services-and-access.md`
- Detection de staleness via `Last verified: YYYY-MM-DD` footer
- Modes: `--dry-run`, `--populate`, `--check`

#### CARL RULE_9 — Reference Files Discipline
- Routing automatique vers le bon layer (L1/L2/L3) selon la tache
- Enforce la co-mise-a-jour dans le meme commit
- Detection de staleness : corriger avant de travailler

#### Session-gate 13 → 15 checks
- Check 14 : staleness des fichiers de reference (Last verified > 30 jours)
- Check 15 : cross-reference MCP sync (tool-routing ↔ services-and-access)

#### Execution quality — layer awareness
- Les agents GSD lisent le bon layer de reference avant de toucher l'infra ou le code
- Skip heuristic si `docs/references/` n'existe pas ou contient des placeholders

### Changed
- `init-project.sh` : genere `docs/references/` + copie le skill reference-audit
- `CLAUDE.md.template` : nouvelle "Regle de reference" + table des fichiers
- `docs/GUIDE.md` : section 13 (reference files), 15 sections total, 8 skills, 10 regles CARL
- Rules projet-specifiques commencent a RULE_10 (au lieu de RULE_9)
- `execution-quality.md` : nouvelle section "Reference Layer Awareness"

---

## [2.1.0] — 2026-03-16

Execution quality hybridation — ce-work patterns injectes via rules.

### Added
- `.claude/rules/execution-quality.md` — 3 patterns : system-wide test check, post-deploy monitoring, commit heuristics
- Hybridation GSD x ce-work via `.claude/rules/` (pas remplacement)

### Changed
- `CLAUDE.md.template` — section outils actifs mise a jour

---

## [2.0.0] — 2026-03-16

Release majeure — systeme de retention complet, hooks, quality score.

### Added

#### Systeme de retention 4 couches
- `LESSONS.md` — cache chaud des lecons (cap 50, format quand/faire/parce que)
- `DECISIONS.md` — registre ADR-light des decisions (cap ~25, tags, champ Rejete)
- `memory/MEMORY.md` — etat courant de session (lu en premier, mis a jour en fin)
- Integration Supermemory pour archivage cross-projet

#### 7 skills inclus
- `/lesson` — capture rapide de lecons en 10 secondes
- `/session-gate` — validation mecanique de MEMORY.md (13 checks)
- `/context-checkpoint` — sauvegarde rapide avant coupure de session
- `/project-bootstrap` — injection cross-projet de lecons depuis Supermemory
- `/pre-flight` — review multi-agent des plans (4 agents paralleles)
- `/context-manager` — reference de gestion du contexte
- `/project-sync` — synchronisation avec outils externes

#### Hooks anti-compaction
- `pre-compact.sh` — snapshot MEMORY.md avant compaction du contexte
- `session-start.sh` — re-injection automatique de MEMORY.md + LESSONS.md au demarrage

#### Rules et discipline
- `.claude/rules/tool-routing.md` — table de routing des outils + anti-patterns + discipline MCP
- `.claude/rules/flywheel-workflow.md` — workflow de capitalisation
- CARL RULE_0-8 : flywheel, credentials, closure, deviation, tool routing, MCP discipline, planning recall

#### Closure protocol (7 etapes)
- Quality score mecanique (CLEAN/ROUGH)
- Capture automatique des decisions dans DECISIONS.md

#### Documentation
- `docs/GUIDE.md` — guide complet (14 sections, architecture, workflows, FAQ)
- `README.md` — quick start + structure

#### Init script
- `init-project.sh` — genere un projet complet avec tous les templates, skills, hooks, rules, et CARL
