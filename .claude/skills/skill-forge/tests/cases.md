# Test Cases — skill-forge

## Case C-01 — Brief complet en argument

**Trigger:** `/skill-forge`
**Contexte:** Projet {{PROJECT}}. Dossier `.claude/skills/` existe.
**Input utilisateur:** `/skill-forge "deployment-check — Vérifier qu'un environnement est prêt avant un déploiement. Triggers: deployment check, check deploy. Output: tableau GO/NO-GO. Hors-scope: ne pas lancer le déploiement."`
**Mode:** Argument fourni (brief suffisant)

---

## Case C-02 — Mode --brief interactif

**Trigger:** `/skill-forge --brief`
**Contexte:** Projet {{PROJECT}}. Dossier `.claude/skills/` existe.
**Input utilisateur:** `/skill-forge --brief`
**Mode:** Interactif — brief manquant

---

## Case C-03 — Brief insuffisant sans --brief

**Trigger:** `/skill-forge`
**Contexte:** Projet {{PROJECT}}.
**Input utilisateur:** `/skill-forge "un skill pour vérifier des trucs"`
**Mode:** Brief insuffisant (objectif vague, pas de triggers, pas d'output défini, pas de hors-scope)

---

## Case C-04 — Demande hors-scope (modifier skill existant)

**Trigger:** `/skill-forge`
**Contexte:** `.claude/skills/lesson/SKILL.md` existe déjà.
**Input utilisateur:** `/skill-forge "modifie le skill lesson pour ajouter un mode --silent"`
**Mode:** Action hors-scope (modification de skill existant)
