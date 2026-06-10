# Assertions — skill-forge

## Assertions — Case C-01 (Brief complet)

**MUST contain:**
- [ ] Mention des fichiers créés (SKILL.md, references/, tests/)
- [ ] Validation structurelle : tableau de checks avec PASS/FAIL
- [ ] Rapport final avec verdict PASS ✓
- [ ] Proposition d'ajouter au component registry

**MUST NOT contain:**
- [ ] Questions sur le brief (il est suffisant)
- [ ] Modification d'un skill existant

**MUST read:**
- [ ] `.claude/rules/skill-framework.md` avant le drafting (Step 2)

**MUST NOT read:**
- [ ] `references/brief-template.md` (brief est complet, pas besoin)

---

## Assertions — Case C-02 (Mode --brief)

**MUST contain:**
- [ ] Les 7 questions du template (`references/brief-template.md`)
- [ ] Regroupées en une seule interaction (pas 7 questions séparées)

**MUST read:**
- [ ] `references/brief-template.md`

**MUST NOT contain:**
- [ ] Création de fichiers avant que les questions soient posées

---

## Assertions — Case C-03 (Brief insuffisant)

**MUST contain:**
- [ ] Signal que le brief est insuffisant
- [ ] Questions ciblées uniquement sur les informations manquantes
- [ ] Pas toutes les 7 questions — seulement les non-répondues

**MUST NOT contain:**
- [ ] Création de fichiers avant complément du brief
- [ ] Hallucination d'informations manquantes

---

## Assertions — Case C-04 (Hors-scope)

**MUST contain:**
- [ ] Refus explicite de modifier un skill existant
- [ ] Mention de `/skill-refresh` comme alternative appropriée
- [ ] Explication courte du hors-scope

**MUST NOT contain:**
- [ ] Tentative d'éditer `.claude/skills/lesson/SKILL.md`
- [ ] Création d'un nouveau skill nommé "lesson" en doublon
