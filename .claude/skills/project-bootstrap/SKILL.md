---
name: project-bootstrap
description: "Bootstrap un nouveau projet avec les lecons cross-projet de Supermemory. Se declenche sur : project bootstrap, bootstrap, demarrer le projet. Aussi invoque explicitement avec /project-bootstrap."
---

# /project-bootstrap — Bootstrap cross-projet

Injecte les lecons pertinentes de Supermemory dans LESSONS.md
pour eviter le cold start sur un nouveau projet.

---

## Invocation

| Commande | Effet |
|----------|-------|
| `/project-bootstrap` | Recall Supermemory + injection dans LESSONS.md |
| `/project-bootstrap --dry-run` | Affiche les lecons candidates sans ecrire |

---

## Flux

### Etape 1 — Identifier les keywords

Lire `.carl/manifest` pour extraire les RECALL keywords du projet
(ligne `{DOMAIN}_RECALL=keyword1,keyword2,...`).

Si pas de manifest : proposer des keywords derives du nom du projet,
de la structure de dossiers, et des fichiers CARL existants.
Laisser l'utilisateur confirmer ou ajuster (propose, ne demande pas).

Validation : si les keywords contiennent des valeurs placeholder
(ex: "keyword1", "keyword2"), les rejeter et proposer des alternatives.

### Etape 2 — Recall Supermemory

Appeler `mcp__mcp-supermemory-ai__recall` avec les keywords identifies.
Filtrer les resultats pour les tags :
- `[lesson:*]` — lecons projet
- `[skill:*]` — regles techniques
- `[convention:*]` — facons de travailler
- `[decision:*]` — choix architecturaux

Exclure `[context:preference]` (preferences personnelles, pas transferables).

Si Supermemory indisponible : signaler "Supermemory non disponible —
bootstrap impossible. Le projet demarre a froid." et sortir.

### Etape 3 — Selectionner et verifier le cap

Compter les entrees `###` existantes dans LESSONS.md (hors commentaires HTML).
Calculer la capacite restante : `slots = 50 - existantes`.

Si slots <= 0 : signaler "LESSONS.md est au cap (N/50). Lancer
/lesson migrate avant /project-bootstrap." et sortir.

Parmi les resultats de recall, trier par date decroissante (plus recentes
d'abord). Prendre les min(10, slots) premiers resultats.

Deduplication : exclure les resultats dont le titre correspond a une
entree existante dans LESSONS.md (match exact sur le titre apres `### `).

Presenter la liste a l'utilisateur pour confirmation (deselectionner
les entrees non souhaitees).

Si mode `--dry-run` : afficher la liste et sortir sans ecrire.

### Etape 4 — Injecter dans LESSONS.md

Pour chaque lecon confirmee, ajouter dans LESSONS.md au format standard :

```markdown
### [domaine] Titre court
**Quand** situation precise
**Faire** action concrete
**Parce que** raison courte
_Date: YYYY-MM-DD | Heritage: {projet-source}_
```

Le tag `[domaine]` est le domaine technique (api, auth, workflow, etc.),
PAS le nom du projet source. Le projet source est dans la ligne date
(apres `Heritage:`). Ceci preserve la compatibilite avec `/lesson migrate`
qui cree `docs/solutions/{domaine}/lessons-migrated.md`.

Remplacer la ligne `_Aucune lecon pour l'instant..._` si c'est la premiere injection.

### Etape 5 — Rapport

```
Bootstrap termine : N lecons injectees depuis M projets.
LESSONS.md a maintenant T/50 entrees.
Entrees ignorees : D (doublons), S (slots insuffisants).
```

---

## Output format

```
/project-bootstrap

  Keywords: saas, api, billing (from .carl/manifest)
  Supermemory: 12 results found, 8 after tag filter

  Candidates (sorted by date, most recent first):
    [x] [api] Rate limiting on third-party APIs (STR System, 2026-02-15)
    [x] [auth] Entra ID token refresh pattern (Loupe, 2026-01-20)
    [x] [workflow] Always run /lesson after non-trivial fix (Global, 2026-01-10)
    [ ] [database] PostgreSQL JSONB indexing (Healthcare, 2025-12-05)  <-- user deselected

  Confirm injection? (oui/non)

  Bootstrap termine : 3 lecons injectees depuis 3 projets.
  LESSONS.md a maintenant 3/50 entrees.
  Entrees ignorees : 0 (doublons), 1 (deselectionne par utilisateur).
```

---

## Ce que ce skill ne fait PAS

- Modifier CARL rules (les lecons heritage sont dans LESSONS.md, pas CARL)
- Ecraser des lecons existantes (ajout seulement, avec deduplication)
- Fonctionner sans Supermemory (degradation gracieuse)
- S'executer automatiquement (invocation manuelle uniquement)
- Depasser le cap de 50 entrees dans LESSONS.md
