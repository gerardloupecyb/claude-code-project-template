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
| `/lesson --supersedes <slug>` | Ajoute la nouvelle lecon ET marque une lecon existante comme obsolete (marker `_Superseded by:_` inseree dans la lecon cible) |
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

### Etape 2.5 — Calculer et valider le slug (collision check)

**Cette etape tourne a CHAQUE invocation de `/lesson` — pas uniquement `--supersedes`.** Le schema slug est une propriete globale de LESSONS.md (D-18).

1. **Calculer le slug** de la lecon proposee a partir du domaine (Etape 1) et du titre (Etape 2) :
   - Algorithme : `{domaine}-{kebab-title}` avec normalisation NFKD, strip ASCII, lowercase, non-alphanum → `-`, collapse, trim
   - Regex de validation (V5 input validation, allowlist) : `^[a-z0-9][a-z0-9-]{1,100}$`
   - Length cap : titre tronque a 120 chars pre-normalization (prevention ReDoS T-02)
   - Reference canonical : fonction `compute_slug(domain, title)` dans `scripts/knowledge-sync.py`
   - Exemple : domaine `{{cloud_provider}}-automation`, titre "SupportsShouldProcess incompatible avec runbooks" → slug `{{cloud_provider}}-automation-supportsshouldprocess-incompatible-avec-runbooks`
   - Exemple accent : domaine `deploiement`, titre "Creer pipeline accentue" → slug `deploiement-creer-pipeline-accentue`

2. **Grep deterministe sur LESSONS.md** pour detecter collision :
   - Pattern : `### \[{domaine}\]` pour recuperer toutes les entrees du meme domaine
   - Pour chaque entree trouvee : recomputer son slug via `compute_slug(domain, titre)` (parse du H3 header)
   - Comparer avec le slug de la nouvelle lecon
   - **Le collision check est deterministe** : zero heuristique, zero NLP. Seulement grep + string equality.

3. **Sur collision detectee** (D-16, D-17 — refuse-and-error, aucun auto-suffix, aucun silent fallback) :
   - **NE PAS** ajouter la lecon a LESSONS.md
   - **NE PAS** tenter `slug-1`, `slug-2`, etc. (no auto-suffix policy D-17, aligne avec verification-discipline "no silent resolutions")
   - Afficher un message d'erreur au format :
     ```
     ERREUR : collision de slug detectee.

     La lecon proposee generait le slug `{slug}`, deja pris par :
     - LESSONS.md ligne {N} : "### [{domaine}] {titre existant}"

     Ce skill refuse de creer deux lecons avec le meme slug (policy D-17, verification-discipline § "no silent resolutions").

     Alternatives de titre a essayer :
     - {Suggestion 1 : titre plus specifique}
     - {Suggestion 2 : mention du contexte}
     - {Suggestion 3 : nom d'outil ou version}

     Re-invoquer `/lesson` avec un titre corrige.
     ```
   - Exit sans modification de fichier

4. **Sur slug OK (pas de collision)** : continuer vers Etape 3.

**Pourquoi a chaque invocation ?** Un collision check paresseux (uniquement sur `--supersedes`) laisserait passer des collisions silencieuses lors d'ajouts classiques. La regle D-18 rend le schema slug une propriete globale et coherente, pas un side-effect du flag supersedes.

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

**Si `--supersedes <target-slug>` a ete passe** (en plus de l'ajout standard ci-dessus) :

1. **Grep deterministe** sur LESSONS.md pour trouver la lecon cible par son slug :
   - Iterer sur toutes les entrees H3 (`### \[...\]`)
   - Pour chaque entree : recomputer son slug (`compute_slug(domain, title)`)
   - Match le slug contre `<target-slug>`
2. **Si target-slug pas trouve** : afficher `ERREUR : slug cible '{target-slug}' non trouve dans LESSONS.md.` et NE PAS ajouter la nouvelle lecon (rollback). Forcer l'auteur a verifier et re-invoquer.
3. **Si target-slug trouve** : dans la lecon cible, localiser la ligne `_Date: YYYY-MM-DD_` et inserer JUSTE APRES cette ligne :
   ```
   _Superseded by: {new-slug} ({date-jour})_
   ```
   ou `{new-slug}` est le slug de la lecon nouvellement ajoutee et `{date-jour}` est la date du jour au format YYYY-MM-DD.
4. **La lecon cible reste physiquement dans LESSONS.md** (D-13). Elle sera archivee dans {{RAG_BACKEND}} au prochain `/knowledge-sync` (metadata `superseded_by: <new-slug>`). La suppression physique est une operation manuelle separee via `python scripts/knowledge-sync.py --prune-superseded` (flag gate, jamais appele par le post-commit hook — prevention boucle infinie T-04).

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

### Backward compatibility

- `/lesson` sans flag : comportement inchange depuis la version precedente. L'unique side-effect nouveau est le collision check Etape 2.5 (qui ne bloque que sur collision reelle).
- `/lesson --supersedes <slug>` : strictement additif. Ne modifie pas le flow normal pour les invocations sans flag.
- Aucune migration retroactive des lecons existantes (D-15) : les ~38 entrees actuelles de LESSONS.md ne recoivent pas de slug frontmatter. Le slug est calcule a la volee a chaque invocation.

---

## Flux /lesson migrate

Declenche quand le cap de 50 entrees est atteint ou proche.

### Etape 1 — Identifier les entrees a migrer

Selectionner les 10 entrees les plus anciennes (par date) dans LESSONS.md.
Presenter la liste a l'utilisateur pour confirmation.

### Etape 2 — Archiver vers {{RAG_BACKEND}} `knowledge` (collection kind=lesson)

> Supermemory removed 2026-04-27 (Phase 27 Plan 00 D6). Lesson archive runs on {{RAG_BACKEND}} local now.

Pour chaque entree confirmee, ajouter dans `docs/solutions/{domaine}/lessons-migrated.md` (Etape 3) — l'auto-sync {{RAG_BACKEND}} post-commit indexera automatiquement le fichier dans la collection `knowledge` avec `kind=lesson` (frontmatter requis).

Frontmatter obligatoire pour que le sync {{RAG_BACKEND}} pickup l'entree :

```yaml
---
kind: lesson
domain: {domaine}
date: {date}
project: {PROJECT_NAME}
---
```

Format de l'entree (corps du markdown) :

```
## [lesson:{domaine}] {Titre}
Quand: {condition}
Faire: {action}
Parce que: {raison}
```

Si {{RAG_BACKEND}} local indisponible : signaler et continuer — le fichier markdown reste source-of-truth, le sync rattrapera au prochain commit. Aucune perte.

### Etape 3 — Ecrire dans docs/solutions/ (source canonique + auto-sync)

Creer ou mettre a jour `docs/solutions/{domaine}/lessons-migrated.md` avec les entrees migrees au format Etape 2.
Format : meme contenu que dans LESSONS.md, accumule au fil des migrations. Frontmatter en tete de fichier (pas par entree).

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
