---
name: memory-consolidate
description: >
  Consolidation memoire : verifie la coherence cross-fichiers de MEMORY.md,
  LESSONS.md et DECISIONS.md. Read-only, advisory, jamais de modification.
  Se declenche sur : consolider memoire, memory consolidation, memory consolidate,
  verifier coherence, hygiene memoire. Aussi invoque explicitement avec /memory-consolidate.
---

# /memory-consolidate — Memory Consolidation

Verifie la coherence semantique des fichiers memoire du projet.
Read-only, advisory, stateless. Ne modifie jamais de fichier. Ne bloque jamais la session.

Complement de `/session-gate` : session-gate verifie la **structure** (fichier existe,
dates parsables, caps respectes). `/memory-consolidate` verifie la **coherence** (faits toujours vrais,
pas de doublons, pas de drift entre fichiers).

---

## Invocation

| Commande | Mode | Checks |
|---|---|---|
| `/memory-consolidate` | FULL | Tous les 8 checks |
| `/memory-consolidate quick` | QUICK | Checks 1-3 seulement (hygiene rapide) |

---

## Pre-check: fichiers requis

Avant de lancer les checks, verifier que les fichiers existent :

- `memory/MEMORY.md` — requis (si absent : `[!!] MEMORY.md absent — run /session-gate first`)
- `LESSONS.md` — requis pour checks 6-7 (si absent : skip ces checks)
- `DECISIONS.md` — optionnel pour check 4 (si absent : `[--] DECISIONS.md absent — skipping decision coherence`)

Si MEMORY.md est absent, afficher le message et arreter. Ne pas continuer les checks.

---

## Les 8 checks

Tous les checks utilisent `Read` et `Grep`. Aucun ne modifie de fichier.
Les checks sont groupes par scope.

### Groupe 1 — Hygiene MEMORY.md (QUICK + FULL)

Ces 3 checks sont aussi disponibles dans `/session-gate end` (checks 14-16).
`/memory-consolidate` les inclut pour offrir un rapport unifie.

#### Check D1 — Dates relatives dans MEMORY.md

Identique a session-gate Check 14.

Scanner memory/MEMORY.md pour les expressions de dates relatives
(case-insensitive, hors commentaires HTML et headers) :

- FR : `hier`, `avant-hier`, `la semaine dernière` / `la semaine derniere`,
  `le mois dernier`, `la semaine passée` / `la semaine passee`,
  `le mois passé` / `le mois passe`
- EN : `yesterday`, `last week`, `last month`

Note : les variantes avec et sans accents doivent etre cherchees car les fichiers
memoire peuvent utiliser l'une ou l'autre forme.

- Si trouve : `[--] MEMORY.md contient N date(s) relative(s) — convertir en YYYY-MM-DD`
  Lister chaque occurrence avec contexte de ligne (tronque a 60 chars).
- Si rien : skip

#### Check D2 — Doublons dans "Ce qui a ete fait"

Identique a session-gate Check 15.

Dans la section "Ce qui a ete fait", extraire les headings `###`.
Deux headings sont doublons s'ils sont identiques (apres trim).

- Si doublons : `[--] "Ce qui a ete fait" a des doublons : "{heading}" — fusionner`
- Si rien : skip

#### Check D3 — Blocages ouverts

Identique a session-gate Check 16.

Dans "Blocages et questions ouvertes", compter les `- [ ]` (hors "Aucun blocage").

- Si count > 0 : `[--] N blocage(s) ouvert(s) — verifier si encore pertinents`
- Si rien : skip

### Groupe 2 — Coherence cross-fichiers (FULL seulement)

#### Check D4 — Coherence decisions MEMORY.md ↔ DECISIONS.md

Lire la section "Decisions actives" de memory/MEMORY.md.

**Format table (legacy)** : si la section contient une table markdown (`|`),
extraire le contenu de la premiere colonne de chaque ligne de donnees
(skip header + separator).

**Format pointeurs (DEC-NNN)** : si la section contient des references `DEC-\d{3}`,
extraire ces identifiants.

Puis verifier dans DECISIONS.md :

- **Format pointeurs** : chaque DEC-NNN reference dans MEMORY.md existe dans
  DECISIONS.md comme heading `### DEC-NNN`. Verifier que son statut est `ACCEPTED`
  (pas SUPERSEDED/DEPRECATED).
  - Si DEC-NNN absent de DECISIONS.md : `[!!] DEC-{NNN} reference dans MEMORY.md mais absent de DECISIONS.md`
  - Si DEC-NNN est SUPERSEDED : `[--] DEC-{NNN} est SUPERSEDED dans DECISIONS.md — retirer de MEMORY.md`

- **Format table** : compter les entrees. Verifier que le nombre ne depasse pas 5.
  Pas de cross-check possible sans identifiants DEC-NNN.
  - Si > 5 : `[--] "Decisions actives" a N entrees (recommande: migrer vers format DEC-NNN)`

**Ordre d'evaluation** : toujours compter les entrees dans MEMORY.md d'abord (applicable
quel que soit l'etat de DECISIONS.md). Puis, si DECISIONS.md est absent, ajouter le
message ci-dessous en complement (pas en remplacement).

- Si DECISIONS.md absent : `[--] DECISIONS.md absent — coherence decisions non verifiable`
- Si section "Decisions actives" absente de MEMORY.md : skip

#### Check D5 — Stack reality check

Lire la section "Stack et config" de memory/MEMORY.md.
Extraire les items de la liste (lignes commencant par `- `).

Chercher ces fichiers manifeste a la racine du projet (Glob) :

| Fichier | Extrait |
|---|---|
| `package.json` | `dependencies` + `devDependencies` keys |
| `Gemfile` | lignes `gem "..."` |
| `requirements.txt` / `pyproject.toml` | noms de packages |
| `go.mod` | module name + require |
| `Cargo.toml` | `[dependencies]` |
| `mix.exs` | `deps` function |
| `composer.json` | `require` keys |

Pour chaque manifeste trouve :
- Extraire les 3-5 principaux frameworks/libraries (pas toutes les deps)
- Comparer avec les items dans "Stack et config"

Rapporter :
- Manifeste present mais framework non mentionne dans Stack :
  `[--] {framework} detecte dans {manifest} mais absent de "Stack et config"`
- Item Stack qui ne correspond a aucun manifeste detecte :
  `[--] "{item}" dans "Stack et config" mais aucun manifeste correspondant trouve`

Si aucun manifeste trouve : `[--] Aucun manifeste projet detecte — stack check non applicable`

**Scope limite** : ne verifier que les fichiers listes ci-dessus, a la racine du projet.
Ne pas scanner les sous-repertoires. Ne pas verifier les versions (seulement presence/absence).

### Groupe 3 — Sante LESSONS.md (FULL seulement)

Skip ce groupe entier si LESSONS.md est absent ou n'a aucune entree `###`.

**Important** : exclure les entrees situees entre `<!--` et `-->` (commentaires HTML).
Le template LESSONS.md contient un bloc commente avec un exemple de format.
Ne jamais comparer ni compter ces entrees fantomes.

#### Check D6 — Entrees similaires dans LESSONS.md

Lire toutes les entrees `###` dans la section "Lecons" de LESSONS.md
(hors blocs `<!-- -->`).
Pour chaque paire d'entrees, verifier :

1. Meme tag `[domaine]` dans le titre
2. Plus de 3 mots non-stopwords en commun dans la ligne `**Quand**`

Stopwords a ignorer : le, la, les, de, du, des, un, une, en, on, a, au, aux,
que, qui, quand, si, et, ou, dans, pour, par, sur, avec, the, a, an, in, on,
at, to, for, of, with, is, are, was, were, when, if, and, or

- Si paires similaires trouvees :
  `[--] Entrees similaires detectees — envisager fusion :`
  Lister chaque paire avec les titres des deux entrees.
- Si rien : skip

**Limite** : ne comparer que les entrees du meme domaine. Max 50 comparaisons
(au-dela du cap, `/lesson migrate` est plus adapte).

#### Check D7 — Entrees agees dans LESSONS.md

Pour chaque entree `###` dans "Lecons" (hors blocs `<!-- -->`),
extraire la date (`_Date: YYYY-MM-DD`).
Rejeter les dates non-parsables (ex: `YYYY-MM-DD` litteral du template).
Calculer l'age en jours.

- Si entrees > 60 jours : `[--] N entree(s) > 60 jours — candidates pour /lesson migrate`
  Lister les titres des entrees concernees.
- Si aucune : skip

### Groupe 4 — Sections secondaires (FULL seulement)

#### Check D8 — Patterns decouverts — references valides

Lire la section "Patterns decouverts" de memory/MEMORY.md (si elle existe).
Pour chaque entree, chercher des references a des fichiers ou chemins
(patterns : backticks contenant `/` ou `.`).

Pour chaque reference fichier trouvee, verifier que le fichier existe (Glob).

- Si fichier reference n'existe plus :
  `[--] Pattern reference "{path}" mais le fichier n'existe plus — mettre a jour ou supprimer`
- Si toutes les references valides ou aucune reference : skip
- Si section absente : skip

---

## Format de sortie

```
Memory Consolidate — {MODE}

  Groupe 1 — Hygiene MEMORY.md
  [--]  MEMORY.md contient 2 date(s) relative(s) — convertir en YYYY-MM-DD
  [--]  1 blocage(s) ouvert(s) — verifier si encore pertinents

  Groupe 2 — Coherence cross-fichiers
  [ok]  Decisions actives coherentes avec DECISIONS.md
  [--]  "express" detecte dans package.json mais absent de "Stack et config"

  Groupe 3 — Sante LESSONS.md
  [--]  2 entree(s) > 60 jours — candidates pour /lesson migrate

  Groupe 4 — Sections secondaires
  [ok]  Patterns decouverts — toutes les references valides

  Actions suggerees :
  1. Convertir les dates relatives en dates absolues dans MEMORY.md
  2. Verifier si les blocages ouverts sont encore pertinents
  3. Ajouter "express" a la section "Stack et config" de MEMORY.md
  4. Lancer /lesson migrate pour archiver les entrees anciennes
```

Legende : `[ok]` = coherent, `[!!]` = action requise, `[--]` = informatif.

En fin de rapport, lister les **actions suggerees** (numerotees) basees sur
les findings `[!!]` et `[--]`. Chaque action doit etre concrete et actionnable.

Si aucun finding : `"Memories are tight. Nothing to consolidate."`

---

## Relation avec les autres skills

| Skill | Role | Relation avec /memory-consolidate |
|---|---|---|
| `/session-gate` | Validation **structurelle** (fichiers existent, dates, caps) | Complementaire — memory-consolidate = coherence semantique |
| `/lesson` | Capture et migration des lecons | D6-D7 suggerent `/lesson merge` ou `/lesson migrate` — ne fait pas le travail |
| `/context-checkpoint` | Sauvegarde avant coupure | Independant — memory-consolidate peut tourner avant un checkpoint |
| Closure protocol | Checklist post-execution | memory-consolidate quick peut etre appele avant le step 2 (MAJ MEMORY.md) |

---

## Quand lancer /memory-consolidate

| Situation | Mode recommande |
|---|---|
| Fin de session (avant MAJ MEMORY.md) | `/memory-consolidate quick` (ou laisser session-gate checks 14-16) |
| Reprise apres longue pause (> 7 jours) | `/memory-consolidate` (full) |
| Avant un milestone ou release | `/memory-consolidate` (full) |
| LESSONS.md approche du cap 50 | `/memory-consolidate` (full — D6 detecte les candidats a fusionner) |
| Apres migration de stack | `/memory-consolidate` (full — D5 detecte le drift) |

---

## Ce que ce skill ne fait PAS

- Modifier un fichier (read-only, comme session-gate et pre-flight)
- Bloquer la session (advisory — l'utilisateur decide quoi corriger)
- Remplacer `/session-gate` (qui verifie la structure, pas la coherence)
- Remplacer `/lesson` ou `/lesson migrate` (suggerent, ne font pas)
- Ecrire dans LESSONS.md, DECISIONS.md ou Supermemory
- Evaluer la qualite du contenu ("cette decision est-elle bonne ?")
- Scanner les sous-repertoires pour les manifestes (racine seulement)
- Verifier les versions des dependances (presence/absence seulement)
