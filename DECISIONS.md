# DECISIONS.md — project-template-v2

> Registre des decisions architecturales et metier.
> Consulte par Claude a la planification (pas chaque session). Cap ~25 decisions actives.
> Les decisions SUPERSEDED/DEPRECATED restent en bas du fichier pour contexte historique.
> Ne jamais supprimer une decision — changer son statut.
> Ne jamais modifier le contenu d'une decision acceptee — seulement son statut.

---

## Decisions actives

<!-- FORMAT pour chaque entree :

### DEC-NNN: Titre court [tag1] [tag2]
- **Date:** YYYY-MM-DD | **Statut:** ACCEPTED
- **Contexte:** Pourquoi cette decision etait necessaire
- **Decision:** Ce qui a ete decide (une phrase)
- **Rejete:** Alternative(s) consideree(s) et pourquoi rejetee(s)
- **Consequences:** Ce que ca implique pour la suite

Statuts possibles : ACCEPTED, SUPERSEDED, DEPRECATED
Tags entre crochets : [database] [api] [auth] [infrastructure] [workflow] etc.

-->

### DEC-001: CARL rules sequentielles a partir de RULE_5 [workflow] [carl]
- **Date:** 2026-03-16 | **Statut:** ACCEPTED
- **Contexte:** Besoin d'ajouter des regles CARL pour context management, le dernier actif etait RULE_5
- **Decision:** Numbering sequentiel RULE_6/7 (pas 8/9)
- **Rejete:** Sauter a RULE_8/9 — creerait un gap dans le numbering
- **Consequences:** Prochaine regle = RULE_8

### DEC-002: Check 9 cible docs/plans/ pas PLAN.md [workflow] [session-gate]
- **Date:** 2026-03-16 | **Statut:** ACCEPTED
- **Contexte:** Session-gate check 9 devait verifier les COT plan blocks
- **Decision:** Cibler `docs/plans/*-plan.md` car PLAN.md n'existe pas dans le template
- **Rejete:** PLAN.md unique — fichier inexistant dans le template
- **Consequences:** Plans doivent etre dans docs/plans/ pour etre valides par session-gate

### DEC-003: Hooks exit 0 obligatoire [infrastructure] [hooks]
- **Date:** 2026-03-16 | **Statut:** ACCEPTED
- **Contexte:** Les hooks Claude Code ne doivent jamais bloquer la session
- **Decision:** `trap exit 0` dans tous les hooks (pas `set -euo pipefail`)
- **Rejete:** `set -euo pipefail` — fait crasher les hooks et bloque la session
- **Consequences:** Erreurs dans les hooks sont silencieuses — logger si besoin

### DEC-004: Flywheel extrait vers .claude/rules/ [architecture] [workflow]
- **Date:** 2026-03-16 | **Statut:** ACCEPTED
- **Contexte:** CLAUDE.md a 505 lignes, depasse le budget 200 recommande par Anthropic
- **Decision:** Extraire les instructions flywheel vers `.claude/rules/flywheel-workflow.md`
- **Rejete:** Garder tout dans CLAUDE.md — degradation d'adherence au-dela de 200 lignes
- **Consequences:** CLAUDE.md reste lean, rules/ auto-charge par tous les subagents

### DEC-005: Quality checks CE via rules pas remplacement GSD [workflow] [execution]
- **Date:** 2026-03-16 | **Statut:** ACCEPTED
- **Contexte:** ce-work et gsd:execute-phase ont des forces complementaires
- **Decision:** Hybridation via `.claude/rules/execution-quality.md` plutot que remplacer GSD
- **Rejete:** Remplacer gsd:execute-phase par ce-work — perdrait l'orchestration GSD
- **Consequences:** GSD orchestration + ce-work quality patterns injectes via rules/

### DEC-006: git add scope MEMORY+LESSONS only dans hooks [infrastructure] [hooks]
- **Date:** 2026-03-16 | **Statut:** ACCEPTED
- **Contexte:** Hook session-end doit commiter les fichiers memoire
- **Decision:** `git add` scope a MEMORY.md et LESSONS.md seulement
- **Rejete:** `git add -A` — risque de stager des fichiers en cours d'ecriture
- **Consequences:** Les autres fichiers doivent etre stages manuellement

### DEC-007: 4 matchers SessionStart dans settings.json [infrastructure] [hooks]
- **Date:** 2026-03-16 | **Statut:** ACCEPTED
- **Contexte:** Hook session-start devait se declencher sur plusieurs evenements
- **Decision:** 4 matchers : startup, compact, resume, clear
- **Rejete:** Matcher unique startup — raterait les reprises de session
- **Consequences:** MEMORY.md et LESSONS.md injectes sur tout demarrage/reprise

---

## Decisions archivees

<!-- Les decisions SUPERSEDED ou DEPRECATED sont deplacees ici.
     Gardees pour audit trail et pour empecher Claude de re-proposer
     des approches deja rejetees.
-->
