---
name: lesson
description: "Capture rapide d'une lecon apprise dans LESSONS.md. Se declenche sur : lesson, lecon, retenir, pattern decouvert, ne pas oublier. Aussi invoque explicitement avec /lesson."
---

# /lesson — Capture rapide de lecon

Capture une lecon apprise en ~10 secondes dans LESSONS.md.
Un seul point de confirmation (oui/non). Pas de workflow lourd.

---

## Invocation

| Commande | Effet |
|----------|-------|
| `/lesson` | Claude propose une lecon basee sur le contexte courant |
| `/lesson migrate` | Migre les 10 plus anciennes entrees vers Supermemory + docs/solutions/ |

---

## Flux /lesson (capture)

### Etape 1 — Detecter le domaine

Analyser le contexte recent de la conversation :
- Fichiers modifies recemment
- Domaine CARL actif
- Sujet de la discussion

Proposer un domaine (ex: `[auth]`, `[api]`, `[workflow]`).
Ne pas demander — proposer et laisser l'utilisateur corriger si besoin.

### Etape 2 — Formuler la lecon

Generer une entree au format strict :

```markdown
### [domaine] Titre court
**Quand** situation precise qui declenche cette lecon
**Faire** action concrete a prendre
**Parce que** raison courte (incident ou decouverte source)
_Date: YYYY-MM-DD_
```

Regles de formulation :
- **Quand** = condition observable, pas vague ("quand on utilise X avec Y", pas "quand ca marche pas")
- **Faire** = action imperative, une seule chose ("utiliser Z au lieu de W")
- **Parce que** = fait concret ("l'API retourne 429 au-dela de 100 req/min")
- Titre = 5-8 mots max

### Etape 3 — Confirmer

Presenter la lecon formatee a l'utilisateur :

```
Lecon proposee :

### [api] Rate limiting sur l'endpoint /search
**Quand** on fait plus de 100 requetes/min sur /search
**Faire** ajouter un throttle cote client avec backoff exponentiel
**Parce que** l'API retourne 429 et coupe l'acces pendant 60s
_Date: 2026-03-14_

Ajouter a LESSONS.md ? (oui/non)
```

- Si **oui** : ajouter l'entree dans LESSONS.md :
  - Si des entrees `###` existent deja : inserer apres la derniere entree (avant le commentaire de fin)
  - Si aucune entree `###` n'existe (fichier vierge) : remplacer la ligne `_Aucune lecon pour l'instant..._` par la nouvelle entree, sous la section `## Lecons`
- Si **non** : ne rien faire

### Etape 4 — Verifier le cap

Apres l'ajout, compter le nombre d'entrees `###` dans la section "Lecons" de LESSONS.md.

- Si < 40 : rien a signaler
- Si >= 40 et < 50 : `"LESSONS.md a N/50 entrees — migration bientot necessaire."`
- Si >= 50 : proposer `/lesson migrate`

### Etape 5 — Proposer promotion CARL (si applicable)

Apres l'ajout, evaluer si la lecon merite une promotion en regle CARL :

Criteres de promotion :
- La lecon est critique (erreur couteuse en temps, securite, ou perte de donnees)
- Un pattern similaire existe deja dans LESSONS.md (>=3 entrees sur le meme sujet)
- La lecon s'applique a CHAQUE session, pas seulement occasionnellement

Si un critere est rempli, proposer :

```
Cette lecon semble critique. Proposer comme regle CARL ?
Regle proposee : {DOMAIN}_RULE_{N}={regle one-liner}
(oui/non)
```

- Si **oui** : ajouter la regle dans `.carl/{domaine}` au prochain slot disponible
- Si **non** : ne rien faire

---

## Flux /lesson migrate

Declenche quand le cap de 50 entrees est atteint ou proche.

### Etape 1 — Identifier les entrees a migrer

Selectionner les 10 entrees les plus anciennes (par date) dans LESSONS.md.
Presenter la liste a l'utilisateur pour confirmation.

### Etape 2 — Migrer vers Supermemory

Pour chaque entree confirmee, appeler `mcp__mcp-supermemory-ai__memory` avec :

```
[lesson:{domaine}] {Titre}
Quand: {condition}
Faire: {action}
Parce que: {raison}
Projet: {PROJECT_NAME}
Date: {date}
```

Si Supermemory indisponible : signaler et continuer avec docs/solutions/ seulement.

### Etape 3 — Copier dans docs/solutions/ (backup local)

Creer ou mettre a jour `docs/solutions/{domaine}/lessons-migrated.md` avec les entrees migrees.
Format : meme contenu que dans LESSONS.md, accumule au fil des migrations.

### Etape 4 — Retirer de LESSONS.md

Supprimer les entrees migrees de LESSONS.md.
Confirmer le nouveau nombre d'entrees : `"LESSONS.md: N/50 entrees apres migration."`

---

## Ce que ce skill ne fait PAS

- Modifier CARL sans confirmation explicite (propose, ne force pas)
- Remplacer `/ce:compound` (qui reste pour patterns lourds avec code + anti-patterns)
- Lire ou modifier MEMORY.md (responsabilites separees)
- Bloquer la session (advisory, oui/non, c'est tout)
- Creer des fichiers dans docs/solutions/ lors de la capture (seulement lors de la migration)
