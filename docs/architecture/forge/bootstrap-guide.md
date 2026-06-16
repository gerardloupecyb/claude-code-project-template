---
title: "FORGE — Bootstrap Guide"
status: active
last_verified: 2026-06-15
owner: {{OWNER}}
phase: 24
slug: forge
---

# FORGE — Bootstrap Guide

> Comment adopter FORGE dans un nouveau projet, via le scaffolder `forge-init.sh`.
> Un seul outil instancie le template, résout l'identité du projet de façon
> injection-safe, et arme les gates ; `check-setup.sh` vérifie que l'installation
> est saine (verdict GREEN/RED déterministe).

---

## Scope honnête (D-10)

Ce template est **dé-identifié** (l'identité du projet source est retirée — noms, comptes,
hôtes, vendeurs tokenisés en `{{PLACEHOLDER}}`) et **sans gate de stack hardcodé** (les
domaines protégés ne sont pas pré-câblés : `protected_domains` / `gated_mcp` arrivent vides,
remplis par projet via le questionnaire de déploiement).

Il n'est **PAS** « stack-neutre » au sens magique du terme. Le modèle opérationnel reste
celui de FORGE : **FORGE + GSD + {{RAG_BACKEND}} (RAG) + CARL**. Adopter ce template, c'est adopter
ce modèle opérationnel — pas un squelette agnostique qui marcherait identiquement sur
n'importe quelle stack. Les exemples de stack (cloud / workflow engine / CRM…) sont
tokenisés, mais la **forme** du système (mémoire persistante, knowledge RAG, discipline de
phases, gates de domaine) est ce que vous adoptez.

> ⚠️ Ne pas lire ce guide comme « FORGE marche pour n'importe quelle stack ». Il marche pour
> un projet qui **adopte le modèle opérationnel FORGE** et y instancie sa propre stack.

---

## Prerequis

- Claude Code installé (`claude` CLI)
- Git
- `jq` — le scaffolder lit l'allowlist dérivée et résout les tokens (substitution injection-safe `jq --arg`)
- `gitleaks` (recommandé) — backstop fail-closed pendant la résolution (S/F1)

---

## Quick start

```bash
# 1. Cloner le template
git clone {forge-template-repo} forge-template

# 2. Scaffolder un nouveau projet
#    --tier 1=Foundation · 2=+Governance · 3=+Intelligence (défaut, additif)
forge-template/forge-init.sh --tier 2 "Mon Projet" monprojet "kw1,kw2,kw3"

#    Pour remplir d'un coup le vocabulaire de stack (workflow engine, cloud, CRM,
#    compliance…) via les réponses du questionnaire de déploiement (Plan 05) :
#    forge-template/forge-init.sh --tier 2 --answers answers.json "Mon Projet" monprojet "kw1,kw2"

# 3. Vérifier que l'installation est GREEN
cd "Mon Projet" && ../forge-template/check-setup.sh .
```

`forge-init.sh` (remplace toute copie manuelle `cp …`) :

- copie les fichiers universels (skills / rules / hooks / outillage forge) **pilotés par
  l'allowlist dérivée** `.forge/sync-allowlist.json` — aucune liste codée en dur, **aucun skill
  de domaine** ({{cloud_provider}} / {{WORKFLOW_ENGINE}} / {{crm_platform}}…) ne peut être poussé ;
- résout les `{{TOKENS}}` de façon **injection-safe** sur tout l'arbre copié (réponses opérateur
  jamais exécutées, validité JSON/YAML **fail-closed**, passe gitleaks sur l'arbre matérialisé) ;
- place `.claude/settings.json` (**NO-CLOBBER** — n'écrase jamais un settings.json existant) +
  installe `.githooks` (`core.hooksPath`) → `pre-tool-use` bloque pour de vrai un Write vers un
  domaine protégé configuré ;
- **tripwire** : sort en **RED** (exit ≠ 0) en listant tout `{{TOKEN}}` de structure non résolu —
  fournissez le questionnaire (`--answers`) pour un init GREEN.

---

## Les tiers (additifs — `maturity-model.md` pour le détail des composants)

| Tier | `--tier` | Ce que vous obtenez |
|------|----------|---------------------|
| 1 Foundation | `1` | mémoire persistante, verification-discipline, cognitive-patterns, todo, lesson, commit-push, session-start |
| 2 Governance | `2` | + skill-gate, supply-chain-audit, pre-flight, sparc, prepare-phase, `.githooks`, gates de domaine |
| 3 Intelligence | `3` (défaut) | + knowledge ({{RAG_BACKEND}} / RAG), graphify, swarm-patterns, task-router, code-xray |

> **Non fournis par le template** (project-specific jusqu'à la genericization Phase 22.1) :
> `governance.md` et `tool-routing.md`. Rédigez les vôtres (obligations de co-update +
> caps / pagination / anti-patterns MCP de **votre** stack).

---

## Configurer les domaines protégés

Les domaines protégés arrivent **vides**. Ils sont remplis par projet via le questionnaire de
déploiement (Plan 05), qui peuple `.claude/gate.config.json` ; les hooks (`pre-tool-use.sh`,
`pre-mcp-gate.sh`) sourcent ce fichier au runtime — la logique de domaine n'est **jamais**
hardcodée dans `settings.json`. `check-setup.sh` reste **RED** tant que :

- `project_name` est vide (**jamais waivable**), OU
- `protected_domains` est vide **et** sans `_no_protected_domains_affirmed: true`, OU
- `compliance_frameworks` est vide **et** sans `_no_compliance_frameworks_affirmed: true`.

L'affirmation est un **flag positif par préoccupation** : supprimer une note de sentinelle sans
poser le flag laisse le projet RED (pas de bypass « delete-without-affirm »).

---

## Tier 4 — Domain (project-specific, hors template)

Créer les skills domain-architect spécifiques au projet :

1. Identifier les domaines sensibles du projet
2. Créer `.claude/skills/{domain}-architect/SKILL.md` (5 sections standard)
3. Déclarer le domaine dans `.claude/gate.config.json` (`protected_domains`) — pas dans `settings.json`
4. Ajouter les CARL rules métier dans `.carl/{domain}`
5. Re-vérifier : `check-setup.sh .`

---

## Mise à jour depuis le template

```bash
forge-template/sync-project.sh "/chemin/du/projet"           # dry-run (revue)
forge-template/sync-project.sh "/chemin/du/projet" --apply    # overwrite universels + re-résolution
```

Pilotée par la **même** allowlist dérivée. N'écrase **jamais** les fichiers consumer-owned
(CLAUDE.md, `*.config.json`, `settings.json`, protected). Écrit un marqueur de version
(`.forge/forge-template-version`, commit-SHA) et re-résout les tokens depuis `.forge/answers.json`
après overwrite. Pas de 3-way merge (différé en 22.1).

---

## Post-bootstrap — Vérification

```bash
cd "Mon Projet" && ../forge-template/check-setup.sh .
```

GREEN exige : `project_name` rempli · domaines remplis ou affirmés · compliance remplie ou
affirmée · `settings.json` présent · `core.hooksPath == .githooks`. Sortie non-zéro sur RED.
Idempotent : corriger la config à la main puis relancer bascule en GREEN sans re-questionnaire.

---

## References

- Extraction map : `docs/architecture/forge/extraction-map.md`
- Maturity model : `docs/architecture/forge/maturity-model.md`
- Configuration points : `docs/architecture/forge/configuration-points.md`
- Component registry : `docs/architecture/forge/component-registry.md`
