# Brief-vs-Contract Verification — Discipline rule

> **Status** : Active 2026-05-10. Étend `feedback_verify_first_relay_protocol.md` (auto-memory, git state axis) avec un axe brief-vs-source.
> **D+ extension (2026-05-10)** : provenance header obligatoire + pre-commit Phase B trigger après cross-vendor adversarial review (Gemini-3-pro-preview + Codex gpt-5.5).
> Note merge : ce fichier existe aussi sur `gsd/phase-20-operator-cockpit`. À la résolution merge, prendre l'union — la version D+ ci-dessous supersede les sections équivalentes.

## Trigger

Cette rule applique quand les 3 conditions sont réunies :

1. Orchestrator (Claude Code main, opérateur via assistant) rédige un brief technique pour relay à un executor (sandbox Claude, Codex CLI, Gemini CLI, subagent, agent task, /{{project}}-execute-phase)
2. ET le brief référence un document source interne (PLAN.md, architecture contract, REVISION-N-SPEC, plan task list, Pass N findings, etc.)
3. ET le document source a été créé ou modifié dans une session antérieure ou parallèle (>1h gap, ou post-compaction)

Out of scope : briefs autonomes sans référence à un document source (single-step task descriptions, ad-hoc questions sans phase liée).

## Discipline minimale — provenance header obligatoire

**Chaque brief envoyé à un executor externe DOIT commencer par un header de provenance** :

```
Source read: <path> @ <sha-or-mtime>
AC copied: <yes|no|n/a>
Helper used: <none|name-of-tool>
```

- `Source read:path/PLAN.md @ a3f9c12` ou `@ 2026-05-10T14:32` (sha de commit OU mtime ISO si non-committed)
- `AC copied: yes` si le brief inclut les §AC-N copiés verbatim, `no` si le brief les référence par citation seulement, `n/a` si le source n'a pas de bloc AC structuré
- `Helper used: none` est la valeur attendue par défaut (D+ ne ship aucun outil) ; champ réservé pour usage futur si Phase B s'enclenche

**Pourquoi le header est non-négociable** : sans provenance trail, le post-mortem d'un incident divergence devient "vibes" — on ne peut pas distinguer "rule respectée + accident" de "rule ignorée". Le header est 1 ligne, coût ergonomique négligeable, valeur mesurable réelle. Cf. cross-vendor adversarial review 2026-05-10 (Codex gpt-5.5 finding #2).

## §AC-N citation requirement (briefs touchant du code)

Si le brief référence une phase qui touche du code ({{SCRIPTING_LANG}}, Python, JS/TS, Bicep, {{WORKFLOW_ENGINE}} workflow JSON, shell scripts), et que le PLAN.md source contient un bloc `acceptance_criteria` YAML structuré, le brief DOIT citer `§AC-N` (par exemple `§AC-3`) verbatim ou par référence claire au lieu de paraphraser.

Mécanique d'extraction (pas d'outil dédié, sed-only) :

```bash
sed -n '/```yaml/,/```/p' .planning/phases/{phase-slug}/PLAN.md
```

Si le source PLAN.md n'a pas de bloc AC structuré, marquer `AC copied: n/a` dans le header de provenance et lister les ACs en prose dans le brief avec citation claire de la section source.

## Trois rôles, trois disciplines

### 1. Orchestrator side

**Avant rédaction du brief** :

1. `Read` le document source en entier — pas de recall, pas de résumé, pas de mémoire conversationnelle
2. Citer chaque deliverable du brief par numéro de section (`§3 schema`, `§7 smoke contract`, `§AC-N`)
3. Cross-référencer counts, file paths, scope boundaries, identifier names entre brief et contrat
4. Émettre le **header de provenance** en haut du brief (template ci-dessus)
5. Si une instruction du brief ne s'adosse pas à une section identifiable → flag explicite "**extension contract**" ou "**deviation contract**" + justification

**Anti-pattern** : écrire le brief de mémoire conversationnelle après compaction ou multi-heures de gap. Coût récurrent : 5-10 min de re-read vs 30+ min de divergence triage post-relay + risque d'agir sur instruction erronée.

### 2. Executor side

**Avant tout STEP 2 reads ou code** :

1. Lire le header de provenance — si absent → STOP + ping opérateur "brief sans provenance header, refuser conformément à brief-contract-verification.md"
2. Read brief + read source contract référencé en parallèle
3. Build divergence table — pour chaque instruction du brief, identifier quelle section du contrat l'autorise ou la contredit
4. Si divergences détectées → STOP + ping opérateur avec table 4-axes :
   - **(a) field/identifier name** — ex: `ExecutionTimeIso` brief vs `StartedAtUtc` contract
   - **(b) implementation ordering / scope boundary** — ex: brief mixe R11.1 + R11.3 / contract §12 sépare
   - **(c) count / fixture / file path** — ex: brief 27/27 / contract §7 22/22, file split vs modify-existing
   - **(d) architectural premise** — ex: brief assume mtime / contract §4 interdit
5. Si zéro divergence → proceed STEP 2

**Anti-pattern** : agir sur le brief sans vérifier source. Brief = relay, pas source of truth. Verify-first inclut brief-vs-source, pas seulement git state.

### 3. Operator side

**Quand executor ping divergences** :

1. Trancher chaque divergence avec default reasoning explicit
2. Verification step (Read source ou code) si reasoning incertain
3. Authoriser proceed ou STOP — pas d'authorization automatique
4. Si pattern récurrent (3+ briefs avec divergences sur la même session) → escalate orchestrator avec re-frame

## Pre-commit Phase B trigger (binding)

**Falsification window** : prochains **5 external code briefs** OU **30 jours calendaires** à partir de 2026-05-10, premier seuil atteint.

**Trigger Phase B (schema gate)** : *"Si 2 des 5 prochains code briefs produisent une AC/source divergence après application de cette rule (avec provenance header présent), implémenter le schema gate (PLAN.md `kind: code` + plan-checker hard-reject) avant tout nouveau code phase non-emergency."*

**Mesure** : compter les divergence tables pingées par executors (cf. §2 step 4) sur briefs portant un header de provenance valide. Sans header valide → brief n'est pas dans le décompte (le défaut de discipline est la cause, pas la falsification de la rule).

**Engagement** : ce trigger n'est pas comfort language. Si la condition est remplie, le schema gate est obligatoire avant le prochain code phase (sauf emergency hotfix explicitement justifié). Cf. cross-vendor review 2026-05-10 (Codex finding #4 : "without that sentence, Phase B is just comfort language").

**Re-évaluation** : à 30j ou 5 briefs, faire le bilan dans MEMORY.md, décider Phase B (gate) ou continuation (rule suffit).

## Modèle de divergence table (executor → operator)

```
| ID | Brief says | Contract §X says | Impact / decision needed |
|----|-----------|------------------|--------------------------|
| D1 | (citation) | (citation §N)    | (axis a/b/c/d + question) |
| D2 | ...       | ...              | ...                      |
```

Recommandation : le sandbox/executor propose des **defaults explicit** pour chaque divergence (avec rationale) — operator confirme ou dévie. Default reasoning rend la décision rapide sans surprendre.

## Pourquoi pas de skill `/derive-brief` ou plan-checker

Cross-vendor adversarial review 2026-05-10 (Gemini-3-pro-preview + Codex gpt-5.5) a converged sur :

- Un script `derive-brief.py` n'adresse pas le bypass (operator under load oublie le helper)
- Schema YAML dans PLAN.md ne change pas le comportement opérateur-under-load
- Précédent corpus-skill (2026-04-23) : root cause comportementale → fix = rule, pas infra
- /{{project}}-execute-phase Phase 20 fonctionne car verifier déterministe à la frontière **exécution**, pas convenience optionnelle à la frontière **drafting humain** — pas le même pattern

Donc D+ ship rule + provenance header + trigger seulement. Si inadequate sur 5 briefs ou 30j, escalation vers schema gate (Phase B) — engagement non-optionnel.

## Relationship aux autres règles

| Axe | Rule canonique | Couvre |
|-----|---------------|--------|
| Claim grounding | `cognitive-patterns.md` | {{RAG_BACKEND}} query before factual assertion |
| Task completion | `verification-discipline.md` (skill `gsd-verifier`) | Work done before claim |
| Git state | `feedback_verify_first_relay_protocol.md` (auto-memory) | Workspace ground truth before relay |
| **Brief vs source + provenance** | **Cette règle (D+)** | **Instruction text vs canonical document, header obligatoire, trigger Phase B** |

Les 4 axes sont orthogonaux. Discipline complète sur task multi-agent = les 4 passées.

## Related sources

- `feedback_verify_first_relay_protocol.md` (auto-memory) — git state verification axis
- `feedback_taskbrief_inline_test_conflicts.md` (auto-memory) — précédent brief inline snippets vs grep ACs
- `feedback_brief_from_memory_unreliable.md` (auto-memory) — précédent brief drafted from memory after compaction
- LESSONS.md 2026-05-06 entries — Phase 14.1 R11.1 incident référence
- `cognitive-patterns.md` — broader anti-rationalization framework
- `docs/brainstorms/rejected/2026-05-09-plan-phase-determinism-contract-requirements.md` — origine, brainstorm rejeté avec verdicts adversariaux complets
- `.claude/workspace/2026-05-10-gemini-arch-review-plan-phase-determinism.md` — verbatim Gemini-3-pro-preview adversarial review
- `.claude/workspace/2026-05-10-codex-review-plan-phase-determinism.md` — verbatim Codex gpt-5.5 adversarial review (full transcript incl. tool searches)

## Promotion log

| Date | Event | Rationale |
|------|-------|-----------|
| 2026-05-06 | Création initiale (gsd/phase-20-operator-cockpit) | Fix Phase 14.1 R11.1 incident |
| 2026-05-10 | D+ extension : provenance header + Phase B trigger | Cross-vendor adversarial review (Gemini + Codex) sur brainstorm `plan-phase-determinism-contract` ; verdicts convergent ont rejeté schema gate au profit de rule-only avec measurement |
