# Behavioral Tests — Skill Forge

Comment exécuter les tests comportementaux à Step 5.
Les cas et assertions se trouvent dans `tests/` du skill testé, pas ici.

---

## Format de tests/cases.md

```markdown
## Case C-01 — {Nom descriptif}

**Trigger:** `/nom-skill` (ou formulation naturelle)
**Contexte:** {Fichiers présents, état du projet simulé, variables d'environnement}
**Input utilisateur:** {Ce que l'utilisateur a tapé exactement}
**Mode:** {Si le skill a des modes : lequel}
```

## Format de tests/assertions.md

```markdown
## Assertions — Case C-01

**MUST contain:**
- [ ] {Élément précis attendu dans l'output}
- [ ] {Autre élément attendu}

**MUST NOT contain:**
- [ ] {Élément qui indiquerait un bug}

**MUST read:** (fichiers que Claude doit avoir lus)
- [ ] `references/{fichier}.md` si mode X

**MUST NOT read:** (fichiers que Claude ne doit PAS charger inutilement)
- [ ] `references/section-lourde.md` si mode Y non activé
```

---

## Process d'exécution

### Pour chaque cas dans tests/cases.md

1. **Lire** `tests/cases.md` → extraire le contexte et l'input du cas
2. **Lire** `tests/assertions.md` → extraire les assertions pour ce cas ID
3. **Spawner un Agent** `general-purpose` avec ce prompt :

```
Tu es Claude Code. L'utilisateur a invoqué un skill.

Voici le contenu du skill ({nom}/SKILL.md) :
[contenu complet du SKILL.md]

Voici les fichiers references/ disponibles :
[liste des fichiers + leur contenu]

Contexte du test :
[contenu de Case C-XX depuis tests/cases.md]

Input utilisateur : "{input}"

Exécute le skill pour cet input et ce contexte. Produis l'output complet que tu retournerais à l'utilisateur.
```

4. **Évaluer l'output** de l'Agent contre chaque assertion :
   - MUST contain → vérifier présence exacte ou sémantique proche
   - MUST NOT contain → vérifier absence
   - MUST read → l'Agent cite-t-il ces fichiers dans son raisonnement ?
   - MUST NOT read → l'Agent évite-t-il de charger des fichiers non pertinents ?

5. **Grader** : PASS (toutes assertions OK) ou FAIL (≥ 1 assertion violée)

---

## Rapport de cas

```
## Behavioral Tests — {nom}

| Case  | Nom                     | Résultat | Assertions échouées |
|-------|-------------------------|----------|---------------------|
| C-01  | Invocation simple       | PASS     | —                   |
| C-02  | Mode avancé             | FAIL     | MUST contain §Output format |
| C-03  | Input invalide          | PASS     | —                   |

Résultat global : {N} PASS, {M} FAIL
```

---

## Diagnostic de failure

Avant de patcher, identifier la cause :

| Symptôme | Cause probable | Correction |
|----------|---------------|------------|
| Output ne contient pas le format attendu | Section Output format absente ou dans references/ non chargé | Ajouter format inline ou vérifier routing table |
| Claude charge un mauvais fichier references/ | Routing table ambiguë ou conditions mal définies | Clarifier conditions dans la routing table |
| Claude hallucine du contenu de règles canoniques | SKILL.md ne pointe pas vers le fichier canonique | Ajouter "Lire `.claude/rules/X.md`" explicitement |
| Output incomplet (étapes manquantes) | Workflow trop court dans SKILL.md, référence pas chargée | Déplacer le workflow détaillé dans references/ |
| Claude ne respecte pas le token budget | SKILL.md trop verbeux → Claude ne lazy-load pas | Réduire SKILL.md, enrichir references/ |

---

## Règles de robustesse

- Les assertions MUST NOT read sont importantes : elles vérifient le lazy loading
- Un cas par mode principal du skill (minimum)
- Un cas "input invalide / hors-scope" obligatoire — vérifie que "What this skill does NOT do" est respecté
- Les assertions sont sémantiques, pas de regex exacte — tolérer reformulations équivalentes
