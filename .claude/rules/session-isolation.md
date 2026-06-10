# Session Isolation — Defense en deux couches contre les collisions sessions Claude paralleles

> Source canonique pour le mécanisme Phase 24.9. Path-scoped soft rule.
> Adjacent : `.claude/rules/parallel-worktree-discipline.md` (discipline générale worktrees), `.claude/rules/skill-gate.md` (pattern `.skill-locks/` mirror).
> Source canonique : ce fichier (gagne en cas de conflit).
> Design amendé post-adversarial review (Codex round-1 + Gemini + Codex round-2). Ne pas régresser à des patterns plus simples sans ré-évaluer les flaws.

## Quand cette règle se déclenche

Auto-load quand Claude touche :

- `.session-locks/` (lecture, écriture, cleanup)
- `.claude/hooks/session-lock-claim.sh`, `.claude/hooks/session-lock-enforce.sh`, `.claude/hooks/pre-tool-use-git-commit.sh`, `.claude/hooks/session-end.sh`
- `.claude/hooks/lib/session-lock.sh` (helper sourceable)
- `.claude/settings.json` § `hooks.SessionStart`, `hooks.UserPromptSubmit`, `hooks.PreToolUse`, `hooks.SessionEnd`
- Tout fichier qui mentionne `SKIP_SESSION_LOCK`
- `tests/session-isolation/` (suite de tests Bash)

## Scope — ce qui est couvert et ce qui ne l'est pas

**Couvert :**

- Sessions Claude Code parallèles dans des working trees standard (linked worktrees du même repo, ou main + sandboxes)
- Détection cross-worktree d'une collision sur la même branche (lockdir au repo main, vu par toutes les linked worktrees)
- Blocage à `UserPromptSubmit` quand 2 sessions actives partagent la branche
- Blocage à `git commit` (toutes variantes) quand session_id mismatch

**Hors scope (D-S4) :**

- **Bare repos** — `git rev-parse --git-common-dir` retourne le bare repo lui-même, son parent est arbitraire, la résolution `<repo-main>` casse
- **Submodules** — `git rev-parse --git-common-dir` retourne `<super>/.git/modules/<sub>`, son parent n'est pas le submodule root
- **Multi-machine** — pas de coordination cross-host (pas de pre-receive hook server-side)

Si {{PROJECT}} adopte un de ces patterns → revisiter D-B10 avec le fix Codex round-2 P1.2 (utiliser `git rev-parse --path-format=absolute --git-common-dir` directement, pas son parent). Aucun bare repo ni submodule actuellement dans le projet.

## Mécanisme — défense en deux couches

### Layer A — Proposition proactive (workflow-guide.md)

Référence canonique : `.claude/rules/workflow-guide.md` § Worktree Sandbox — proposition proactive (Trigger 1 + Trigger 2). Pas dupliqué ici.

Trigger 2 cible spécifiquement les investigations shell-heavy avec control-flow où l'allow list devient un whack-a-mole.

### Layer B — Enforcement mécanique (lock files + 4 hooks)

Design amendé post-adversarial review (Codex round-1 + Gemini round-1 + Codex round-2). Chacun des points ci-dessous est load-bearing — un seul écart re-introduit un flaw FATAL identifié par les reviewers.

#### Lockdir branche-only

Format : `<repo-main>/.session-locks/{branch-slug}/lock.yml`

- **Lock key = branche seulement** (D-B1). PAS `(worktree, branch)` — sinon 2 worktrees sur même branche bypass le lock. C'est exactement le pattern de collision #1 du brainstorm Phase 24.9.
- `branch-slug` = `git branch --show-current | tr / .` (point n'est pas valide dans un nom de branche git, donc safe filename ET injectif — `feature/foo` ≠ `feature.foo` ≠ `feature-foo`).
- Le `worktree` (chemin absolu) est metadata diagnostic dans le YAML, **pas** dans la clé.
- `<repo-main>` résolu via `git rev-parse --git-common-dir` parent (D-B10) — invariant à `pwd` à l'intérieur du worktree, donc `cd src/` ne casse pas la résolution. **Jamais** `basename $(pwd)`.
- Toutes les linked worktrees du même repo voient le **même** `.session-locks/`, exposant les collisions cross-worktree.
- `.session-locks/` est gitignored (session-scoped, recréé à chaque session). Pattern parity avec `.skill-locks/` (cf. `skill-gate.md`).

#### Lock YAML format

```yaml
session_id: "<from stdin .session_id>"
started: "<ISO 8601 UTC>"
last_seen: "<ISO 8601 UTC — heartbeat>"
worktree: "<chemin absolu — diagnostic only>"
branch: "<nom de branche complet — diagnostic only>"
```

**Champ `pid` retiré** (D-B8). `$$` du hook est éphémère (mort dès SessionStart exit), donc PID-based était fatal (lock né stale, reaper instantané). Liveness via `last_seen` mtime, pas PID.

#### Liveness = mtime heartbeat

- `UserPromptSubmit` `touch`e le lockdir à chaque user prompt → mtime updated.
- `PreToolUse` (any tool) `touch`e aussi le lockdir si lock owned by us — couvre les long-turns > 2h sans nouveau prompt (D-B8 amendment, Codex round-2 P1.3).
- **Stale = stat mtime du lockdir > 2h** (`-mmin +120` POSIX, D-B9).
- Détection : `find <repo-main>/.session-locks/<branch-slug> -maxdepth 0 -mmin +120` — retourne path si stale.

Bénéfices :

- Robuste aux PIDs éphémères des hooks
- Pas de problème de PID reuse
- Solo-dev friendly : sessions actives = locks fresh par construction
- Sessions idle > 2h = lock nettoyé automatiquement
- Sessions très longues légitimes (debug 4h+) : override `SKIP_SESSION_LOCK=1` (D-B12)

#### Atomic claim — empty-lockdir grace

Pattern d'écriture (D-B14, Codex round-2 P0) :

1. `mkdir <repo-main>/.session-locks/<branch-slug>/` — atomic POSIX
2. Write `lock.yml.tmp` — partial state OK
3. `mv lock.yml.tmp lock.yml` — atomic (même filesystem)

Le lockdir peut exister sans `lock.yml` dans 2 cas :

- **Claim-in-progress** : autre session entre `mkdir` et `mv`. Grace : si mtime < 30s → traiter comme claim-in-progress (exit 0, laisser finir).
- **Orphan** : crash entre `mkdir` et `mv`. Si mtime ≥ 30s → reclaim (`rmdir` puis retry `mkdir`).

#### Les 4 hooks

| Hook | Rôle | Bloque ? |
|---|---|---|
| `SessionStart` (`session-lock-claim.sh`) | Claim atomique via `mkdir` ; warn si collision détectée | Non — Claude Code spec : `exit 2` non-bloquant pour SessionStart |
| `UserPromptSubmit` (`session-lock-enforce.sh`) | Heartbeat (`touch` lockdir) + claim si missing + bloque si collision active | **Oui — c'est le vrai enforcement** (D-B11) |
| `PreToolUse` matcher `Bash` (`pre-tool-use-git-commit.sh`) | Détection **interne** regex POSIX du `git commit` ; vérifie session_id matche avant commit | Oui — D-B6 amendé |
| `SessionEnd` (`session-end.sh`) — pas `Stop` | Cleanup lock seulement si session_id matche | N/A |

**Pourquoi `SessionEnd` et pas `Stop`** (D-B7) : `Stop` fire à chaque fin de turn et supprimerait le lock entre chaque user prompt = bug majeur. `SessionEnd` fire une seule fois en fin de session.

#### Matcher Bash sans `if` (D-B6 amendé)

Le hook `PreToolUse` matche **TOUT `Bash`**, pas `if: "Bash(git commit *)"`. Le matcher narrow rate :

- `cd repo && git commit`
- `env GIT_EDITOR=true git commit`
- `git -c user.name=x commit`
- `/usr/bin/git commit`

La détection `git commit` est faite **DANS** le script via regex POSIX qui couvre toutes ces variantes ET exclut `git commit-tree` / `git commit-graph`. Sur tout Bash non-git-commit → exit 0 immédiat (~5ms).

#### Fail-safe explicite (D-B13)

**Iron Law :** tous les 4 hooks, sur tout path d'erreur → `exit 0` (allow). Bloquer (`exit 2`) **uniquement sur evidence positive de collision** (lock parsé proprement, session_id mismatch confirmé, mtime ≤ 2h confirmé).

Liste exhaustive des paths qui DOIVENT exit 0 :

- `jq -r '.session_id'` retourne empty / null / fail
- Helper script `lib/session-lock.sh` missing ou unreadable
- `lock.yml` exists mais YAML invalide / champ session_id absent
- `git rev-parse --git-common-dir` fail (pas un repo, repo corrompu, bare repo)
- `mkdir` fail pour raison autre que EEXIST (permissions, fs full)
- `touch`/`stat`/`find` fail
- Lockdir existe mais lock.yml manquant ET mtime < 30s (claim-in-progress autre session — TOCTOU race grace)
- Toute autre erreur shell non-anticipée

**Justification (Gemini F5 fail-deadly) :** un bug du hook ne doit JAMAIS lock l'opérateur out de ses propres sessions. Le système est **fail-open by design**. Asymétrie clairement en faveur du fail-open : faux négatif (collision non détectée) = rare + override dispo ; faux positif (futures sessions bloquées par bug) = catastrophique.

#### Worktrees managés exclus

`.claude/worktrees/agent-*` et `.worktrees/promote-*` sont éphémères et auto-managés (cf. `parallel-worktree-discipline.md` § Cas particulier). Le hook les détecte et skip le claim.

## Override — SKIP_SESSION_LOCK=1

Pour les cas légitimes où l'isolation est gênante :

- Opérateur sait qu'il opère seul sur la branche → `SKIP_SESSION_LOCK=1 claude`
- Automation locale / CI script → exporter une fois pour la session
- Session > 2h légitime (debug long, replay) où l'auto-cleanup deviendrait un faux positif

Tous les 4 hooks honorent le flag uniformément (D-B12).

### Syntaxe shell critique (Codex F8)

L'env var DOIT être PLACÉE AVANT `bash` (PAS avant `echo`) lors des invocations directes :

```bash
# ✓ CORRECT — env appliqué à bash → hook honore le flag
echo '{"session_id":"foo"}' | SKIP_SESSION_LOCK=1 bash .claude/hooks/session-lock-enforce.sh

# ✗ INCORRECT — env appliqué à echo, hook reçoit env vanilla → flag ignoré
SKIP_SESSION_LOCK=1 echo '{"session_id":"foo"}' | bash .claude/hooks/session-lock-enforce.sh
```

Logger l'usage abusif via `bash-commands.log` (post-tool hook existant) si abus suspecté.

## Rollback — désactivation rapide

Procédure complète documentée dans `.planning/phases/active/24.9-session-isolation-enforcement/24.9-03-ROLLBACK.md` (créé par Plan 03 Task 5).

Résumé des escape hatches :

1. **`SKIP_SESSION_LOCK=1 claude`** — démarre une session en bypass total (< 30s)
2. **`rm -rf <repo-main>/.session-locks/<branch-slug>/`** — cleanup d'un lock orphelin (< 1 min)
3. **`cp .claude/settings.json.bak-pre-24.9 .claude/settings.json`** — restore backup (< 2 min)
4. **Désactivation sélective via `jq`** (UserPromptSubmit seul, ou hook git commit seul, ou SessionEnd seul) — voir ROLLBACK.md
5. **`git checkout HEAD -- .claude/settings.json`** — clean state via git

## Troubleshooting

| Symptôme | Cause probable | Fix |
|---|---|---|
| Toute session bloquée au 1er prompt | Bug `session-lock-enforce.sh` qui ignore D-B13 fail-safe | `SKIP_SESSION_LOCK=1 claude` puis investiguer Plan 02 hooks |
| Lock orphelin (session morte mais lock présent) | `SessionEnd` n'a pas fire (crash, kill -9, `git worktree remove --force` sans `/quit` préalable) | Auto-cleanup > 2h via mtime stale (D-B9). Manuel : `rm -rf <repo-main>/.session-locks/<branch-slug>/` |
| 2e session sur même branche pas bloquée | Hook `UserPromptSubmit` non actif dans settings.json | Vérifier `.claude/settings.json` § hooks ; redémarrer la session |
| Collision spurious dans worktree managé `.claude/worktrees/agent-*` | Hook ne skippe pas les worktrees managés | Bug — corriger dans `session-lock-claim.sh` |
| `git commit` bloqué malgré session unique | Lock écrit avec mauvais session_id | `rm -rf .session-locks/` puis redémarrer Claude |
| Variant `cd repo && git commit` ne déclenche pas le hook | Matcher narrow `if: "Bash(git commit *)"` (anti-pattern) | Vérifier que settings.json a matcher `Bash` SANS `if` (D-B6 amendé). Détection interne au script via regex POSIX |
| Lockdir résolu dans le mauvais path (`<repo>/src/.session-locks/`) | Hook utilise `basename $(pwd)` au lieu de `git rev-parse --git-common-dir` | Bug Plan 02 D-B10 — vérifier `lib/session-lock.sh` `compute_lock_dir` |
| Hook crash sur YAML corrupt → bloque session | Bug fail-safe D-B13 — un path d'erreur fait `exit 2` au lieu de `exit 0` | Investiguer `lib/session-lock.sh` paths d'erreur, tous doivent `exit 0` |
| Bare repo : lockdir résolu hors du repo (parent du bare) | Cas D-S4 hors scope | {{PROJECT}} n'utilise pas de bare repos. Si adopté → fix Codex round-2 P1.2 |
| Slug collision (`feature/foo` et `feature-foo` partagent le même lock) | Slug computation = `tr / -` (anti-pattern) | Vérifier que `compute_branch_slug` utilise `tr / .` (Codex round-2 P1.4 — point n'est pas valide dans un nom de branche, donc safe filename + injectif) |

## Adjacent rules

- `.claude/rules/parallel-worktree-discipline.md` — discipline générale worktrees parallèles (R1-R4 : branche canonique, sync, push backup, worktree discovery)
- `.claude/rules/skill-gate.md` — pattern `.skill-locks/` que `.session-locks/` mirror
- `.claude/rules/workflow-guide.md` — Layer A (proposition proactive worktree)
- `.claude/rules/governance.md` — table d'enforcement où session-isolation est listée
- `.claude/rules/governance-index-discipline.md` — co-update obligation pour `docs/GOVERNANCE.md`

## Règle de maintenance

Mettre à jour ce fichier dans le même commit si :

- Un nouveau hook event Claude Code devient disponible et est intégré au mécanisme
- L'override `SKIP_SESSION_LOCK=1` change de nom ou de sémantique
- Le format du lockdir / lock.yml change (clé, champs)
- L'un des scripts hook est renommé ou remplacé
- Le seuil mtime stale (2h) change
- Le fail-safe D-B13 reçoit une nouvelle catégorie d'erreur à honorer
- Le matcher `PreToolUse` change de stratégie (broader / narrower)
- Le scope D-S4 évolue (si {{PROJECT}} adopte bare repos ou submodules)

## Ce qui ne va pas ici

- Détail d'implémentation des hooks → lire `.claude/hooks/session-lock-*.sh` directement
- Tests unitaires → `tests/session-isolation/`
- Patterns de discipline worktree → `parallel-worktree-discipline.md`
- Trigger 2 wording (Layer A) → `workflow-guide.md`
- Rollback step-by-step détaillé → `24.9-03-ROLLBACK.md`
- Adversarial review process value → `LESSONS.md` § [git-workflow] entrée Phase 24.9

## Références

- Phase 24.9 CONTEXT (decisions D-A1..D-A6, D-B1..D-B14, D-S1..D-S4, D-P1..D-P3) : `.planning/phases/active/24.9-session-isolation-enforcement/24.9-CONTEXT.md`
- Phase 24.9 RESEARCH : `.planning/phases/active/24.9-session-isolation-enforcement/24.9-RESEARCH.md`
- Hooks Claude Code spec : https://docs.claude.com/en/docs/claude-code/hooks
- Pattern mirror : `.claude/rules/skill-gate.md`
- Adversarial review process : LESSONS.md § [git-workflow] entrée Phase 24.9 + adjacents
