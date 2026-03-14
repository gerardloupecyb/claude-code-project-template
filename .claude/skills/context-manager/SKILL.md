---
name: context-manager
description: >
  Règles de gestion du contexte, de la mémoire et du chain of thought pour
  Claude Code. Charger automatiquement sur tout projet qui utilise MEMORY.md,
  Supermemory, ou qui implique des sessions longues. Se déclenche aussi quand
  l'utilisateur mentionne "contexte", "mémoire", "reprendre le projet",
  "session", ou "MEMORY.md".
---

# Context Manager

Ce skill rappelle les règles de gestion du contexte définies dans CLAUDE.md.
Les règles complètes sont dans CLAUDE.md (Règles #1 à #7). Ce skill ne les duplique pas.

---

## Rappels critiques

### Démarrage de session

Lire AVANT de coder : `memory/MEMORY.md` + `LESSONS.md`.
Si l'un n'existe pas → le créer depuis le template.
Voir CLAUDE.md Règle #1 pour le détail.

### Fin de session

Mettre à jour MEMORY.md (ce qui a été fait, décisions, prochaine étape, blocages).
Proposer `/lesson` si fix non-trivial.
Commiter MEMORY.md + LESSONS.md avec le code.
Voir CLAUDE.md Règle #2 pour le détail.

### Sessions longues

Quand le contexte se dégrade (~60-70%) → checkpoint dans MEMORY.md → nouvelle session.
Ne jamais continuer une session dégradée.
Voir CLAUDE.md Règle #3 pour le détail.

---

## Quand ce skill est utile

Ce skill se charge quand le contexte détecte des mots-clés liés à la gestion de session.
Son rôle est de **rappeler** que les règles existent dans CLAUDE.md, pas de les redéfinir.

Si une situation nécessite les règles complètes (chain of thought, Supermemory, CARL,
hiérarchie des couches mémoire), lire directement CLAUDE.md Règles #4 à #7.

---

## Références

- CLAUDE.md Règles #1-#7    → règles complètes de gestion du contexte
- memory/MEMORY.md          → état courant projet
- LESSONS.md                → cache chaud des leçons (cap 50)
- Supermemory (projet)      → archive principale des leçons
- docs/solutions/           → backup local + patterns détaillés
