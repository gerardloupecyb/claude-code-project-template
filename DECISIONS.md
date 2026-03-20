# DECISIONS.md — project-template-v2

> Registre des decisions architecturales et metier.
> Consulte par Claude a la planification (pas chaque session). Cap ~25 decisions actives.
> Les decisions SUPERSEDED/DEPRECATED restent en bas du fichier pour contexte historique.
> Ne jamais supprimer une decision — changer son statut.
> Ne jamais modifier le contenu d'une decision acceptee — seulement son statut.

---

## Decisions actives

### DEC-001: MEMORY.md est source de verite, auto memory est supplementaire read-only [workflow] [context]
- **Date:** 2026-03-20 | **Statut:** ACCEPTED
- **Contexte:** CE v2.45+ scanne le repertoire auto memory de Claude (`~/.claude/projects/<project>/memory/`) comme source d'evidence pour `ce:compound` et `ce:compound-refresh`. Le template utilise MEMORY.md comme etat projet. Risque d'asymetrie si les deux divergent.
- **Decision:** MEMORY.md reste la source de verite structuree (etat projet, prochaine etape, blocages). Auto memory est supplementaire en lecture seule — consultee par `ce:compound` et le flywheel comme source d'insights additionnels, jamais ecrite par le template.
- **Rejete:** (A) Auto memory comme source de verite — pas structure, pas versionne, pas lisible par session-gate. (B) Fusionner les deux — complexite disproportionnee, formats incompatibles.
- **Consequences:** Les hooks (session-start.sh, pre-compact.sh) continuent de ne gerer que MEMORY.md. Le flywheel ajoute une etape 1.5 "consulter auto memory". Aucun hook n'ecrit dans auto memory.

### DEC-002: Garder pre-compact.sh, desactiver GSD context monitor [workflow] [context] [hooks]
- **Date:** 2026-03-20 | **Statut:** ACCEPTED
- **Contexte:** GSD v1.27 inclut un context monitor qui detecte la degradation du contexte. Le template a deja pre-compact.sh (snapshot MEMORY.md avant compaction) et session-start.sh (re-injection apres). Les deux touchent le meme lifecycle — risque de double-snapshot, ordering indetermine, hooks concurrents.
- **Decision:** Option A — garder pre-compact.sh et session-start.sh comme mecanismes de contexte du template. Ne pas activer le GSD context monitor. Mentionner son existence dans CLAUDE.md.template comme alternative disponible.
- **Rejete:** (B) Remplacer par GSD monitor — perd le snapshot MEMORY.md versionne et la re-injection LESSONS.md. (C) Layerer les deux — ordering indetermine entre hooks template et GSD, debug difficile.
- **Consequences:** CLAUDE.md.template Rule #3 mentionne le context monitor GSD comme alternative (1 ligne). Si pre-compact.sh s'avere insuffisant, DEC-002 peut etre supersedee par une decision activant le GSD monitor.

---

## Decisions archivees

<!-- Les decisions SUPERSEDED ou DEPRECATED sont deplacees ici.
     Gardees pour audit trail et pour empecher Claude de re-proposer
     des approches deja rejetees.

     Quand une decision est supersedee :
     1. Changer son statut a SUPERSEDED
     2. Ajouter "Supersede par: DEC-NNN" dans ses consequences
     3. Deplacer l'entree complete dans cette section
     4. La nouvelle decision doit referencer "Supersede: DEC-NNN"
-->
