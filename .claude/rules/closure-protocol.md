# Closure Protocol — checklist post-exécution

APPLICABILITY: Obligatoire après chaque `/gsd:execute-phase`.

Closure n'est pas un skill — c'est une checklist mécanique :

1. Écrire `.planning/{phase}-{N}-SUMMARY.md` :
   - Planifié vs réalisé (ce qui a divergé du plan et pourquoi)
   - Décisions prises pendant l'exécution
   - Items différés (ce qui n'a pas été fait et pourquoi)
2. Mettre à jour `memory/MEMORY.md` (Règle #2)
3. Logger les déviations dans la table "Déviations d'exécution" de MEMORY.md
4. Proposer `/lesson` si un fix non-trivial a été résolu
5. Lancer les tests existants si un test runner est configuré (ex: `npm test`, `pytest`, `rspec`). Si des tests échouent, corriger AVANT de passer à `/gsd:verify-work`.
6. Quality score — ajouter dans le SUMMARY.md de la phase :
   - AC coverage: X/Y AC satisfaits
   - Deviations: N déviations loguées pendant l'exécution
   - Verdict: CLEAN (0 déviations ET tous les AC satisfaits) | ROUGH (tout le reste)
   - Si ROUGH : proposer `/lesson` avec focus "pourquoi le plan n'a pas tenu"
     (remplace la proposition `/lesson` du step 4 pour cette session)
7. Si des décisions ont été prises pendant l'exécution et ne sont pas dans DECISIONS.md : proposer l'ajout au format DEC-NNN
