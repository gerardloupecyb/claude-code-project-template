# skill-forge — Behavioral Rules & Out-of-Scope

## Behavior rules

- Ne jamais supposer le contenu du framework — toujours lire le fichier
- Ne jamais créer un skill sans tests/ (obligation du framework)
- Step 3 (drafting) est toujours délégué à un Agent — ne pas drafter inline
- Si le brief est ambigu sur le hors-scope, demander avant de drafter
- Max 3 rounds d'itération (structurel + comportemental combinés) ; au-delà : escalader

## What this skill does NOT do

- Modifier des skills existants → utiliser `/skill-refresh` pour les mises à jour
- Créer des skills dans des domaines protégés sans skill-gate approprié
- Bypasser le framework — même si l'utilisateur le demande, expliquer pourquoi
- Déployer ou registrer automatiquement sans confirmation utilisateur

## Rapport final — format

```
## Skill Forge — {nom}

Fichiers créés :
  .claude/skills/{nom}/SKILL.md              ({N} lignes)
  .claude/skills/{nom}/references/*.md       ({N} fichiers)
  .claude/skills/{nom}/tests/cases.md        ({N} cas)
  .claude/skills/{nom}/tests/assertions.md

Validation structurelle : {N}/{N} checks OK
Validation comportementale : {N}/{N} cas PASS

Verdict : PASS ✓ / FAIL ✗ (voir détails)
```

Si PASS : proposer d'ajouter le skill au component registry et skills-inventory.
Si FAIL : lister les checks/cas en échec avec diagnostic.
