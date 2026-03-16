# /context-checkpoint — Sauvegarde rapide avant coupure de session

Automatise la Règle #3 de CLAUDE.md : checkpoint de contexte avant coupure.

## Quand utiliser

- L'utilisateur tape `/context-checkpoint`
- Claude détecte une dégradation (répétitions, imprécisions, questions déjà répondues)
- Avant une coupure volontaire de session longue

## Procédure (max 5 tool calls)

### 1. Résumer dans MEMORY.md

Mettre à jour la section "Ce qui a été fait" avec un résumé de 200 mots max :
- Ce qui a été accompli cette session
- État actuel du travail

### 2. Lister les décisions

Ajouter/mettre à jour la table "Décisions actives" dans MEMORY.md :
- Chaque décision prise depuis le début de session
- Avec sa raison courte

### 3. Prochaine étape

Mettre à jour "Prochaine étape" dans MEMORY.md avec une seule action claire et actionnable.

### 4. Proposer /lesson

Si un fix non-trivial a été réalisé cette session, proposer :
"Un pattern intéressant a été résolu. Lancer `/lesson` pour le capturer ?"

### 5. Valider et annoncer

Lancer `/session-gate end` pour valider l'état de MEMORY.md.

Puis afficher :

```
Checkpoint saved.
Ouvre une nouvelle session avec : Read MEMORY.md → puis énonce ta prochaine tâche.
```

## Ce que ce skill ne fait PAS

- Il ne peut pas mesurer le % de contexte utilisé (pas d'API disponible)
- Il ne ferme pas la session automatiquement
- Il ne remplace pas /session-gate — il le complète en amont
