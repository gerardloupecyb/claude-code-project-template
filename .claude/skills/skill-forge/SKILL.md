---
name: skill-forge
description: >
  Crée un skill complet (SKILL.md + references/ + tests/) respectant le framework
  {{PROJECT}}, valide structurellement, teste comportementalement, itère jusqu'à passer.
  Triggers on: skill-forge, forge skill, créer un skill, nouveau skill, new skill.
---

# /skill-forge — Créateur de skill avec validation

Crée, valide, et teste un skill jusqu'à ce qu'il respecte le framework {{PROJECT}}.
Lit le framework comme contrainte de design — jamais depuis la mémoire.

---

## References

| Fichier | Charger quand |
|---------|---------------|
| `references/brief-template.md`  | Step 1 — brief incomplet ou manquant |
| `references/structural-checks.md` | Step 3 — validation structurelle |
| `references/behavioral-tests.md` | Step 4 — validation comportementale |
| `references/process-rules.md`   | Step 6 — rapport final + behavior rules |

Charger aussi : `.claude/rules/skill-framework.md` (toujours, Step 2)

---

## Usage

```
/skill-forge "nom-du-skill — description courte de ce qu'il doit faire"
/skill-forge --brief  ← mode interactif, lit references/brief-template.md
```

---

## Process

### Step 1 — Lire le brief

Si argument fourni : utiliser comme brief.
Si `--brief` ou brief insuffisant : lire `references/brief-template.md`, poser les questions manquantes.

Un brief suffisant contient : nom, objectif, triggers, mode(s), outputs attendus, hors-scope.

### Step 2 — Lire le framework

Lire **maintenant** `.claude/rules/skill-framework.md` complet.
Ne pas travailler de mémoire — le framework peut avoir changé.

### Step 3 — Drafting (Agent isolé)

Spawner un Agent `general-purpose` avec :
- Le brief complet
- Le contenu de `.claude/rules/skill-framework.md`
- L'instruction de produire : SKILL.md + references/*.md + tests/cases.md + tests/assertions.md

L'Agent écrit les fichiers directement dans `.claude/skills/{nom}/`.
Retourner quand tous les fichiers sont créés.

### Step 4 — Validation structurelle

Lire `references/structural-checks.md`.
Exécuter chaque check mécaniquement contre les fichiers créés.
Produire un tableau : `check | résultat | détail`.

Si échecs : patcher les fichiers directement (pas re-spawner l'Agent).
Max 2 rounds de patch. Si encore en échec → surface à l'utilisateur avec diagnostic.

### Step 5 — Validation comportementale

Lire `references/behavioral-tests.md`.
Pour chaque cas dans `tests/cases.md` :
- Spawner un Agent `general-purpose` avec le SKILL.md + contexte du cas
- Demander à l'Agent d'exécuter le skill pour ce scénario
- Comparer output contre `tests/assertions.md`

Si un cas échoue : identifier la cause, patcher, re-tester le cas.
Max 3 rounds total (structurel + comportemental combinés). Après 3 : STOP, rapport d'échec.

### Step 6 — Rapport final

Lire `references/process-rules.md` pour le format de rapport et les behavior rules.
Appliquer le verdict PASS / FAIL et proposer la mise à jour des registres si PASS.
