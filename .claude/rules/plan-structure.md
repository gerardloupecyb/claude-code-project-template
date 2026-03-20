# Plan Structure — critères d'acceptation et frontières

APPLICABILITY: S'applique à tout plan créé par `/gsd:plan-phase` ou `/ce:plan`.

## Critères d'acceptation (BDD)

Format obligatoire Given/When/Then :

```
AC-1: Given [contexte], When [action], Then [résultat attendu]
AC-2: Given [contexte], When [action], Then [résultat attendu]
```

Chaque tâche doit référencer quel AC elle satisfait (ex: "→ satisfait AC-1").
Les critères doivent être déclaratifs (comportement attendu), pas impératifs (étapes mécaniques).
Les critères servent de référence pour `/gsd:verify-work` (UAT goal-backward).

Règles pour écrire de bons AC :

- Un seul comportement par AC (ne pas combiner plusieurs vérifications)
- Le "Then" doit être vérifiable par lecture de fichier ou exécution de commande
- Pas de détails d'implémentation dans le "Then" (tester le comportement, pas le code)

## Frontières — tous les plans

Lister explicitement les fichiers et répertoires qui ne doivent PAS être modifiés :

```
## Boundaries
- CLAUDE.md (ne pas modifier)
- .carl/ (ne pas modifier sauf si flywheel)
- [autres fichiers protégés selon contexte]
```

Les frontières protègent contre les modifications accidentelles pendant l'exécution.
Si une tâche nécessite de modifier un fichier listé en frontière,
le signaler comme déviation dans MEMORY.md avant de procéder.
