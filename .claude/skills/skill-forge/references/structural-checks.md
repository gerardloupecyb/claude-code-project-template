# Structural Checks — Skill Forge

Checklist mécanique exécutée à Step 4. Chaque check est binaire : PASS ou FAIL.
Source canonique des règles : `.claude/rules/skill-framework.md`.

---

## Checks frontmatter (F)

| ID | Check | Comment vérifier |
|----|-------|-----------------|
| F-1 | `name` présent et en kebab-case | Regex `^[a-z0-9-]+$` |
| F-2 | `name` correspond au nom du dossier | Comparer `name:` vs `basename(chemin)` |
| F-3 | `description` présent et non vide | Longueur > 20 chars |
| F-4 | `description` contient "Triggers on:" | Grep case-insensitive |
| F-5 | Aucun champ non-standard dans frontmatter | Seuls `name` et `description` autorisés |

## Checks structure SKILL.md (S)

| ID | Check | Comment vérifier |
|----|-------|-----------------|
| S-1 | Titre H1 présent, format `# /nom — ...` | Regex `^# /{name}` sur ligne 1 après frontmatter |
| S-2 | Ligne count ≤ limite selon type | Simple ≤ 60, Standard ≤ 80, Orchestrateur ≤ 100 |
| S-3 | Section "What this skill does NOT do" présente | Grep `does NOT do` (case-insensitive) |
| S-4 | Section Usage présente | Grep `^## Usage` |
| S-5 | Si ligne count > 40 → `references/` doit exister | Check `ls references/` |
| S-6 | Si `references/` existe → table de routing présente | Grep `| Fichier |` dans SKILL.md |

## Checks references/ (R)

| ID | Check | Comment vérifier |
|----|-------|-----------------|
| R-1 | Tous les fichiers listés dans la routing table existent | `ls references/{fichier}` pour chaque ligne |
| R-2 | Aucun fichier `references/` absent de la routing table | Diff entre `ls references/` et table |
| R-3 | Aucun fichier `references/` > 200 lignes | `wc -l references/*.md` |
| R-4 | ≤ 5 fichiers dans `references/` | `ls references/ | wc -l` |
| R-5 | Noms descriptifs (pas `part1.md`, `content.md`, `details.md`) | Regex reject `^(part\d|content|details|stuff|misc)\.md$` |

## Checks tests/ (T)

| ID | Check | Comment vérifier |
|----|-------|-----------------|
| T-1 | `tests/` existe | `ls tests/` |
| T-2 | `tests/cases.md` existe et non vide | `wc -l tests/cases.md` > 5 |
| T-3 | `tests/assertions.md` existe et non vide | `wc -l tests/assertions.md` > 5 |
| T-4 | Chaque cas dans cases.md a un ID unique | Grep `^## Case` et vérifier unicité |
| T-5 | Chaque ID de cas référencé dans assertions.md | Cross-ref des IDs |

## Checks anti-patterns (A)

| ID | Check | Comment vérifier |
|----|-------|-----------------|
| A-1 | SKILL.md ne contient pas de contenu de `.claude/rules/*.md` copié | Grep pour phrases-clés des rules files |
| A-2 | Workflow inline ≤ 15 étapes numérotées | Count lignes commençant par `\d+\.` dans section Workflow |
| A-3 | Pas de section conditionnelle > 20 lignes inline | Détecter blocs `if/then` non déplacés en references/ |

---

## Format de rapport

```
## Validation structurelle

| ID  | Check                     | Résultat | Détail |
|-----|---------------------------|----------|--------|
| F-1 | name kebab-case           | PASS     |        |
| F-2 | name = nom dossier        | PASS     |        |
| S-2 | ligne count ≤ 80          | FAIL     | 94 lignes — déplacer §Workflow en references/ |
| R-1 | references/ fichiers OK   | PASS     |        |
| T-1 | tests/ existe             | PASS     |        |
...

Résultat : {N} PASS, {M} FAIL
```

Pour chaque FAIL : proposer l'action corrective exacte (quelle section déplacer, quel champ ajouter).
