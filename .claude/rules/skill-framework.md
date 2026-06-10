---
title: Skill Framework — Spec canonique
scope: all-skills
enforced-by: skill-forge
---

# Skill Framework

Spec canonique pour tout skill {{PROJECT}}. Lue par `/skill-forge` à chaque création.
Source de vérité : ce fichier. Ne pas dupliquer dans les SKILL.md individuels.

## Philosophie — Lazy Loading

Un SKILL.md est un **index + routing**, pas un manuel complet.
Le détail vit dans `references/` et n'est chargé que quand c'est nécessaire.

Principe : Claude lit le minimum requis pour démarrer, puis charge les sections
pertinentes selon le contexte ou le mode invoqué.

## Token Budget

| Type de skill | Limite SKILL.md | references/ requis |
|---|---|---|
| Simple (1 mode, < 5 étapes) | ≤ 60 lignes | Optionnel |
| Standard (multi-mode ou multi-étapes) | ≤ 80 lignes | Obligatoire si > 40 lignes |
| Orchestrateur (appelle d'autres skills) | ≤ 100 lignes | Obligatoire |

Compter **toutes** les lignes incluant le frontmatter et les lignes vides.

## Structure requise

```
.claude/skills/{nom}/
├── SKILL.md          ← index (frontmatter + routing + output format + what-not)
├── references/       ← contenu détaillé (lazy-loaded)
│   └── *.md
└── tests/            ← cas de test (requis si skill-forge a été utilisé)
    ├── cases.md      ← scénarios d'invocation + contexte simulé
    └── assertions.md ← ce que l'output doit contenir / ne pas contenir
```

## Frontmatter obligatoire

```yaml
---
name: nom-en-kebab-case
description: >
  Une ligne résumant l'effet. Suivi des triggers exacts sur des lignes séparées :
  Triggers on: mot-clé-1, mot-clé-2, /commande-explicite.
---
```

- `name` : kebab-case, correspond exactement au nom du dossier
- `description` : commence par un verbe d'action, inclut les triggers explicitement
- Pas d'autres champs — ne pas ajouter `version`, `author`, `date`

## Sections requises dans SKILL.md

1. **Titre H1** : `# /nom — Titre humain court`
2. **Table de routing** (si multi-mode) : quel fichier `references/` charger selon contexte
3. **Usage** : comment invoquer (commande + variantes)
4. **Workflow** ou **Process** : étapes numérotées, format court
5. **What this skill does NOT do** : liste explicite des hors-scope

## Table de routing — format canonique

```markdown
## References

| Fichier | Charger quand |
|---------|---------------|
| `references/section-a.md` | Mode A activé |
| `references/section-b.md` | Mode B activé |
| `references/common.md`    | Toujours |
```

## Anti-patterns — NEVER

| Anti-pattern | Correct |
|---|---|
| Copier du contenu de `.claude/rules/*.md` dans le SKILL.md | Pointer vers le fichier canonique |
| Workflow > 15 étapes inline | Déplacer dans `references/` |
| Sections conditionnelles longues inline | Table de routing + `references/` |
| Frontmatter avec champs non listés ci-dessus | Supprimer les champs non standards |
| `references/` avec un seul fichier > 200 lignes | Découper en sections logiques |
| Tests absents sur skill créé par skill-forge | `tests/` obligatoire |

## Règle de nommage references/

- Noms descriptifs : `checks-start.md`, `workflow-create.md`, `assertions-output.md`
- Pas de `part1.md`, `content.md`, `details.md`
- Max 5 fichiers dans `references/` — si plus, reconsidérer le scope du skill

## Intégration component registry

Tout skill créé par `/skill-forge` doit être ajouté dans le même commit à :
- `docs/architecture/forge/component-registry.md` (table du groupe approprié)
- `docs/solutions/agents/skills-inventory.md` (ligne dans le groupe approprié)

## Cross-référence aux standards du domaine

À la création d'un skill orienté domaine ({{WORKFLOW_ENGINE}}, {{cloud_provider}}, {{crm_platform}}, ...) **et** à toute modification
d'un skill existant qui touche un domaine couvert par un standard `docs/standards/{domain}-*.md` :

- Identifier les standards pertinents par grep dans `docs/standards/` sur les mots-clés du domaine
- Ajouter dans le `SKILL.md` une section `## Production Hardening Standard` (ou équivalent ciblé)
  qui pointe vers le standard avec les §sections les plus pertinentes au scope du skill
- L'insertion se fait juste avant `## MCP Routing` — placement le plus discoverable

Réciproque obligatoire : voir `.claude/rules/governance.md` § « Nouveau standard / standard modifié ».
Les deux directions doivent toujours être en phase — un standard sans pointeur depuis les skills
du domaine est aussi cassé qu'un skill qui ignore un standard publié.
