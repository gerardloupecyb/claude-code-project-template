---
name: project-template-sync
description: >
  Synchronise les fichiers template (rules, skills, hooks) d'un projet existant
  avec la derniere version du template upstream. Compare, affiche les diffs,
  et applique les changements acceptes.
  Trigger: "project-template-sync", "sync template", "mettre a jour le template",
  "update from template".
argument-hint: "[template-repo-url-or-local-path]"
disable-model-invocation: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(git *), Bash(mkdir *), Bash(diff *), Bash(cp *)
---

# Project Template Sync — Mise a jour depuis le template upstream

Synchronise les fichiers issus du template avec leur version la plus recente.
Ne touche JAMAIS aux fichiers projet-specifiques (CLAUDE.md, MEMORY.md, CARL, etc.).

---

## Quand utiliser

- Apres une nouvelle release du template (ex: v2.3.0 → v2.4.0)
- Quand un skill ou une rule a ete ameliore dans le template
- Periodiquement pour rester a jour

---

## Entree

Source du template. Soit :
- URL GitHub : `/project-template-sync https://github.com/gerardloupecyb/claude-code-project-template`
- Chemin local : `/project-template-sync /path/to/template`
- Sans argument : utilise `https://github.com/gerardloupecyb/claude-code-project-template` par defaut

---

## Fichiers synchronisables vs proteges

### Synchronisables (viennent du template)

| Categorie | Pattern | Merge strategy |
|-----------|---------|---------------|
| Rules | `.claude/rules/*.md` | Remplacer (pas de contenu projet-specifique) |
| Skills template | `.claude/skills/{skill}/SKILL.md` pour les skills du template | Remplacer |
| Hooks | `.claude/hooks/*.sh` | Remplacer |
| Settings | `.claude/settings.json` | Merge (ajouter les hooks manquants, garder les existants) |
| Gitignore | `.gitignore` patterns template | Append (ajouter les lignes manquantes) |

### Skills du template (liste exhaustive)

Ces skills viennent du template et peuvent etre synchronises :
- `context-checkpoint`
- `context-manager`
- `lesson`
- `pre-flight`
- `project-bootstrap`
- `project-sync`
- `project-template-sync`
- `reference-audit`
- `session-gate`
- `task-router`

Tout autre skill dans `.claude/skills/` est projet-specifique → NE PAS toucher.

### Proteges (JAMAIS synchronises)

- `CLAUDE.md`, `AGENTS.md` — configuration projet
- `memory/MEMORY.md` — etat de session
- `LESSONS.md`, `DECISIONS.md` — donnees projet
- `.carl/*` — regles CARL projet-specifiques
- `compound-engineering.local.md` — config review agents projet
- `.claude/integrations.md` — integrations projet
- `docs/references/*` — contenu reference projet
- `.claude/skills/` hors liste template — skills projet-specifiques
- `.claude/rules/workflow-guide.md` ou tout rule non-template — regles projet

---

## Etapes

### 0. Resoudre la source

Si URL GitHub :
```bash
git clone --depth 1 --branch master <url> /tmp/template-sync-$$
```
Si chemin local : utiliser directement.

Stocker le chemin dans `$TEMPLATE_SRC`.

### 1. Inventorier les fichiers synchronisables

Lire les fichiers du template et du projet courant.
Construire une table de comparaison :

Pour chaque fichier synchronisable :
1. Verifier s'il existe dans le projet
2. Si oui : comparer le contenu (diff)
3. Classifier : `IDENTICAL`, `MODIFIED`, `MISSING`

### 2. Afficher le rapport

```
## Template Sync Report

Source: [url ou path] (version [tag si disponible])
Projet: [nom du projet courant]

| Fichier | Status | Action proposee |
|---------|--------|----------------|
| .claude/rules/execution-quality.md | MODIFIED | +25 lignes (Simplify + Reviewer) |
| .claude/rules/tool-routing.md | IDENTICAL | Aucune |
| .claude/rules/model-routing.md | IDENTICAL | Aucune |
| .claude/skills/task-router/SKILL.md | MISSING | Nouveau skill |
| .claude/hooks/session-start.sh | MODIFIED | +3 lignes |

MODIFIED: N fichiers
MISSING: N fichiers
IDENTICAL: N fichiers (a jour)
```

### 3. Demander confirmation

Pour les fichiers MODIFIED : afficher le diff (format unified, max 50 lignes).
Si diff > 50 lignes : resumer les changements cles.

Demander a l'utilisateur :
- **Tout accepter** — appliquer tous les changements
- **Fichier par fichier** — accepter/rejeter chaque fichier
- **Annuler** — ne rien changer

### 4. Appliquer les changements acceptes

Pour chaque fichier accepte :
- `MODIFIED` → Copier la version template (ecraser)
- `MISSING` → Copier depuis le template (creer)
- Pour `.gitignore` : append les lignes manquantes seulement
- Pour `.claude/settings.json` : merger les hooks (garder les existants + ajouter les nouveaux)

### 5. Nettoyage et rapport final

Si clone temporaire : supprimer `/tmp/template-sync-$$`.

```
## Sync Complete

Applied: N fichiers mis a jour
Skipped: N fichiers (identiques ou refuses)
New: N fichiers ajoutes

Fichiers modifies :
  - .claude/rules/execution-quality.md (UPDATED)
  - .claude/skills/task-router/SKILL.md (NEW)

Next: verifier que les rules sont coherentes avec le projet.
      Si nouveau skill ajoute, verifier CLAUDE.md pour le documenter.
```

---

## Ce que ce skill ne fait PAS

- Modifier les fichiers projet-specifiques (CLAUDE.md, MEMORY.md, CARL, etc.)
- Synchroniser les fichiers de reference (docs/references/) — contenu unique par projet
- Gerer les conflits de merge complexes — si un fichier template a ete modifie localement ET dans le template, il affiche le diff et laisse l'utilisateur decider
- Commit automatiquement — l'utilisateur decide quand committer
- Mettre a jour compound-engineering.local.md — utiliser `/setup` pour ca
