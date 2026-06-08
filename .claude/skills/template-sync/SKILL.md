---
name: template-sync
description: >
  Synchronise le projet courant avec le template source. Compare skills, rules,
  hooks et settings, affiche les ecarts, et applique les mises a jour sur
  confirmation. Ne touche jamais aux fichiers projet-specifiques (CLAUDE.md,
  MEMORY.md, LESSONS.md, DECISIONS.md, CARL). Se declenche sur : template sync,
  sync template, mettre a jour depuis template, update from template.
  Aussi invoque explicitement avec /template-sync.
---

# /template-sync — Synchronisation projet ← template

Compare le projet courant avec le template source et propose les mises a jour.
Les fichiers universels (skills, rules, hooks, settings) sont synchronises.
Les fichiers projet-specifiques ne sont jamais touches.

---

## Invocation

| Commande | Action |
|---|---|
| `/template-sync` | Dry-run : affiche les ecarts sans modifier |
| `/template-sync apply` | Applique les mises a jour apres confirmation |
| `/template-sync --from <url-github>` | Dry-run depuis un template distant (clone shallow) |
| `/template-sync --from <url-github> apply` | Applique depuis un template distant |

> L'option `--from <url-github>` est absorbee de l'ex-skill `project-template-sync` (retire — D-6). Le modele allowlist qu'il portait est desormais dans `sync-project.sh` (`.forge/sync-allowlist.json`).

---

## Pre-check : localiser le template

Le script `sync-project.sh` se trouve a la racine du template.
Pour le localiser, chercher dans cet ordre :

1. **Source distante** : si l'invocation contient `--from <url-github>`, cloner d'abord le template :
   ```bash
   git clone --depth 1 --branch master <url-github> /tmp/template-sync-$$
   ```
   Utiliser `/tmp/template-sync-$$` comme `TEMPLATE_DIR`. Nettoyer (`rm -rf /tmp/template-sync-$$`) en fin de run.
2. Variable `TEMPLATE_DIR` dans le fichier `.claude/integrations.md` du projet courant
   (ligne contenant `template-path:` ou `TEMPLATE_DIR`)
3. Chemin par defaut : `/Users/gerardvinou/Claude code/Claude Projects/project-template-v2`
4. Si aucun trouve : demander a l'utilisateur

Verifier que `sync-project.sh` ET `.forge/sync-allowlist.json` existent au chemin trouve.
Si absent : `[!!] sync-project.sh ou .forge/sync-allowlist.json introuvable — verifier le chemin du template`

---

## Execution

### Mode dry-run (defaut)

Lancer le script avec Bash :

```
Bash: sync-project.sh "$PROJECT_DIR"
```

Le script affiche :
- `[NEW]` : fichier present dans le template mais absent du projet
- `[MODIFIED]` : fichier different entre template et projet
- `[SKIP]` : fichier projet-specifique (non synchronise)
- Summary avec compteurs

Presenter le rapport a l'utilisateur dans le format :

```
Template Sync — Dry Run

  Template : /chemin/vers/template
  Projet   : /chemin/vers/projet

  Ecarts detectes :
  [NEW]       .claude/skills/memory-consolidate/SKILL.md
  [MODIFIED]  .claude/skills/session-gate/SKILL.md
  [MODIFIED]  .claude/rules/execution-quality.md

  Fichiers proteges (non synchronises) :
  [SKIP]  CLAUDE.md, MEMORY.md, LESSONS.md, DECISIONS.md, integrations.md, CARL

  1 nouveau, 2 modifies, N a jour.

  Appliquer ? Lancer /template-sync apply
```

### Mode apply

Lancer le script avec `--apply` :

```
Bash: sync-project.sh "$PROJECT_DIR" --apply
```

Presenter le resultat :

```
Template Sync — Applied

  ✓ 1 nouveau fichier copie
  ✓ 2 fichiers mis a jour

  Note : CLAUDE.md n'a pas ete modifie (projet-specifique).
  Pour verifier les changements du template CLAUDE.md :
    diff CLAUDE.md.template CLAUDE.md
```

---

## Fichiers synchronises vs proteges

> **Modele allowlist (D-6).** Ce ne sont PAS tous les skills/rules qui sont synchronises — seuls ceux listes dans `.forge/sync-allowlist.json` (cle `skills[]` / `rules[]`). Un skill domaine (`ghl-architect`, `n8n-*`, ...) absent de l'allowlist n'est JAMAIS pousse vers un consumer. C'est le garde-fou que `sync-project.sh` applique a chaque run.

| Categorie | Fichiers | Action |
|---|---|---|
| **Skills (allowlist)** | `.claude/skills/{skill}/SKILL.md` pour chaque `skill` de `.forge/sync-allowlist.json` `.skills[]` | Copie si nouveau ou modifie |
| **Rules (allowlist)** | `.claude/rules/{rule}` pour chaque `rule` de `.forge/sync-allowlist.json` `.rules[]` | Copie si nouveau ou modifie |
| **Hooks** | `.claude/hooks/*.sh` | Copie si nouveau ou modifie |
| **Settings** | `.claude/settings.json` | Copie si modifie |
| **CLAUDE.md** | `CLAUDE.md` | JAMAIS — projet-specifique |
| **Memory** | `memory/MEMORY.md` | JAMAIS — etat projet |
| **Lessons** | `LESSONS.md` | JAMAIS — historique projet |
| **Decisions** | `DECISIONS.md` | JAMAIS — registre projet |
| **Integrations** | `.claude/integrations.md` | JAMAIS — config projet |
| **CARL** | `.carl/*` | JAMAIS — regles projet |

---

## Ce que ce skill ne fait PAS

- Modifier les fichiers projet-specifiques (CLAUDE.md, MEMORY.md, etc.)
- Creer un nouveau projet (utiliser `init-project.sh` pour ca)
- Synchroniser les fichiers CARL (domaine et manifest sont projet-specifiques)
- Forcer la mise a jour sans confirmation de l'utilisateur
- Fonctionner sans le script `sync-project.sh` ni `.forge/sync-allowlist.json` (il depend des deux)
- Pousser un skill domaine hors allowlist (`ghl-architect`, `n8n-*`, ...) — impossible par construction (D-6)
