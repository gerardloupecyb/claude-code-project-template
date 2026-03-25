# Routing des modèles — delegation vers executors externes

Claude (Opus) est le context orchestrator. Les modèles externes sont les executors.
Claude ne code PAS directement les tâches classifiées "external" — il génère un brief structuré.

## Classification v1 — binaire

| La tâche est... | Routing | Action |
|-----------------|---------|--------|
| Architecture, design, trade-offs, review, audit, planification, ambiguë | **opus** (stay) | Exécuter directement dans la session |
| Implémentation code, scripting, automation, CI/CD, tests | **external** (handoff) | Générer brief dans `.task-briefs/` via `/task-router` |

**Default si ambiguë → opus.**

## Handoff — ce que Claude fait pour chaque tâche "external"

1. Collecter le contexte pertinent depuis `docs/references/` (L1-L3 selon la tâche)
2. Extraire les snippets de code pertinents (pas les fichiers entiers)
3. Écrire `.task-briefs/{NNN}-{slug}.md` avec frontmatter (status + target_model)
4. Self-check : "Le brief contient-il tout pour que l'executor produise du code qui compile et passe les AC sans lire d'autres fichiers ?"
5. Afficher : `→ Codex VS Code : "lis .task-briefs/{NNN}-{slug}.md et exécute"`

## Return Signal Protocol

Quand l'executor a fini :
1. User tape dans Claude Code : `Codex done {slug}` (ex: `Codex done 002`)
2. Claude exécute :
   - `git diff` pour voir les changements
   - Vérifie chaque AC du brief
   - Met à jour `status` dans le frontmatter
   - Si PASS → next task. Si FAIL → retry protocol.

## Failure & Retry Protocol

```
Claude review (git diff + AC check)
  ├── PASS → status: reviewed → next task
  └── FAIL → attempt += 1
        ├── attempt ≤ 2
        │   → Écrire corrections dans le brief
        │   → status: pending (retry)
        │   → "lis .task-briefs/{slug}.md et corrige"
        └── attempt > 2
            → status: rejected
            → Claude exécute la tâche lui-même (Opus)
            → Log: "Escalated: [raison]"
```

Jamais plus de 2 retries. Si l'executor ne peut pas, le contexte est insuffisant — Opus reprend.

## Sources de contexte pour les briefs

Le task-router consulte `docs/references/Reference-files-index-routing.md` :
- **Tâche archi/security** → extraire de L1 (architecture-security.md)
- **Tâche code** → extraire de L2 (coding-patterns.md) + L3 (codebase-context.md)
- **Tâche infra** → extraire de L3 (services-and-access.md)
