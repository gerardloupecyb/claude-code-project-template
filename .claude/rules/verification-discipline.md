# Verification Discipline

> Auto-injecté par Claude Code. Source canonique de la discipline de vérification.
> Adapté de obra/superpowers verification-before-completion.

## The Iron Law

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

Avant de dire "Done", "terminé", "task complete", ou toute variante :
1. **IDENTIFY** — quelle commande ou vérification est nécessaire
2. **RUN** — exécuter la commande (pas se souvenir d'une exécution précédente)
3. **READ** — lire le output complet et le code de sortie
4. **VERIFY** — confirmer que l'output supporte la claim
5. **ONLY THEN** — faire la claim avec l'evidence dans le message

Sauter une étape = violation.

## Evidence Requirements

| Claim | Evidence requise | Insuffisant |
|-------|-----------------|-------------|
| "Tests pass" | Output du test runner montrant 0 failures | Exécutions précédentes, suppositions |
| "Script works" | Output réel de l'exécution + exit code | "Should work", "devrait fonctionner" |
| "No regressions" | Output complet de la suite de tests | Vérifications partielles |
| "Bug fixed" | Le symptôme original passe maintenant | Changements de code seuls |
| "Phase complete" | SUMMARY.md écrit + MEMORY.md mis à jour + verify-work | Tests seuls |
| "Ready to execute" | Markers `.planning/phases/{phase}/PLAN-CHECKER-PASS` **ET** `.planning/phases/{phase}/ADVERSARIAL-REVIEW-PASS` (ou `ADVERSARIAL-REVIEW-WAIVED.md` documentant la raison du waiver) coexistent **ET** le verdict pre-flight le plus récent = GO (le marker ADVERSARIAL-REVIEW-PASS ne peut être posé AVANT un pre-flight GO — gate-ordering Phase 27.2) (ou exemption `--skip-verify` / `plan_checker_enabled: false` documentée) | "Le plan est prêt", "plan-checker a passé", "cross-vendor a passé" — plan-checker valide la structure, l'adversarial valide la sémantique design, mais ni l'un ni l'autre ne remplace le pre-flight (lentilles orthogonales). Voir § "Plan-Checker ≠ Adversarial Review" |
| "Commit clean" | git status + SAST output | "J'ai vérifié" sans output |
| "Codex done {id} validé" | `git show {commit} --stat` + diff complet lu + vérification relancée + artefacts cités explicitement | Counts du brief, observations auto-déclarées de Codex |

## Red Flag Phrases — STOP immédiat

Si tu es sur le point de dire une de ces phrases, STOP et applique le 5-step gate :

- "should work now" / "devrait fonctionner maintenant"
- "I'm confident" / "je suis confiant"
- "seems to" / "semble"
- "probably fine" / "probablement OK"
- "just this once" / "juste cette fois"
- toute expression de satisfaction avant vérification

## System-Wide Test Check

Before marking a code task done, answer these 5 questions:

| Question | Action |
|----------|--------|
| **What fires when this runs?** Callbacks, middleware, observers, event handlers — trace two levels out. | Read actual code for callbacks on models you touch, middleware in the chain, `after_*` hooks. |
| **Do tests exercise the real chain?** All-mocked tests prove logic in isolation, not interaction. | Write at least one integration test with real objects through the full chain. |
| **Can failure leave orphaned state?** State persisted before an external call — what if it fails? | Trace the failure path. Test that failure cleans up or retry is idempotent. |
| **What other interfaces expose this?** Mixins, DSLs, alternative entry points. | Grep for the method in related classes. If parity needed, add it now. |
| **Do error strategies align across layers?** Retry middleware + app fallback + framework handling — conflicts? | List error classes at each layer. Verify rescue list matches what lower layers raise. |

**Skip:** Leaf-node changes with no callbacks, no state persistence, no parallel interfaces.

## Fix Escalation Gate

Quand plusieurs tentatives de fix échouent sur le même bug :

**Trigger primaire** — si le fix N révèle un problème dans un endroit *différent* que le fix N-1 : **STOP avant le fix N+1**. C'est un signal de coupling architectural, pas un bug isolé.

**Backstop** — après 3 tentatives distinctes sans succès : **STOP** même si les problèmes semblent au même endroit.

**Distinguer :**
- Erreurs d'environnement / syntaxe (credential expirée, version manquante, typo) → retry acceptable, ne comptent pas comme "fix distinct"
- Régressions logiques / fonctionnelles (comportement incorrect, test échoue) → comptent comme fix distinct

**Action obligatoire :** Écrire un résumé des 3 tentatives + localisation de chaque symptôme. Discuter avec l'humain avant de continuer. Ne pas tenter Fix #4 sans ce checkpoint.

> Alignement : ce gate complète le cap 2-retries cross-vendor de `router-rules.md` § "Failure & Retry Protocol". Pour les tâches Codex/Gemini, le protocole router-rules prend précédence (2 retries max puis Opus reprend). Ce gate s'applique aux sessions Claude directes.

## Artifact-Specific Promotion Gates

For promotions to production ({{WORKFLOW_ENGINE}} workflows, {{SCRIPTING_LANG}} scripts, runbooks), also apply the gate defined in `.claude/skills/promote/SKILL.md` § "Mandatory Pre-Promote Gate". Generic verification claims are not sufficient for promotion — artifact-specific functional validation is required.

**Knowledge-layer DB migrations (`knowledge-broker/migrations/*.sql`) — canary evidence required (DEC-041).** A migration touching the live {{KNOWLEDGE_BACKEND}}/pgvector schema, role privileges, or anything {{KNOWLEDGE_BACKEND}}'s boot-time `create_all()` depends on MUST NOT reach prod without a **passing clone-canary run** per `docs/runbooks/knowledge-layer-db-migration-canary.md` (real {{KNOWLEDGE_BACKEND}}, fresh volume, two clean cold-starts). An empty throwaway test container validates SQL *logic* only — it cannot catch SQLAlchemy reflection / cold-start permission-deny failures. "Migration applied to canary, two cold-starts green, evidence captured" is the evidence; "the SQL is idempotent" is NOT sufficient. Promotion path: `/promote` Rule 2d → `references/flow-knowledge-db.md`.

## Plan-Checker ≠ Adversarial Review (structural ≠ semantic)

Le marker `PLAN-CHECKER-PASS` certifie que la **structure** du plan est valide (frontmatter, AC coverage, dépendances, dimensions Nyquist). Il **ne certifie pas** que les prémisses sémantiques du plan tiennent contre la réalité du code.

**Ce que plan-checker fait :**
- Lit les frontmatter, AC tags, dépendances, threat model blocks
- Vérifie présence/absence de champs requis
- Mesure la couverture par template

**Ce que plan-checker NE fait PAS :**
- Lire les fichiers cibles (cascade JSON, code source) pour vérifier les claims du plan
- Raisonner sur la sémantique (ex: scoping dynamique {{SCRIPTING_LANG}}, parser whitelist {{WORKFLOW_ENGINE}}, IF node conditions)
- Vérifier les prérequis externes (sessions parallèles, état de branches sœurs, briefs en flight)
- Détecter les asymétries entre "le plan dit X" et "le fichier impose Y"

**Conséquence :** un plan peut passer plan-checker tout en reposant sur des prémisses sémantiquement fausses. Le seul moyen de capter cette asymétrie : **adversarial review** (Codex / Gemini / domain-expert reviewer) qui lit les fichiers cibles et raisonne contre les claims.

**Iron Law amendée :**

> Pour qu'un plan soit `Ready to execute`, deux markers doivent coexister dans `.planning/phases/{phase}/` **ET** le pre-flight le plus récent doit avoir retourné GO :
> - `PLAN-CHECKER-PASS` — structure validée
> - `ADVERSARIAL-REVIEW-PASS` — prémisses sémantiques design validées (ou `ADVERSARIAL-REVIEW-WAIVED.md` documentant pourquoi un waiver est acceptable — ex: trivial bug fix, refactor sans changement de contrat, doc-only)
> - **Pre-flight verdict = GO.** Le marker `ADVERSARIAL-REVIEW-PASS` NE PEUT PAS être posé avant que `/{{project}}-pre-flight` ait retourné GO. Si le pre-flight retourne CONDITIONAL GO ou NO-GO : résoudre les findings, re-run le pre-flight, ALORS poser le marker. **Gate-ordering (Phase 27.2, 2026-06-05) :** le marker adversarial a été posé à `ca34154e` PUIS pre-flight a trouvé 3 HIGH (audit-sink PII bypass, source_pdf_sha256 unauditable, AM-5 non-bound) → marker stale. Cause racine : adversarial review (Codex+Gemini "casser le design") et pre-flight (STRIDE + privacy-lens + AC-binding + implementability) sont des **lentilles orthogonales**, pas redondantes. Un PASS adversarial ne préjuge pas du pre-flight. L'ordre canonique est donc : adversarial → pre-flight GO → ALORS poser le marker. Un marker posé avant le pre-flight GO est par construction stale-able.

**Cas réel ayant motivé cette règle (Phase 14.2, 2026-04-29) :**
- Plan-checker iter 1 : PASS (3 blockers + 4 warnings closed)
- Adversarial review (Codex + Gemini, parallèles) : NO-GO converge avec 6 BLOCKERS sémantiques :
  - Cascade Route nodes ne checkent pas `Status='Skipped'` → D-11 invalidée
  - Cascade webhook input model n'a pas les modes per-step → T1..T7 impossible
  - DP sub-cascade parser whitelist `WhatIf|Apply` only → ReportOnly+Skipped silently coercés
  - Plan 06 cleanup script path wrong + `-WhatIf` default = dry-run
  - Hygiene `$WhatIfPreference` dynamic-scope risk (6 ShouldProcess sites)
  - Surgical merge by-name lacks pre-validation jq assertion
- Aucun de ces 6 n'aurait été capté par plan-checker seul. Tous ont été confirmés par lecture directe des fichiers (`jq`, `grep`, `ls`).

**Quand l'adversarial review est obligatoire :**
- Plans qui modifient un contrat partagé (cascade, API, runbook signature)
- Plans qui touchent ≥ 2 plans (dépendances cross-plan)
- Plans qui prétendent "subsumer" un autre plan ou brief en flight
- Plans avec scope > 5 fichiers ou > 3 plans
- Plans dont le succès dépend de l'état d'une session parallèle
- Tout plan dont le plan-checker pass repose sur des claims non-vérifiables sans lire les fichiers cibles
- **Class nommée Phase 27.1.1 D-15** (auth + audit + route surface + scope-guard) : cross-vendor
  Codex + Gemini mandatory, no waiver. Voir § Cross-vendor adversarial review.

### Cross-vendor adversarial review (OpenAI + Gemini)

**Established Phase 27.1.1 (D-15) — applies generically to any phase touching the named class.**

**Amendé 2026-06-08 (op. {{OWNER}}, RPRP) — transport de la voix OpenAI :** le cross-vendor exige une **voix OpenAI ET une voix Google (Gemini)**. La voix OpenAI peut emprunter **deux transports** — **Codex CLI** OU le **modèle OpenAI via OpenRouter** — selon `router-rules.md` § Executor Registry (**source canonique du modèle** : ne pas dupliquer de nom de modèle ici). Le transport est indifférent ; seule compte la présence des deux familles de vendor.

Pour les phases qui touchent une des classes suivantes, **l'adversarial review DOIT être exécuté
par une voix OpenAI ET Gemini** (les deux vendors, pas un seul) :

- **Authentification** : JWT validation, token-scope checks, agent-key registries
- **Pipeline d'audit** : ordering (mark/fsync/durable write), event-type allowlist, target_uri convention, audit-log rotation/path resolution
- **Surface de routes** : nouveau/supprimé endpoint, scope-guard guards, public-vs-internal route surface
- **Scope-guard / DLP / DEC-037** : content policy, allowlist/denylist semantics, PII detectors

**Procédure :**
1. Pre-execute : `ADVERSARIAL-REVIEW-PASS` marker requires Codex PASS AND Gemini PASS sur le PLAN.md
2. Post-execute, pre-merge : `/{{project}}:review` Steps 5+6 (Codex sur git diff main, Gemini sur git diff main)
3. **Divergence** entre Codex et Gemini = NO-GO. Reconcilier avant de poser le marker.
4. **Pas de waiver** pour la classe nommée — `ADVERSARIAL-REVIEW-WAIVED.md` est interdit.
5. Si une **famille de vendor** (OpenAI *ou* Google) est indisponible → BLOCK (pas de single-vendor fallback). La voix OpenAI n'est « indisponible » que si **les deux** transports échouent (Codex CLI **ET** OpenRouter per router-rules) — un quota Codex CLI seul ne déclenche PAS le BLOCK tant qu'OpenRouter (`openai/gpt-5.5`) fournit la voix OpenAI.

**Précédent** : Phase 27.1 a sauté `/{{project}}:review` à la closure → 8 P1 trouvés post-merge → Phase
27.1.1 (hotfix). Voir `.claude/workspace/27.1-{{project}}-review-postmerge.md`.

**Phases qui s'appliquent automatiquement** :
- Phases dans les domaines `knowledge-layer/`, `auth/`, `audit/`, `scope_guard/`
- Phases qui modifient les fichiers `*Route*`, `*audit*`, `*auth*`, `*scope_guard*`, `*token*`,
  `*lifespan*` dans le runtime plane

**Quand un waiver est acceptable (ADVERSARIAL-REVIEW-WAIVED.md) :**
- Bug fix isolé, scope < 5 fichiers, pas de contrat changé
- Refactor pur sans changement de comportement
- Doc-only changes
- Phases dont l'execute-phase invoque automatiquement un test de régression complet (CI green = adversarial review functional equivalent)

Le waiver doit nommer la raison + l'auteur + la date. Pas de waiver verbal.

## Post-Deploy Monitoring

For any change touching production runtime code, document in SUMMARY.md or commit message:
- **Logs/search terms**, **Metrics/dashboards**, **Expected healthy signal**, **Failure signal + rollback trigger**

If no runtime impact: `No monitoring needed: [reason]`

## Rationalizations — NEVER ACCEPT

| Excuse | Réalité |
|--------|---------|
| "C'est trivial, pas besoin de vérifier" | Les changements triviaux cassent des choses. Vérifier prend 30 secondes. |
| "J'ai déjà vérifié mentalement" | La vérification mentale n'a aucune valeur probante. Exécuter. |
| "Le changement est tellement petit que ça ne peut pas casser" | C'est exactement quand les bugs arrivent. |
| "On vient de vérifier il y a 2 minutes" | Les vérifications précédentes ne comptent pas après des modifications. |
| "Je suis sûr que ça marche" | La certitude sans preuve = rationalization. |
| "Le skip heuristic s'applique ici" | Seulement si AUCUN callback, AUCUN state, AUCUNE interface parallèle. |
| "Le plan-checker a déjà tourné" / "Je l'ai lancé" | Sans marker `PLAN-CHECKER-PASS` dans `.planning/phases/{phase}/`, le plan-checker n'a PAS tourné. Créer le marker est la preuve. |
| "Plan-checker passed, donc le plan est ready-to-execute" | Plan-checker = structure. Pour ready-to-execute, `ADVERSARIAL-REVIEW-PASS` (ou WAIVED) est aussi requis. Voir § "Plan-Checker ≠ Adversarial Review". |
| "Pas besoin de monitoring pour ça" | Si ça touche du runtime code, documenter. Pas d'exception. |
