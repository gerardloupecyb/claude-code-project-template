# Routing des outils — prévention du context flooding

IMPORTANT : Le context window se remplit vite et les performances se dégradent.
Chaque tool call a un coût. Toujours utiliser le bon outil.

## Table de routing

| Situation | Outil correct | Anti-pattern — NE PAS faire |
|-----------|--------------|----------------------------|
| Lire un fichier connu | `Read` (offset/limit si > 500 lignes) | `Bash(cat file)` |
| Chercher des fichiers par nom | `Glob` | `Bash(find . -name ...)` |
| Chercher du contenu dans le code | `Grep` | `Bash(grep -r / rg)` sans cap |
| Commandes git courtes (add, commit, status) | `Bash` direct | — |
| `git log` / `git diff` | `Bash(git log --oneline -20)` — TOUJOURS avec flag de cap | `git log` brut = 2K-10K tokens |
| Fetch de documentation web | `WebFetch` | `Bash(curl url)` = HTML brut ~12K tokens |
| Investigation multi-fichiers | `Agent` retourne résumé 200 mots max | Lire tous les fichiers en main session |
| MCP retournant > 20 lignes | Extraire champs utiles seulement | Ré-énoncer la réponse MCP complète |
| Playwright browser_snapshot | TOUJOURS passer `filename` param | Sans filename = ~135K tokens |
| Trouver une fonction/classe | `Grep` regex par langage → résultat ciblé | `Read` du fichier entier pour chercher |
| Lire une seule fonction | `Grep` pour la ligne → `Read(offset, limit:30)` | `Read` du fichier complet |
| Impact d'un changement | `Grep` refs → `Grep` importeurs (2 degrés max) | Lire manuellement chaque fichier |

## Coûts de référence

| Anti-pattern | Coût token estimé |
|-------------|------------------|
| `browser_snapshot()` sans filename | ~135 000 tokens |
| `git log` brut sur repo mature | 2 000-10 000 tokens |
| `curl url` (retourne HTML) | ~12 500 tokens |
| `cat` fichier JSON 100KB | ~25 000 tokens |
| `list_mail_messages` sans `$top`/`$select` | 30 000-60 000 tokens |
| `quickbooks query` sans MAXRESULTS | jusqu'à 25 000 tokens |
| CLAUDE.md > 200 lignes | Dégradation d'adhérence |

## Anti-patterns — NEVER

- Ne jamais lancer `git log`, `git diff`, `find`, `grep -r` sans flag de cap
- Ne jamais faire `Bash(curl url)` — utiliser `WebFetch`
- Ne jamais laisser un subagent retourner plus qu'un résumé de 200 mots
- Ne jamais faire `browser_snapshot()` sans `filename` param
- Réponses prose : max ~500 mots sauf demande explicite
- Plans, specs, blocs de code > 50 lignes : écrire dans un fichier, retourner le chemin
- Ne jamais `Read` un fichier entier pour trouver une fonction — `Grep` d'abord, `Read(offset, limit)` ensuite

## Discipline MCP — limit parameters par outil

| Outil | Paramètre | Valeur recommandée |
|-------|-----------|-------------------|
| `mcp__ms365__list_mail_*` | `$top` + `$select` | `$top=20&$select=subject,from,receivedDateTime` |
| `mcp__quickbooks__query` | `MAXRESULTS` dans la requête SQL | `MAXRESULTS 25` |
| `mcp__airtable__list_records` | `maxRecords` | `20` exploration, `100` max export |
| `mcp__linear__list_issues` | `first` | `25` |
| `mcp__azure-mcp__*` | filtre par resource group | Obligatoire — jamais scope subscription entier |
| `mcp__n8n-mcp__n8n_list_workflows` | aucun natif | Déléguer à subagent résumé 10 lignes max |
| `mcp__prod-ghl-mcp__contacts_get-contacts` | `limit` | `20` — jamais appel sans filtre |
| `mcp__google-analytics__run_report` | `limit` + date range | `limit=25`, date range 30 jours max |

Si aucun paramètre de limite disponible : subagent obligatoire avec contrat de retour explicite
"retourne une table avec colonnes [X, Y, Z], max 10 lignes"

## Ajout de nouveaux MCP — mise à jour obligatoire

Après chaque `claude mcp add <name>`, mettre à jour cette table :

1. Identifier le paramètre de limite natif du nouveau MCP (`limit`, `maxResults`, `first`, `$top`, etc.)
2. Ajouter une ligne dans la table ci-dessus avec la valeur recommandée
3. Si aucun paramètre natif : documenter "subagent obligatoire" dans la table
