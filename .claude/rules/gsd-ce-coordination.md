# GSD ↔ Compound Engineering — coordination protocol

GSD et Compound Engineering produisent des artifacts complémentaires.
Ils doivent lire les outputs de l'autre pour éviter la duplication.

## GSD lit les outputs Compound

Lors de `/gsd:plan-phase` et `/gsd:discuss-phase` :
- Consulter `docs/solutions/` (output de `/ce:compound`) pour les patterns connus
- Consulter `docs/plans/` (output de `/ce:plan`) si un plan Compound existe déjà
- Consulter `docs/brainstorms/` si un brainstorm a précédé la phase

## Compound lit les outputs GSD

Lors de `/ce:review` après exécution GSD :
- Lire `.planning/{phase}-VERIFICATION.md` comme contexte pour la review
- Lire `.planning/{phase}-{N}-SUMMARY.md` pour comprendre ce qui a été construit

Lors de `/ce:compound` :
- Lire `.planning/{phase}-PREFLIGHT.md` si pre-flight a été exécuté
  → Les findings pre-flight résolus sont des patterns à capitaliser

## Fichiers partagés

| Fichier | Producteur | Consommateurs |
|---------|-----------|---------------|
| `LESSONS.md` | `/lesson` | Toutes les sessions (lu au démarrage), planification |
| `docs/solutions/` | `/lesson migrate`, `/ce:compound` | Agent Explore (fallback ou profondeur) |
| `docs/plans/` | `/ce:plan` | `/gsd:discuss-phase` |
| `.planning/{phase}-PLAN.md` | `/gsd:plan-phase` | `/pre-flight`, `/gsd:execute-phase` |
| `.planning/{phase}-PREFLIGHT.md` | `/pre-flight` | `/ce:compound` |
| `.planning/{phase}-VERIFICATION.md` | `/gsd:verify-work` | `/ce:review` |
| `.planning/{phase}-{N}-SUMMARY.md` | `/gsd:execute-phase` + closure | `/ce:review`, `/ce:compound` |
| `memory/MEMORY.md` | Toutes les sessions | Toutes les sessions, `/session-gate` |
| `STATE.md` | GSD (position technique) | GSD, `/pre-flight` |
| Supermemory (projet) | `/lesson migrate` | `recall` à la planification |
