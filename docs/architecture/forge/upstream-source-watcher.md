---
forge_pattern: "upstream-source-watcher"
category: "knowledge-grounding"
reusability: "high"
maturity: "implemented"
authored: "2026-04-11"
implementation_phase: "24.2"
---

# FORGE Pattern: Upstream Source Watcher

## Problem

Les systemes d'AI agent reposent sur des sources amont (lois, docs API, standards) qui evoluent sans notification. Sans mecanisme de detection de drift, l'agent reste fige sur une version perimee et genere des recommandations non conformes. Les solutions naives (fetch a la demande, scraping periodique) sont fragiles et couteuses.

Le pattern `upstream-source-watcher` resout ce probleme en traitant la provenance comme metadonnee first-class dans chaque fichier de reference, en detectant le drift par empreinte SHA256, et en appliquant une strategie de refresh declarative. A partir de 2026-04-14, {{PROJECT}} ajoute une boucle d'**auto-resolve non bloquante** pour les cas consideres surs.

## When to use this pattern

- Votre agent/systeme consomme des documents reglementaires, des docs API tierces, ou des standards qui doivent rester a jour
- Les sources changent de facon imprevisible (pas de webhook ni de changelog machine-readable)
- Vous voulez un mecanisme auditable, versionnable, et reversible (pas un service externe opaque)
- Le cout d'un drift silencieux est eleve (conformite, securite, facturation)

## When NOT to use this pattern

- Sources avec API webhook de changelog native (souscrire directement au webhook est plus efficace)
- Sources qui changent plusieurs fois par jour (polling devient couteux ; preferer streaming)
- Contenu purement interne et stable (pas de drift a detecter)

## Generic architecture

### 1. Frontmatter as provenance metadata

Chaque fichier de reference porte son propre bloc YAML frontmatter decrivant sa source :

- `source` -- titre officiel humain
- `source_url` -- URL canonique (PDF, API endpoint, HTML)
- `source_pdf_sha256` (ou equivalent) -- empreinte cryptographique de la source brute
- `normalized_text_sha256` -- empreinte du texte extrait/nettoye (pour differencier changement cosmetique vs changement reel)
- `source_last_modified` -- header HTTP Last-Modified pour skip bande passante
- `fetched_at` / `consolidated_at` -- horodatage de verification / regeneration
- `refresh_strategy` -- enumeration des strategies disponibles
- `dependent_skills` / `dependent_systems` -- liste des consommateurs qui doivent etre re-{{identity_provider}}ines si ce fichier change

Le frontmatter EST la source de verite : pas de registre externe, pas de base de donnees, juste le fichier lui-meme. Cela garantit que le repo git est le seul artefact necessaire pour faire tourner le systeme.

### 2. Drift detection loop

Un script `check-drift.sh` (ou equivalent dans n'importe quel langage) :

1. Parse tous les fichiers de reference et extrait leur frontmatter
2. Pour chaque fichier : HEAD request sur `source_url`, compare `Last-Modified` header
3. Si identique : skip (economie bande passante -- aucune modification possible)
4. Sinon : GET complet + recalcul SHA256, compare a `source_pdf_sha256`
5. Si SHA256 differe : drift detecte, emettre warning
6. Gere les erreurs reseau sans exit fatal (warn-only)

La sortie est consommee par un hook session-start ou un scheduler (cron, systemd timer).

### 3. Refresh strategies (declarative)

Chaque fichier declare dans son frontmatter quelle strategie appliquer en cas de drift :

- `regenerate_file` -- le script telecharge la source, extrait le texte, nettoie, reecrit le fichier integralement. Adapte aux sources structurees (PDF legal, docs API JSON).
- `invoke_skill_refresh` -- le script delegue le refresh a un skill/command externe (scraper HTML specialise, extracteur proprietaire). Adapte aux sources necessitant une logique metier.
- `notify_only` -- le script warn seulement. Adapte aux sources payantes, legales avec copyright, ou necessitant intervention humaine.

Ajouter une nouvelle strategie = ajouter une branche dans le script `sync.sh`, rien d'autre.

### 4. Skill dependency graph

Le champ `dependent_skills` cree un graphe explicite : quand un fichier change, les skills qui en dependent doivent etre signales comme "knowledge stale". Implementations possibles :

- Simple : le script `sync.sh` imprime la liste des skills a re-auditer manuellement
- Avancee : invocation automatique d'un skill `knowledge-refresher` qui met a jour les caches {{RAG_BACKEND}}/vector-store des skills impactes
- Tres avancee : pipeline CI qui retourne les tests des skills concernes

### 5. Hook integration

Le drift-check doit tourner au demarrage de session (ou a intervalle regulier) pour que l'utilisateur soit alerte sans action explicite. Pour les cas surs, il peut aussi declencher un auto-resolve en best-effort. Contraintes :

- Non-bloquant : en background avec timeout strict (15s recommande)
- Warn-only : jamais exit 1 dans le hook -- c'est un signal, pas un gate
- Skippable : `--quiet` flag pour tests et CI

### 6. Trusted auto-resolve loop

Un repo qui veut fermer la boucle sur les cas low-risk peut ajouter un script `auto-resolve.sh` entre `check-drift.sh` et l'operateur humain :

1. Lire la liste de drift via `check-drift.sh --quiet`
2. Filtrer sur `refresh_strategy: regenerate_file`
3. Verifier que le host du `source_url` est dans une allowlist versionnee
4. Regenerer le fichier via `sync.sh --file`
5. Mesurer le diff lineaire (`added + removed`) contre un cap (`max_auto_diff_lines`)
6. Si le diff depasse le cap : revert local du fichier et fallback notify-only
7. Sinon : laisser le fichier modifie dans le working tree, emettre un resume semantique + references downstream

Le point cle est le **write without commit** : l'agent garde la discipline de review humaine, mais supprime le toil manuel pour les updates evidentement mecaniques.

## Reuse guide (how to apply to any repo)

1. **Inventory upstream sources** -- lister tout fichier de reference consomme par votre systeme (lois, docs API, standards, glossaires).

2. **Decide strategy per source** -- pour chaque fichier, choisir entre `regenerate_file`, `invoke_skill_refresh`, `notify_only`. Le critere principal : pouvez-vous extraire automatiquement le contenu (PDF text, JSON, HTML structure) ?

3. **Add frontmatter** -- prepender un bloc YAML a chaque fichier de reference avec les champs de provenance.

4. **Implement check-drift** -- script qui parse les frontmatter, fait HEAD + SHA compare, warn sur drift. ~60 lignes de bash.

5. **Implement sync** -- script qui applique les strategies. ~80 lignes de bash + 80 lignes de cleanup (si PDF -> texte).

6. **Optionally add trusted auto-resolve** -- allowlist versionnee + diff cap + revert local si l'update devient trop large.

7. **Wire into startup** -- ajouter un bloc non-bloquant dans votre hook session-start ou equivalent.

8. **Document dependent skills** -- remplir `dependent_skills` pour que les consommateurs soient alertes en cascade.

9. **Create a slash command** -- exposer un `/upstream-sync` pour le trigger manuel.

## Extension points

- **Nouvelle strategie** : ajouter une branche `case` dans `sync.sh` et documenter dans le schema frontmatter.
- **Nouvelle source de drift detection** : au lieu de SHA256, utiliser un champ `version` parse depuis le contenu (ex: {{WORKFLOW_ENGINE}} releases tag). Ajouter un parser dans `check-drift.sh`.
- **Notifications push** : envoyer le warning drift a Slack/email au lieu de stdout.
- **Re-indexation vector-store** : brancher le post-sync sur le re-index automatique d'un vector store ({{RAG_BACKEND}}, Pinecone, etc.).
- **Multi-jurisdiction** : ajouter un champ `jurisdictions` pour router le drift vers les skills concernes uniquement.

## Related FORGE patterns

- `artifact-staleness-watcher` -- meme philosophie : frontmatter as first-class metadata + proactive session-start alert + triage protocol. Applique le pattern a des artefacts (todos, issues) plutot qu'a des sources upstream.
- `knowledge-grounding` -- comment les skills consomment les sources watched
- `arch-kit` -- comment documenter les decisions (ADR) qui referencent ce pattern
- `phase-lifecycle` -- co-update entre changements de sources et phases de developpement
