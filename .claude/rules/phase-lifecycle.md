---
paths:
  - ".planning/phases/**/*"
  - ".planning/ROADMAP.md"
  - ".planning/state.yml"
  - "config/{{rag_backend}}-registry.json"
  - ".claude/hooks/session-start.sh"
  - ".claude/hooks/post-knowledge-sync.sh"
---

# Phase Lifecycle — Règles de gouvernance

> Source canonique du cycle de vie des phases GSD.
> Path-scoped : ne se charge que quand Claude touche une phase, la roadmap, state.yml, ou les hooks qui manipulent les phases.
> `CLAUDE.md` et `governance.md` pointent ici.

## Structure des répertoires

Tous les dossiers de phase vivent dans `.planning/phases/{subdir}/{phase-name}/`

| Sous-dossier | Définition | Critères |
|---|---|---|
| `planned/` | Phase définie, aucun plan exécuté | Aucun `*-PLAN.md` marqué `[x]` dans ROADMAP.md |
| `active/` | Phase en cours — travail partiel | Au moins 1 plan `[x]` dans ROADMAP.md, phase non complète |
| `complete/` | Phase vérifiée terminée | Marker phase `[x]` dans ROADMAP.md **OU** note `*(COMPLETE)*` dans la section OU `Done ✓` dans LIVE-ARCHITECTURE.md |

**Règle absolue :** Aucun dossier de phase ne doit exister à la racine `.planning/phases/` (sauf `active/`, `complete/`, `planned/`).

## Déclencheurs de mouvement

> **Note de routing :** Les déclencheurs ci-dessous décrivent les mouvements mécaniques que font les substeps GSD. Pour **préparer une phase complète**, l'entry point canonique est `/prepare-phase` qui orchestre `/gsd:discuss-phase` + `/gsd:plan-phase` + reviews + pre-flight. Ne pas proposer les substeps en standalone sauf exemption. Voir `.claude/rules/workflow-guide.md` § Phase Preparation — Default Orchestrator.

| Événement | Action |
|-----------|--------|
| `/gsd:plan-phase N` crée un nouveau dossier | Créer dans `planned/` |
| Premier plan d'une phase exécuté (`gsd:execute-phase`) | `git mv planned/{phase} active/{phase}` |
| Phase complète (UAT pass + closure) | `git mv active/{phase} complete/{phase}` |
| Nouvelle phase sans historique de plans | Créer directement dans `planned/` |

## Mise à jour obligatoire dans le même commit

Quand un dossier de phase est déplacé entre `planned/`, `active/`, `complete/` :

1. **`git mv`** — préserver l'historique git (ne jamais `cp` + `rm`)
2. **`config/{{rag_backend}}-registry.json`** — mettre à jour les chemins dans `files:` (remplacement du préfixe du sous-dossier)
3. **CONTEXT.md frontmatter** — mettre à jour le champ `status: planned|active|complete`
4. **ROADMAP.md** — si la phase devient `complete`, cocher `[x]` au niveau phase

Ces 4 changements doivent être dans le **même commit**.

## CONTEXT.md frontmatter obligatoire

Tout dossier de phase doit avoir un `CONTEXT.md` avec au minimum `phase`, `status`, et la **déclaration de dépendances explicite** (`autonomy`) :

```yaml
---
phase: "XX.Y"
status: planned | active | complete
autonomy: standalone | linked      # REQUIS — jamais inféré de l'absence de depends_on
# --- si autonomy: linked, au moins un des deux blocs ci-dessous ---
depends_on:                        # edge directionnel amont → cette phase
  - phase: "XX.Y"
    kind: hard | soft              # hard = bloque plan/exec ; soft = préférence de séquencement ("avant OU avec", ne pas fold)
    why: "une ligne — la raison réelle, pas le défaut positionnel GSD"
coordinates_with: ["XX.Y"]         # surface partagée, non-directionnel (pas un blocker)
blocks: ["XX.Y"]                   # optionnel — reverse edge (cette phase bloque X)
# --- optionnel : garde-fou run-budget de la boucle de validation Step-3 d'execute-phase-auto ---
run_budget:
  max_fix_iterations: 8            # cap déterministe de la boucle fix supervisée (défaut 8 si absent ; iteration 0 = batch initial, exclue)
---
```

Le champ `status` doit correspondre au sous-dossier parent (`active/` → `status: active`).

Le bloc `run_budget:` est **optionnel** — il plafonne la boucle de validation Step-3 d'`/execute-phase-auto` (cap déterministe `max_fix_iterations`, halt-only, pas de resume in-loop). Un bloc présent mais malformé/hors-borne → **hard halt** (`PARSE_HALT`), jamais de fallback silencieux vers le défaut. Détail : `.claude/skills/execute-phase-auto/references/validation-loop.md` ; design + cross-vendor GO : `.claude/workspace/2026-06-04-execute-phase-auto-run-budget-spec.md`.

### Dépendances : frontmatter autoritaire, ROADMAP réconcilié (DEC-045)

Le `Depends on:` du `ROADMAP.md` est **généré par GSD** — `/gsd:add-phase` chaîne positionnellement chaque nouvelle phase à la précédente. C'est du **bruit d'auto-link, pas une intention**. La **source de vérité des dépendances est le frontmatter CONTEXT.md**, pas le ROADMAP.

- **`autonomy:` est REQUIS et explicite.** `standalone` est une *assertion humaine* « aucune dépendance réelle », distincte de « personne n'a rempli le champ ». L'absence de `depends_on` ne signifie **jamais** standalone par défaut — c'est précisément l'ambiguïté que ce champ supprime.
- **`kind: hard|soft`** capture la distinction qui compte : un `hard` bloque planning/exécution ; un `soft` est une préférence de séquencement (ex : « 37 valide les oracles, 39 les exécute — séquencer, ne pas fold »).
- **`why:` obligatoire** sur chaque edge — sans rationale, on ne distingue pas une vraie dépendance d'un auto-link (l'asymétrie « ligne ROADMAP avec justification vs sans » est exactement le tell qui a révélé le gap).
- **Réconciliation au plan-time.** Tout edge `Depends on:` du ROADMAP doit être miroité dans le frontmatter — confirmé comme réel (avec `why`) ou corrigé/supprimé comme auto-link. Ne jamais laisser ROADMAP et frontmatter diverger en silence. Le skill `gsd-analyze-dependencies` peut semer les vraies deps, mais le frontmatter tranche.
- **Ne jamais modifier la logique d'auto-link GSD** (`/gsd:add-phase`, template-synced — cf. `memory/feedback_no_upstream_modification.md`). On override **en aval** via le frontmatter + le gate.

**Hard gate (structurel).** `scripts/create-plan-checker-pass.sh` — le helper canonique qui pose le marqueur `PLAN-CHECKER-PASS` — **refuse** de le créer si le CONTEXT.md de la phase n'a pas de champ `autonomy:` valide (et, si `linked`, au moins un bloc `depends_on`/`coordinates_with`). La **complétude structurelle** est bloquante ; la *justesse sémantique* de la dépendance reste du ressort de l'adversarial review (cf. `verification-discipline.md` § « Plan-Checker ≠ Adversarial Review ») — conforme à `feedback_soft_gates_over_hard_blocks` (« hard rules technical only »). Backfill **lazy** : une phase acquiert le champ à son prochain passage plan-checker ; pas de migration de masse des phases déjà passées.

## Plan-Phase Association (docs/plans/)

Les fichiers `docs/plans/*.md` sont des plans pré-GSD ou des specs d'implémentation. Chaque plan doit être associé à une phase via frontmatter `phase: "XX.Y"`.

**Règles :**

1. **Tout nouveau plan** dans `docs/plans/` DOIT avoir un champ `phase:` dans son frontmatter YAML
2. **CONTEXT.md cross-ref** : quand `/gsd:discuss-phase` ou `/gsd:plan-phase` crée un CONTEXT.md pour une phase qui a des plans dans `docs/plans/`, ajouter une section `## Pre-GSD Plans` avec les liens relatifs
3. **Archive** : quand la phase passe en `complete/` ET le plan est `completed`/`superseded`, `git mv docs/plans/{file} docs/plans/archive/` et mettre `status: archived` dans le frontmatter
4. **Standalone** : un plan sans association phase (ex: ops plan non rattaché) garde `phase:` vide mais doit documenter pourquoi

Le schéma frontmatter obligatoire pour `docs/plans/` est défini dans `docs/references/source-of-truth-map.md` § "Frontmatter Schema".

**Index :** `docs/plans/INDEX.md` est la table de correspondance plan↔phase, mise à jour quand un plan est créé, archivé, ou réassocié.

## Brainstorm-Phase Association (docs/brainstorms/)

Les fichiers `docs/brainstorms/*.md` sont des artefacts structurés upstream-of-GSD qui peuvent alimenter une phase via `/gsd:add-phase`. Chaque brainstorm consommé par une phase doit être lié via frontmatter `linked_phase: "XX.Y"`.

**Règles :**

1. **Création** : un nouveau brainstorm dans `docs/brainstorms/` DOIT avoir les champs `date:`, `topic:`, `focus:`, `status: active` dans son frontmatter YAML
2. **Lien brainstorm → phase** : quand `/gsd:add-phase` crée un CONTEXT.md, ajouter `origin:` dans le frontmatter du CONTEXT.md pointant vers le brainstorm source ; déplacer le brainstorm : `git mv docs/brainstorms/{file}.md docs/brainstorms/linked/` et mettre `status: linked` + `linked_phase: "XX.Y"` dans son frontmatter
3. **Archival post-phase** : quand la phase passe en `complete/`, proposer (step 4c du closure protocol) : `git mv docs/brainstorms/linked/{file}.md docs/brainstorms/archived/`, mettre `status: archived` + `archived_on:`
4. **Rejection** : un brainstorm qui ne convertit pas en phase → `git mv docs/brainstorms/{file}.md docs/brainstorms/rejected/`, mettre `status: rejected` + `rejected_reason:`

Le schéma frontmatter obligatoire pour `docs/brainstorms/` et `docs/ideation/` est défini dans `docs/references/source-of-truth-map.md` § "Frontmatter Schema".

## Hooks — patterns de fichiers

Les hooks (`post-knowledge-sync.sh`, `session-start.sh`) doivent utiliser des patterns récursifs :

| Pattern | Cible | Collection |
|---------|-------|------------|
| `.planning/phases/*/*/*SUMMARY*` | SUMMARY dans n'importe quel sous-dossier | `knowledge` |
| `.planning/phases/*/*/*` | Tout fichier de phase | `planning` |
| `.planning/phases/*/*` | Fichiers directement dans un sous-dossier | `planning` |

**Ne jamais utiliser** `.planning/phases/*SUMMARY*` ou `.planning/phases/*` — ces patterns ne traversent pas les sous-dossiers.

## {{rag_backend}}-registry.json — watched_paths

Le champ `planning.watched_paths` doit référencer `active/` :

```json
"planning": [
  ".planning/phases/active/",
  "memory/MEMORY.md"
]
```

Le champ `knowledge.watched_paths` doit utiliser le glob récursif :

```json
"knowledge": [
  "LESSONS.md",
  "DECISIONS.md",
  "docs/solutions/",
  ".planning/phases/**/*SUMMARY*.md"
]
```

## Règle de maintenance

Mettre à jour ce fichier dans le même commit si :
- La définition de `planned/active/complete` change
- Un nouveau déclencheur de mouvement est ajouté
- Les patterns de hooks changent
- Le schéma frontmatter CONTEXT.md change
- Les règles plan-phase association changent (frontmatter `docs/plans/`, archivage, cross-ref)
- Les règles brainstorm-phase association changent (frontmatter `docs/brainstorms/`, transitions, subdirs)

## Ce qui ne va pas ici

- Inventaire des phases actives → `ROADMAP.md`
- Détail des plans → `{phase}/CONTEXT.md`
- État de la session courante → `.planning/state.yml`
- Règles MCP/intégrations → `.claude/rules/governance.md`
