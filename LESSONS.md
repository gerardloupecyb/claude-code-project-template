# LESSONS.md — project-template-v2

> Cache chaud des lecons apprises. Lu a chaque debut de session.
> Cap : 50 entrees. Quand atteint, migrer les plus anciennes vers Supermemory (projet) + docs/solutions/ (backup).
> Format strict : Quand/Faire/Parce que — une lecon par bloc.

---

## Comment utiliser ce fichier

- **Ajouter** : `/lesson` apres un fix non-trivial
- **Promouvoir** : si une lecon est critique ou repetee (>=3 occurrences) → proposer une regle CARL
- **Migrer** : quand le cap est atteint, les 10 plus anciennes migrent vers Supermemory + docs/solutions/
- **Consulter** : Claude lit ce fichier automatiquement a chaque session (reference dans CLAUDE.md)

---

## Lecons

### [template] Le deepening multi-agent previent les bugs structurels dans les plans

**Quand** on implemente un plan touchant plusieurs fichiers template interconnectes (skills, CARL, hooks, CLAUDE.md)
**Faire** lancer un deepening avec agents paralleles par fichier cible AVANT d'implementer — verifier numbering, paths, et contrats d'interface
**Parce que** 3 bugs identifies grace aux 7 agents : PLAN.md inexistant (Check 9 casse), RULE_8/9 au lieu de RULE_6/7 (gap dans le numbering), set -euo pipefail contradisant exit 0 (hooks qui crashent). Sans deepening, ces 3 erreurs seraient passees en production du template.
_Date: 2026-03-16_

---

<!-- FORMAT pour chaque entree :

### [domaine] Titre court
**Quand** situation precise qui declenche cette lecon
**Faire** action concrete a prendre
**Parce que** raison courte (incident ou decouverte source)
_Date: YYYY-MM-DD_

---

-->
