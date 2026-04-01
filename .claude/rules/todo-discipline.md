# Todo discipline — todos/ est géré par le skill /todo uniquement

IMPORTANT : Ne jamais écrire directement dans `todos/` avec Write ou Edit.
Le skill encapsule le séquençage des IDs, les git mv, et la validation.

## Table de routing

| Situation | Outil correct | Anti-pattern — NE PAS faire |
|-----------|--------------|----------------------------|
| Créer un todo | `/todo create "description"` | `Write todos/pending/X-foo.md` |
| Marquer terminé | `/todo close {ID}` | `Edit todos/pending/X-foo.md` → status: complete |
| Vérifier complété | `/todo done {ID}` | `Bash(git mv todos/complete/... todos/done/...)` |
| Lister les todos | `/todo list` | `Glob todos/**/*` + lecture manuelle |
| Vérifier l'intégrité | `/todo validate` | Scan manuel des IDs |
