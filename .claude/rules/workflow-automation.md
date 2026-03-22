# Workflow Automation — transitions automatiques entre outils

APPLICABILITY: Ces regles s'appliquent a TOUTES les sessions. Elles rendent les transitions
entre planification, execution et review automatiques — l'utilisateur n'a pas a se souvenir
de la prochaine commande.

## Auto-detection de config manquante

Au DEBUT de chaque session de travail (pas de recherche/question), verifier silencieusement :

| Check | Condition | Action |
|-------|-----------|--------|
| Review agents | `compound-engineering.local.md` n'existe pas | Proposer : "Pas de review agents configures. Lancer `/setup` ?" |
| GSD state | `.planning/` vide ou inexistant ET tache de dev prevue | Proposer : "Pas de milestone GSD. Lancer `/gsd:new-project` ou travailler avec `/ce:work` ?" |

Ne PAS bloquer — proposer une fois, puis continuer si l'utilisateur decline.

## Choix automatique de l'executor

Quand l'utilisateur demande d'executer un plan ou une tache :

| Contexte detecte | Executor | Raison |
|-----------------|----------|--------|
| `.planning/STATE.md` existe ET phase active | `/gsd:execute-phase` | GSD structure en cours |
| Plan dans `docs/plans/` sans GSD actif | `/ce:work docs/plans/...` | Plan libre, pas de state GSD |
| Description verbale sans plan | `/ce:work` inline | Pas de plan ecrit |
| Utilisateur dit "execute phase N" | `/gsd:execute-phase N` | Demande explicite GSD |
| Utilisateur dit "fais X" (tache simple) | Executer directement | Pas besoin d'orchestrator |

Ne PAS demander "quel executor voulez-vous ?" — choisir automatiquement et informer :
"J'utilise /ce:work pour ce plan (pas de GSD actif)."

## Transitions post-execution

Apres avoir termine l'execution d'un plan ou d'une tache significative (> 3 fichiers modifies) :

```
Execution terminee
    |
    v
1. Proposer /lesson si fix non-trivial decouvert pendant l'execution
2. Proposer /ce:review si compound-engineering.local.md existe
3. Si /ce:review pas disponible → proposer /setup d'abord
```

Format de proposition (une ligne, pas un pavé) :
"Execution terminee. Lancer `/ce:review` sur cette branch ?"

## Transitions post-review

Apres `/ce:review` :

- Si P1 findings → "N findings critiques. Les corriger maintenant ?"
- Si 0 P1 → "Review clean. Creer la PR ?"

## Transitions post-planning

Apres `/gsd:plan-phase` ou `/ce:plan` :

- Si taches external detectees (model-routing.md) → "N taches delegables a Codex. Generer les briefs avec `/task-router` ?"
- Sinon → "Plan pret. Lancer l'execution ?"

## Anti-patterns — NE PAS

- Ne PAS enchainer automatiquement sans confirmation (proposer, pas executer)
- Ne PAS repeter une proposition deja declinee dans la meme session
- Ne PAS proposer `/ce:review` pour des changements < 3 fichiers ou docs-only
- Ne PAS proposer `/lesson` pour des changements triviaux (typo, config)
