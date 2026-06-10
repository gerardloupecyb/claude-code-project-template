# Parallel Worktree Discipline

> Path-scoped soft rule. Se charge proactivement quand Claude opère dans un worktree, switch de branche, ou s'apprête à `/gsd-execute-phase`.
> Goal : prévenir les collisions cross-worktree et pertes de travail dans le setup multi-worktree de {{PROJECT}}.

## Contexte

{{PROJECT}} utilise plusieurs worktrees en parallèle pour isoler le travail par phase (Phase 09.1, 12, 15, 16, 27, etc.). Ce design protège l'isolation **filesystem** mais crée 6 sources de collision et confusion si la discipline est absente.

## Les 6 sources de collision

| Risque | Symptôme | Mitigation |
|---|---|---|
| Branches divergentes pour la même phase | `gsd/phase-N-slug` ET `sandbox/phase-N-slug` coexistent | One canonical branch (R1) |
| Sandbox stale | Sandbox HEAD < canonical branch HEAD | Sync avant execution (R2) |
| Branches local-only avec WIP | Worktree perdu = travail perdu | Push -u origin (R3) |
| Édition concurrente fichier partagé | Deux worktrees modifient `.claude/rules/*` | Worktree discovery (R4) |
| Nom de dossier opaque | `{{project}}-sandbox-phase16` ne dit pas quelle phase | Naming canonique (R5) |
| Commits concurrents sur `main` | Ton `git commit` capture autre chose que ton staged | Pathspec strict + sérialisation (R6) |

## R1. Une phase = une branche canonique

Pour chaque phase, planning **et** execution sur la même branche : `gsd/phase-{N}-{slug}`.

- ❌ NE PAS créer `sandbox/phase-{N}` comme branche séparée
- ✓ Le worktree sandbox isole le **filesystem**, pas la branche — il checkout la même branche `gsd/phase-{N}-{slug}` que le main repo
- ✓ Si un sandbox existant est sur une branche distincte (ex : ancien `sandbox/phase-27-knowledge-layer`), reconcilier avant de l'utiliser : merge ou recréer le worktree sur la branche canonique

## R2. Sync sandbox avant execution

Avant `/gsd-execute-phase {N}` dans un sandbox :

```bash
cd /path/to/{{project}}-sandbox-phase{N}
git fetch origin
git status  # verify clean working tree
git merge origin/gsd/phase-{N}-{slug}  # ou rebase si historique linéaire préféré
```

Si la branche sandbox diverge de la branche canonique → **STOP**, reconcilier d'abord. L'auto-execution dans un sandbox stale = source #1 de bugs Phase 15 (cf. MEMORY.md session 2026-04-15b sur nested worktrees).

## R3. Pas de branches local-only sur WIP

Toute branche avec :
- du dirty non commité significatif, OU
- des commits ahead de main représentant du WIP réel

DOIT avoir un upstream remote pour backup :

```bash
git push -u origin {branch}
```

Exception : branches éphémères de test (< 24h, aucun commit utile à conserver).

## R4. Worktree discovery avant edit infra partagée

Avant d'éditer un fichier dans un namespace partagé entre worktrees :

- `.claude/rules/`, `.claude/skills/`, `.claude/hooks/`, `.claude/settings.json`
- `AGENTS.md`, `CLAUDE.md`, `MEMORY.md`, `LESSONS.md`, `DECISIONS.md`
- `docs/standards/`, `docs/references/`, `docs/GOVERNANCE.md`
- `config/*.json`, `.mcp.json`

Lancer un cross-check :

```bash
git worktree list
git worktree list --porcelain | awk '/^worktree / {print $2}' | while read wt; do
  echo "--- $(basename "$wt") ---"
  (cd "$wt" && git status --short -- "<target-file>" 2>/dev/null)
done
```

Si une autre session modifie le même fichier (dirty, staged, untracked) → coordonner ou sérialiser. Sinon collision au merge garantie.

## R5. Naming canonique des worktrees sandbox

**Format obligatoire** pour tout worktree sandbox créé pour le travail d'une phase GSD :

```
{{project}}-sandbox-phase{N}-{slug-court}
```

Sur la branche canonique :

```
gsd/phase-{N}-{slug-complet}
```

### Règles de construction du slug

| Composant | Règle |
|---|---|
| `{N}` | Numéro de phase exact, incluant le décimal et le zéro de tête si présent — `14.2`, `04.7`, `27.1`, `15.1` |
| `{slug-complet}` (branche) | Slug complet de la phase tel qu'il apparaît dans `.planning/phases/{planned,active,complete}/{N}-{slug}/` — pas de troncation |
| `{slug-court}` (dossier) | Slug-complet **tronqué à ~25-30 caractères** en gardant les premiers tokens significatifs et en supprimant les modifiers de queue |

### Modifiers de queue à supprimer pour `{slug-court}`

Liste non exhaustive (drop tout ce qui dilue l'identification) :

- Adjectifs de portée : `-full`, `-batch-1`, `-batch-2` (gardé si c'est l'identifiant principal)
- Verbes d'action de queue : `-hardening`, `-refactor`, `-enforcement`, `-ingestion`, `-migration` (gardé si le slug serait vide sans)
- Suffixes de contexte : `-on-{{project}}-tenant`, `-dogfood`, `-{{hosting_vendor}}`, `-prod`, `-staging`
- Articles : `-of`, `-on`, `-the`

### Exemples canoniques

| Branche (slug complet) | Dossier (slug court) |
|---|---|
| `gsd/phase-14.2-runbook-mode-contract-hardening` | `{{project}}-sandbox-phase14.2-runbook-mode-contract` |
| `gsd/phase-15.1-lago-data-plane-migration-{{hosting_vendor}}` | `{{project}}-sandbox-phase15.1-lago-data-plane-migration` |
| `gsd/phase-27.1-domain-ontology-framework-ingestion` | `{{project}}-sandbox-phase27.1-domain-ontology-framework` |
| `gsd/phase-12.2-sharepoint-governance-audit-dogfood-on-{{project}}-tenant` | `{{project}}-sandbox-phase12.2-sharepoint-governance` |
| `gsd/phase-16.1-batch-1` | `{{project}}-sandbox-phase16.1-batch-1` |
| `sandbox/phase-16-cloudflare-dns` | `{{project}}-sandbox-phase16-cloudflare-dns` |

### Anti-patterns

| ❌ Ne pas faire | ✓ Correct |
|---|---|
| `{{project}}-sandbox` (générique) | `{{project}}-sandbox-phase{N}-{slug-court}` |
| `{{project}}-sandbox-phase14.2` (sans slug) | `{{project}}-sandbox-phase14.2-runbook-mode-contract` |
| `{{project}}-phase16-final` (sans `sandbox`) | `{{project}}-sandbox-phase16.1-batch-1` |
| `{{project}}-sandbox-phase-15.1` (tiret entre `phase` et `{N}`) | `{{project}}-sandbox-phase15.1-lago-data-plane-migration` |
| Slug-court > 35 caractères | Trim modifiers de queue jusqu'à passer sous le seuil |

### Justification

Le nom du dossier est l'identifiant **visible** dans :
- Le tab title de VSCode / Cursor
- L'output de `git worktree list`
- Le prompt zsh dans le terminal
- Le sélecteur de workspace de Claude Code

Sans le numéro de phase **et** un slug significatif, l'opérateur ne peut pas distinguer 9 sandboxes ouverts en parallèle. Le numéro seul (`phase16`) ne suffit pas quand des décimales (`16.1`, `16.2`, `16.3`) coexistent.

### Création (skill `/git-worktree` ou Bash direct)

```bash
git worktree add ../{{project}}-sandbox-phase{N}-{slug-court} gsd/phase-{N}-{slug-complet}
```

### Rename d'un sandbox mal nommé

```bash
git worktree move "<chemin actuel>" "<nouveau chemin canonique>"
```

`git worktree move` préserve le working tree et le HEAD. Casse les sessions IDE/terminal ouvertes sur l'ancien path — coordonner avant l'opération.

### Enforcement — détection de dérive au SessionStart (warn-only)

Le naming R5 est désormais **vérifié mécaniquement** au démarrage de session, en plus d'être documenté ici. Deux scripts globaux (`~/.claude/scripts/`, hors repo car les sandboxes ont 100-400 commits de divergence sur main) :

- `{{project}}-sandbox-title-launcher.sh` (hook `SessionStart` global) détecte un sandbox par sa **branche** (`gsd/phase-*` ou `sandbox/phase-*`), pas seulement par le nom de dossier. Si le dossier dévie du nom canonique R5, il émet un **warning non-bloquant** sur stderr avec le nom attendu + la commande `git worktree move` exacte. Fail-open sur tout chemin d'erreur (un bug du hook ne doit jamais bloquer une session).
- `{{project}}-sandbox-title-watcher.sh` dérive le numéro de phase depuis la **branche** quand le nom de dossier ne matche pas la regex canonique. Le tab title affiche donc `Phase {N}` **même avant le rename** — l'identité visuelle ne disparaît plus silencieusement.

**Pourquoi (root cause)** : avant cette enforcement, le watcher exitait silencieusement sur tout nom non-canonique (regex stricte `^{{project}}-sandbox-phase{N}`), faisant disparaître l'identité de phase du terminal. C'est précisément ce qui a permis des commits sur le mauvais worktree (incident Phase 27.1.2). Le warning rend la dérive visible et corrigeable en une commande au lieu d'être un échec muet. La discipline reste **soft** (warn, pas block) — conforme à `feedback_soft_gates_over_hard_blocks.md`.

> Maintenance : toute évolution de la regex de nommage R5 (préfixe `{{project}}-sandbox-phase`, format du numéro de phase, dérivation du slug-court) doit être répercutée dans ces deux scripts globaux, sinon le warning et le titre divergent du nom canonique attendu.

## R6. Commits concurrents sur `main` — pathspec strict + sérialisation

Quand 2+ worktrees ont `main` checkouté (ce qui arrive naturellement : main repo + sandboxes qui mergent vers main) ET que des agents/sessions tournent en parallèle, l'index partagé via `.git/index` peut muter entre ton `git add` et ton `git commit`. Symptôme : `git diff --cached --stat` montre tes fichiers, mais `git commit -m "..."` capture autre chose (deletions d'autres worktrees, files staged par un autre processus).

### Mitigation primaire — Pathspec strict (obligatoire)

**Toujours** committer sur `main` avec un pathspec explicite :

```bash
git commit -m "..." -- <path1> <path2> <path3>
```

Le pathspec court-circuite l'état complet de l'index — seuls les fichiers listés sont commités, peu importe ce qui mute par ailleurs. Vérifier immédiatement après :

```bash
git log -1 --stat
```

Si le scope ne correspond pas à ce que tu attendais et le commit n'est **pas encore pushed** : `git reset --mixed HEAD~1` puis re-commit avec pathspec.

### Mitigation secondaire — Sérialiser via signal

Si plusieurs sessions Claude / agents background sont actives sur ce repo, signaler dans MEMORY.md ou via un fichier marker `.planning/.commit-in-progress-{worktree}` avant tout `git commit` sur `main`. Lever le signal après push. Pas de mécanisme strict — c'est une discipline d'opérateur.

### Détection post-mortem

```bash
git reflog -10
```

Si des commits **étrangers** apparaissent entre tes propres opérations (ex: `HEAD@{1}: commit: chore(todos)` que tu n'as pas écrit), c'est la signature d'une concurrence multi-worktrees sur `main`.

### Anti-patterns

| ❌ Ne pas faire | ✓ Correct |
|---|---|
| `git commit -m "..."` sans pathspec quand working tree dirty | `git commit -m "..." -- <paths>` |
| Trust `git diff --cached --stat` comme preuve de ce qui sera commité quand multi-worktrees | Vérifier `git log -1 --stat` APRÈS le commit, avant le push |
| Push un commit sans vérifier `git log -1 --stat` quand multi-worktrees actifs | Toujours vérifier le scope avant `git push` |

### Directive pour Claude (toujours appliquer)

Quand Claude prépare un `git commit` sur `main` :

1. **Toujours utiliser pathspec** : `git commit -m "..." -- <file1> <file2> ...`
2. **Stage uniquement les fichiers du commit en cours** : préférer `git add <paths>` à `git add -A` ou `git add .`
3. **Vérifier après commit** : `git log -1 --stat` doit lister exactement les fichiers attendus
4. **Si le scope ne match pas et le commit n'est pas pushed** : `git reset --mixed HEAD~1`, re-commiter avec pathspec

Cette discipline n'est pas négociable même si la session paraît seule — l'arbitrage `git diff --cached --stat` n'est pas fiable sur ce repo.

### Enforcement automatique

La détection commit-concurrency (HEAD=main + >1 fichier staged + multiples sessions Claude actives → WARNING non-bloquant) est **foldée dans le hook pre-commit canonique** `.githooks/pre-commit` (step 0). Le même hook fait aussi les checks SAST + governance guards. Si tu vois le warning, applique le pathspec et re-commit — c'est un filet de sécurité, pas une barrière.

**Installation / réparation** (après un clone, un reset, ou si `core.hooksPath` a dérivé) :

```bash
bash scripts/setup-hooks.sh
```

`setup-hooks.sh` configure `core.hooksPath=.githooks` (config per-repo, non clonée) et rend les hooks exécutables.

**Symptôme de dérive** : si `git config --get core.hooksPath` retourne autre chose que `.githooks` (ex: `.git/hooks`), le hook canonique n'est PAS actif — la concurrency-warn ET le SAST sont tous deux off. Re-lancer `setup-hooks.sh`. Ne jamais copier un hook vers `.git/hooks/pre-commit` à la main : c'est précisément ce qui crée la dérive (récurrence observée 2026-05-15 → 2026-05-17).

### Justification

Incident observé 2026-05-11 : commit du routing /prepare-phase canonical. `git add` puis `git diff --cached --stat` confirmait 3 fichiers staged (39+/-8). `git commit -m "..."` immédiatement après a produit `1 file changed, 48 deletions` — capturant la deletion d'un todo unstaged ailleurs, pas mes 3 fichiers. Cause identifiée via `git reflog` : 2 commits étrangers d'un autre worktree (`b578d2f`, `dca8d52`) sont apparus dans l'historique pendant ma session. L'hypothèse hook pre-commit a été réfutée (`.git/hooks/` vide, `core.hooksPath` legacy, `.githooks/pre-commit` ne touche pas l'index). Voir LESSONS.md `[git]` lesson 2026-05-11 pour le détail.

## Cas particulier — Worktrees Claude internes

Worktrees auto-managés sont **hors scope** de cette règle (ils ont leur propre lifecycle géré par Claude/Anthropic) :

- `.claude/worktrees/{name}` (Agent isolation)
- `.worktrees/{name}` (skill `/promote`, `/git-worktree`, autres)

Ne pas tenter de les "discipliner" — ils sont éphémères par design.

## Trigger automatique

Cette règle se charge proactivement quand Claude :

- Opère dans un working dir matchant `{{project}}-sandbox-*` ou `{{project}}-*-sandbox*`
- S'apprête à invoquer `/gsd-execute-phase` (lire AVANT l'exec)
- S'apprête à éditer un fichier dans les namespaces partagés listés en R4
- S'apprête à exécuter `git commit` sur la branche `main` (lire R6 AVANT le commit)
- Détecte plus d'un worktree actif via `git worktree list`

## Anti-patterns

| Anti-pattern | Correct |
|---|---|
| Créer `sandbox/phase-N` parallèle à `gsd/phase-N-slug` | Réutiliser la branche `gsd/phase-N-slug` dans le sandbox worktree |
| Lancer `/gsd-execute-phase` dans sandbox stale sans sync | Appliquer R2 systématiquement |
| Garder branche WIP local-only "juste un peu" | Push -u origin immédiat |
| Édit `.claude/rules/` ou `MEMORY.md` depuis 2 worktrees parallèles | Worktree discovery R4 + sérialisation |
| Reset sandbox HEAD sans backup | Push branche d'abord, reset après |
| `git commit -m "..."` sans pathspec sur `main` quand multi-worktrees actifs | `git commit -m "..." -- <paths>` (R6) |
| Ignorer le warning SessionStart Layer B + bypasser le block UserPromptSubmit (Phase 24.9) | Appliquer la discipline Layer B — ouvrir un worktree isolé OU utiliser `SKIP_SESSION_LOCK=1` consciemment, jamais subrepticement. Voir `.claude/rules/session-isolation.md` |
| `git worktree remove --force` quand une session Claude tourne dans ce worktree | `/quit` Claude DANS le worktree AVANT le `git worktree remove`. Voir § Cleanup discipline ci-dessous |

## Cleanup discipline — /quit avant git worktree remove

`git worktree remove --force` (ou `-f -f` pour overrider un lock) sur un worktree où une session Claude est encore active laisse la session dans un **état corrompu** : récurrence visible du message `Not logged in · Please run /login` même après un `/login` réussi, et le lock Layer B (Phase 24.9) reste orphelin dans `.session-locks/`.

**Procédure correcte :**

1. Dans le terminal où tourne Claude pour le worktree visé : `/quit` (ou Ctrl+C si non-interactif). Attendre que `SessionEnd` fire — le lock `.session-locks/{branch-slug}/` se cleanup automatiquement.
2. Optionnel : vérifier le cleanup — `ls <repo-main>/.session-locks/` ne doit pas contenir le slug de la branche du worktree.
3. **Ensuite seulement** : `git worktree remove <path>` (pas besoin de `--force` si étape 1 effectuée). Le lock du worktree git lui-même est libéré par `/quit`.

**Si l'étape 1 a été oubliée :**

- Lock Layer B orphelin → auto-cleanup dans 2h via mtime stale (D-B9) OU manuel : `rm -rf <repo-main>/.session-locks/{branch-slug}/`.
- Session Claude corrompue → `/quit` puis relancer `claude` (le `/login` répété ne corrige pas, c'est un état terminal).

## Règle de maintenance

Mettre à jour ce fichier dans le même commit si :

- Un nouveau pattern de collision émerge (ex : nouveau type de worktree managé)
- La convention de nommage des branches phase change
- La liste de namespaces partagés (R4) évolue

## Références

- `.claude/rules/workflow-guide.md` § Worktree Sandbox (création initiale d'un sandbox)
- `.claude/rules/phase-lifecycle.md` § Phase lifecycle structurel
- `.claude/rules/governance.md` § File ownership et co-update obligations
- Skill `/git-worktree` (gestion lifecycle worktrees)
- LESSONS.md § Phase 15 nested worktrees (cas réel de collision résolu)
- LESSONS.md `[git]` 2026-05-11 — Concurrence multi-worktrees peut écraser ton commit (incident R6)
