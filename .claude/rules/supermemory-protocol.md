# Supermemory Protocol — formats et règles d'usage

## Deux types de contenu

**Leçons projet** (via `/lesson migrate`) :

```
[lesson:{domaine}] Titre court
Quand: situation précise
Faire: action concrète
Parce que: raison courte
Projet: {{PROJECT_NAME}}
Date: YYYY-MM-DD
```

**Leçons cross-projet** (via flywheel `/ce:compound`) :

```
[tag:{domaine}] Titre court et précis
Contexte : dans quel projet/situation découvert
Problème : ce qui se passait avant
Solution : ce qui fonctionne
Règle : "Toujours X quand Y." — une phrase actionnable
Réf : chemin fichier ou URL si applicable
```

## Tags standards

- `[lesson:{domaine}]`        → leçon projet migrée depuis LESSONS.md
- `[skill:{domaine}]`         → règle technique réutilisable
- `[decision:architecture]`   → choix structurant cross-projets
- `[decision:stack]`          → choix de librairie ou outil
- `[lesson:error]`            → erreur à ne pas répéter
- `[convention:workflow]`     → façon de travailler à retenir
- `[context:preference]`      → préférence personnelle sur comment travailler

## Règles d'usage

- Ne pas sauvegarder directement dans Supermemory — passer par `/lesson` ou `/ce:compound`
- Ne pas stocker de code ou credentials dans Supermemory
