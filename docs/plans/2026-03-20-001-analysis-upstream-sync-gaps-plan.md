# Analyse des ecarts upstream — CE v2.46 + GSD v1.27

**Date:** 2026-03-20
**Status:** done
**Type:** gap analysis + recommandations
**Sources:** compound-engineering-plugin (v2.40→v2.46), get-shit-done (→v1.27)
**Deepened:** 2026-03-20 (architecture-strategist, spec-flow-analyzer, code-simplicity-reviewer)

---

## Deepening Summary

### Review findings: 5 HIGH, 7 MEDIUM, 5 LOW severity issues

**5 decisions architecturales a resoudre AVANT implementation :**

1. **DEC-A: Auto memory vs MEMORY.md** — Qui est source de verite ? CE v2.45 lit auto memory mais les hooks template ne gerent que MEMORY.md → asymetrie. Decision recommandee : MEMORY.md = source de verite structuree, auto memory = supplementaire en lecture seule. Creer DEC-NNN dans DECISIONS.md.

2. **DEC-B: Context monitor vs pre-compact.sh** — GSD context monitor et pre-compact.sh touchent le meme lifecycle. Risques : double-snapshot, ordering indetermine, registry hooks concurrents. Decision : choisir Option A (garder pre-compact.sh, desactiver GSD monitor), B (remplacer par GSD monitor), ou C (layerer avec ordering explicite). Creer DEC-NNN.

3. **Rollback strategy** — Tag `pre-sync-v2.46` AVANT Phase 1. Si regression, revert.

4. **Compatibilite gate** — Phase 1 doit inclure verification post-upgrade (executer `/ce:review`, `/ce:compound`, `/gsd:plan-phase` une fois) avant Phase 2.

5. **Layer 2 dependency** — Le plan Layer 2 (DECISIONS.md template) n'est pas encore implemente. Certaines recommendations y font reference. Verifier independance.

### Simplification appliquee : 21 → 10 actions

| Action | Recommandations |
|--------|----------------|
| **CUT** (7) | 1.5 WAITING.json, 2.3 /gsd:do, 2.5 notes/seeds, 3.5 advisor mode, 3.6 ce:ideate, 4.5 profiling, 1.7 session report |
| **SIMPLIFY** (5→2) | Consolider 2.1+2.2+2.6 en 1 edit parcours, merger 3.1+3.2+3.3 en 1 edit Rule 8 |
| **DEFER** (3) | 1.3 threads, 2.9 verif debt, 2.8 requirements gate |
| **KEEP** (5) | 1.1 auto memory, 1.2 context budget, 1.6 context monitoring, 2.7 regression gate, 4.2 security |
| **Passive gains** (5) | 1.4 HANDOFF.json, 2.10 stub detection, 2.11 todo-parallel, 4.3 MCP awareness, 3.4 decision IDs |

**Impact token budget : +12 lignes (458 total) au lieu de +80 (526). Pas d'extraction vers rules/ necessaire.**

### Feature overlap matrix (a clarifier dans la doc)

| Capture | Quoi | Quand |
|---------|------|-------|
| MEMORY.md | Etat projet (ou on est, prochaine etape) | Debut/fin session |
| LESSONS.md | Lecons apprises (quand/faire/parce que) | Apres fix non-trivial |
| Supermemory | Archive cross-projet | Migration cap 50 |
| Auto memory (Claude) | Notes implicites de Claude (read-only) | Supplementaire pour ce:compound |

| Review | Quoi | Quand |
|--------|------|-------|
| /ce:review | 15 agents internes Claude | Apres execution |
| /gsd:review | CLI externes (Gemini, Codex) | Optionnel, quand CLI disponibles |

### Risques supplementaires identifies

- **init-project.sh** non mis a jour pour copier les nouveaux fichiers rules/ — ajouter explicitement en Phase 2
- **Pas de guide de migration** pour les projets existants — ajouter en Phase finale
- **CARL rule slots** proches de la capacite (RULE_6/7 actives, template max RULE_8)
- **Rule 8 over-complication** si on ajoute plan depth + technical design + execution posture + decision IDs → merger plan depth dans Rule 4 comme extension du trigger 2-of-5
- **Doublons GSD↔CE non routes** — `/gsd:review --all` et `/gsd:autonomous` ajoutent des steps aux parcours sans conditions de declenchement → risque de pipeline systematique a 10 etapes. Corrige : conditions explicites ajoutees en Phase 2 #5
- **Flywheel ne consulte pas auto memory** — `ce:compound` v2.46 scanne auto memory mais le flywheel ne le mentionne pas → ajout etape 1.5 en Phase 2 #7

---

## Etat courant du projet

| Composant | Version locale | Version upstream | Delta |
|-----------|---------------|-----------------|-------|
| Compound Engineering | v2.40.0 | v2.46.0 | **6 versions** |
| GSD | ~v1.24 | v1.27.0 | **~3 versions** |
| CARL | custom domains | inchange | — |
| Hooks | session-start + pre-compact | +context-monitor (GSD) | manquant |
| Claude auto memory | non integre | CE v2.45 l'exploite | manquant |

---

## 1. Gestion du contexte — Ecarts et recommandations

### 1.1 Integration auto memory de Claude (CE v2.45) — PRIORITE HAUTE

**Ecart:** `ce:compound` et `ce:compound-refresh` scannent maintenant le repertoire auto memory de Claude (`~/.claude/projects/<project>/memory/`) comme source supplementaire d'evidence. Le template ne l'exploite pas.

**Impact:** Apres compaction ou sessions longues, l'auto memory preserve des insights perdus par le contexte. Le template ne les exploite ni dans le flywheel ni dans les refresh de docs/solutions/.

**Recommandation:**
1. Mettre a jour le plugin CE (v2.40→v2.46) pour obtenir le comportement natif
2. Ajouter dans `flywheel-workflow.md` etape 1.5 : consulter auto memory comme source supplementaire avant documentation (Phase 2 item #7)
3. Documenter la relation auto memory vs MEMORY.md dans CLAUDE.md.template (section "Fichiers memoire et etat")

**Complexite:** Faible (mise a jour plugin + doc)

---

### 1.2 Context budget precheck (CE v2.39) — PRIORITE MOYENNE

**Ecart:** `ce:compound` inclut desormais un precheck de budget contexte qui avertit quand le contexte est contraint et offre un mode compact-safe.

**Impact:** Sans ce guard, `/ce:compound` peut crasher mid-compaction sur les sessions longues.

**Recommandation:** La mise a jour du plugin (rec. 1.1) apporte ce comportement. Ajouter une mention dans CLAUDE.md.template workflow pour signaler l'existence du mode compact-safe.

---

### 1.3 Threads persistants cross-session (GSD v1.27) — PRIORITE MOYENNE

**Ecart:** `/gsd:thread` offre des knowledge stores legers pour le travail cross-session qui n'appartient a aucune phase specifique. Le template n'a rien d'equivalent.

**Impact:** Le travail d'investigation, de debug, ou de recherche qui s'etale sur plusieurs sessions n'a pas de structure dediee — tout va dans MEMORY.md qui est deja charge.

**Recommandation:**
1. Mettre a jour GSD pour obtenir `/gsd:thread`
2. Ajouter dans CLAUDE.md.template section workflows : "Parcours investigation/debug cross-session: `/gsd:thread`"
3. Documenter la distinction thread vs MEMORY.md (thread = sujet specifique cross-session, MEMORY.md = etat global)

---

### 1.4 Handoff structure machine-readable (GSD v1.26) — PRIORITE MOYENNE

**Ecart:** `/gsd:pause-work` genere maintenant `.planning/HANDOFF.json` (machine-readable) en plus du contexte texte. Le template repose uniquement sur MEMORY.md prose.

**Impact:** Les reprise de session (`/gsd:resume-work`) sont plus fiables avec un artifact JSON structure.

**Recommandation:** Mise a jour GSD. Pas de changement template necessaire — le comportement est natif.

---

### 1.5 Signal WAITING.json (GSD v1.26) — PRIORITE BASSE

**Ecart:** Nouveau fichier signal `.planning/WAITING.json` pour les points de decision qui requierent une intervention utilisateur.

**Impact:** Utile pour les workflows multi-agent ou autonomes.

**Recommandation:** Vient avec la mise a jour GSD. Documenter dans le parcours autonome.

---

### 1.6 Context window monitoring (GSD v1.27) — PRIORITE HAUTE

**Ecart:** GSD v1.27 inclut un context monitor optimise pour les modeles 1M+ tokens, avec un toggle `hooks.context_monitor`. Le template a un hook pre-compact mais pas de monitoring proactif.

**Impact:** Le template detecte la degradation de contexte trop tard (quand Claude repete des questions). Un monitor proactif permet d'agir avant.

**Recommandation:**
1. Mettre a jour GSD
2. Evaluer si le context monitor GSD peut coexister avec le pre-compact.sh existant
3. Si oui, ajouter la config `hooks.context_monitor: true` dans le template settings.json
4. Mettre a jour Regle #3 (sessions longues) dans CLAUDE.md.template pour referencer le monitoring automatique

---

### 1.7 Session report (GSD v1.26) — PRIORITE BASSE

**Ecart:** `/gsd:session-report` genere un rapport de session avec estimation de tokens, resume du travail et resultats.

**Impact:** Utile pour le suivi de consommation et le retrospectives.

**Recommandation:** Vient avec la mise a jour GSD. Ajouter en option dans le workflow "fin de session".

---

## 2. Gestion des taches — Ecarts et recommandations

### 2.1 Fast path pour taches triviales (GSD v1.27) — PRIORITE HAUTE

**Ecart:** `/gsd:fast` execute des taches triviales inline sans subagents ni planning. Le template route tout via le workflow standard (plan→execute).

**Impact:** Overhead inutile pour les typo fixes, config changes, petits refactors. Perte de temps et tokens.

**Recommandation:**
1. Mettre a jour GSD
2. Ajouter un 4eme parcours dans CLAUDE.md.template :
   ```
   ### Parcours immediat — tache triviale
   /gsd:fast "description"
   → closure (MEMORY.md only, pas de SUMMARY.md)
   ```
3. Criteres de routing : tache single-file, < 50 LOC, pas de decision d'approche

---

### 2.2 Auto-advance (GSD v1.26) — PRIORITE HAUTE

**Ecart:** `/gsd:next` detecte l'etat du projet et invoque automatiquement la prochaine etape logique.

**Impact:** Elimine le besoin de savoir quel `/gsd:*` lancer ensuite. Reduit le friction entre les phases.

**Recommandation:**
1. Mettre a jour GSD
2. Mentionner `/gsd:next` comme raccourci dans les 3 parcours existants de CLAUDE.md.template
3. Considerer comme entry point pour les utilisateurs qui ne connaissent pas le workflow GSD

---

### 2.3 Natural language routing (GSD v1.25) — PRIORITE MOYENNE

**Ecart:** `/gsd:do` route du texte libre vers la bonne commande GSD.

**Impact:** Abaisse la barriere d'entree pour les nouveaux utilisateurs du template.

**Recommandation:** Vient avec la mise a jour GSD. Mentionner dans CLAUDE.md.template comme alternative aux parcours explicites.

---

### 2.4 Autonomous mode (GSD v1.27) — PRIORITE MOYENNE

**Ecart:** `/gsd:autonomous` chaine discuss→plan→execute pour toutes les phases restantes. Pause uniquement pour les decisions utilisateur.

**Impact:** Permet des executions multi-phases sans intervention manuelle constante.

**Recommandation:** Vient avec la mise a jour. Ajouter comme 5eme parcours dans CLAUDE.md.template :
```
### Parcours autonome — milestone complet
/gsd:autonomous [--from N]
→ Chaine: discuss→plan→execute pour chaque phase
→ Pause aux decision points
→ closure automatique
```

---

### 2.5 Note capture et seed planting (GSD v1.27) — PRIORITE BASSE

**Ecart:** `/gsd:note` (zero-friction idea capture) et `/gsd:plant-seed` (ideas futures avec trigger conditions) n'ont pas d'equivalent dans le template.

**Impact:** Les idees qui emergent pendant le travail n'ont pas de structure de capture rapide.

**Recommandation:** Viennent avec la mise a jour GSD. Ajouter dans CLAUDE.md.template une section "Capture rapide" :
- `/gsd:note` pour les idees immediates
- `/gsd:plant-seed` pour les idees futures (surfacees par `/gsd:new-milestone`)
- `/lesson` reste pour les patterns appris (pas les idees)

---

### 2.6 Ship command (GSD v1.26) — PRIORITE MOYENNE

**Ecart:** `/gsd:ship` ferme la boucle plan→execute→verify→PR. Le template documente le workflow jusqu'a `/ce:review` mais pas la creation de PR.

**Recommandation:** Ajouter `/gsd:ship` apres `/ce:review` dans les parcours standard et complet.

---

### 2.7 Cross-phase regression gate (GSD v1.26) — PRIORITE HAUTE

**Ecart:** Apres execution d'une phase, GSD v1.26 re-execute les tests des phases precedentes.

**Impact:** Sans ce gate, une phase peut casser du code d'une phase precedente sans detection.

**Recommandation:** Activer dans la config GSD du template. Ajouter un rappel dans `execution-quality.md`.

---

### 2.8 Requirements coverage gate (GSD v1.26) — PRIORITE HAUTE

**Ecart:** `/gsd:plan-phase` verifie maintenant que tous les requirements de la phase sont couverts par au moins un plan.

**Impact:** Empeche l'execution de plans incomplets.

**Recommandation:** Vient avec la mise a jour. Mentionner dans `pre-flight` skill comme gate complementaire.

---

### 2.9 Verification debt tracking (GSD v1.26) — PRIORITE MOYENNE

**Ecart:** 5 ameliorations structurelles pour prevenir la perte silencieuse d'items UAT : health check cross-phase dans progress, status partial, result blocked, HUMAN-UAT.md, warnings de transition.

**Impact:** Les items de verification sont actuellement perdus quand le projet avance.

**Recommandation:** Vient avec la mise a jour. Ajouter `/gsd:audit-uat` dans le parcours post-verification.

---

### 2.10 Stub detection (GSD v1.27) — PRIORITE MOYENNE

**Ecart:** Le verifier et l'executor detectent maintenant les implementations incompletes (stubs, TODOs, placeholder code).

**Recommandation:** Vient avec la mise a jour GSD. Pas de changement template.

---

### 2.11 Resolve-todo-parallel lifecycle (CE v2.45) — PRIORITE BASSE

**Ecart:** Skill reecrit pour gerer le cycle de vie complet des todos (pas juste resolve).

**Recommandation:** Vient avec la mise a jour CE.

---

## 3. Chain of thought — Ecarts et recommandations

### 3.1 Execution posture signaling (CE v2.44) — PRIORITE HAUTE

**Ecart:** `ce:plan-beta` et `ce:work` passent maintenant des signaux d'execution posture (test-first, characterization-first) a travers les plans via `Execution note` par implementation unit.

**Impact:** Actuellement, la Regle #4 (COT) et la Regle #8 (structure plans) ne captent pas l'intention d'execution. L'implementeur n'a aucun signal sur comment aborder chaque unite.

**Recommandation:**
1. Mettre a jour le plugin CE (rec. 1.1)
2. Enrichir Regle #8 dans CLAUDE.md.template pour inclure un champ optionnel `Execution note:` dans les plans
3. Enrichir `execution-quality.md` pour lire les execution notes quand disponibles

---

### 3.2 Plan depth classification (CE v2.44+) — PRIORITE MOYENNE

**Ecart:** `ce:plan-beta` classifie les plans en Lightweight/Standard/Deep selon complexite et risque, et adapte le niveau de detail.

**Impact:** Le template traite tous les plans de la meme facon — Regle #4 a un trigger 2-of-5 mais pas de classification du plan resultant.

**Recommandation:**
1. Ajouter la classification plan depth dans Regle #8 :
   - **Lightweight** : < 2 fichiers, < 50 LOC → plan minimal (AC + files suffisent)
   - **Standard** : 2-5 fichiers, decisions a documenter → plan complet
   - **Deep** : cross-cutting, high-risk → plan + technical design + risk assessment
2. Aligner avec le trigger COT de la Regle #4

---

### 3.3 High-level technical design dans les plans (CE v2.46) — PRIORITE MOYENNE

**Ecart:** Les plans CE peuvent maintenant inclure des pseudo-codes, DSL grammars, ou diagrammes Mermaid comme guidance directionnelle.

**Impact:** Les plans complexes manquent de representation visuelle/structurelle de la solution.

**Recommandation:**
1. Vient avec la mise a jour CE
2. Ajouter dans Regle #8 : "Pour les plans Deep : inclure une section `## Technical Design` optionnelle (pseudo-code, mermaid, ou data flow)"

---

### 3.4 Decision IDs et tracabilite (GSD v1.27) — PRIORITE MOYENNE

**Ecart:** GSD v1.27 ajoute des decision IDs pour la tracabilite discuss→plan.

**Impact:** Le template a DECISIONS.md mais sans lien formel entre decisions et plans. Le session-gate Check 12 verifie la fraicheur mais pas la tracabilite.

**Recommandation:**
1. Vient avec la mise a jour GSD
2. Enrichir Regle #8 : referencer les DEC-NNN dans les plans quand une decision existante s'applique

---

### 3.5 Advisor mode dans discuss-phase (GSD v1.26-1.27) — PRIORITE MOYENNE

**Ecart:** `/gsd:discuss-phase` peut maintenant spawner des agents de recherche paralleles pour evaluer les gray areas avant que l'utilisateur decide. Necessite USER-PROFILE.md.

**Impact:** Les discussions de phase manquent de donnees de recherche pour eclairer les decisions.

**Recommandation:**
1. Vient avec la mise a jour GSD
2. Considerer `/gsd:profile-user` pour generer USER-PROFILE.md (prerequis advisor mode)
3. Mentionner le flag `--analyze` dans le parcours standard

---

### 3.6 Ideation avant brainstorm (CE v2.43+) — PRIORITE BASSE

**Ecart:** `ce:ideate` est un nouveau workflow pre-brainstorm qui genere et filtre des idees d'amelioration fondees sur le codebase.

**Impact:** Le workflow actuel saute directement de "j'ai une idee" a `/ce:brainstorm`. Pas de phase exploratoire structuree.

**Recommandation:**
1. Vient avec la mise a jour CE
2. Ajouter dans le parcours complet : `/ce:ideate → /ce:brainstorm → /ce:plan`
3. Particulierement utile avec l'agent `issue-intelligence-analyst` (analyse des issues GitHub)

---

## 4. Integration MCP / CLI — Ecarts et recommandations

### 4.1 Cross-AI peer review (GSD v1.27) — PRIORITE HAUTE

**Ecart:** `/gsd:review` invoque des CLI externes (Gemini, Claude, Codex) pour review independante des plans. Le template utilise `/ce:review` (agents internes seulement).

**Impact:** Pas de diversity de perspective — tous les reviewers sont des sous-agents Claude.

**Recommandation:**
1. Mettre a jour GSD
2. Ajouter `/gsd:review --all` comme option dans le parcours post-verification
3. Prerequis : au moins un autre CLI installe (Gemini CLI, Codex)
4. Ajouter dans tool-routing.md une section "CLI review routing"

---

### 4.2 Security hardening (GSD v1.27) — PRIORITE HAUTE

**Ecart:** Module centralise `security.cjs` avec prevention path traversal, detection prompt injection, parsing JSON safe, validation noms de champs, validation arguments shell. Hook `gsd-prompt-guard` scanne les ecritures vers `.planning/`.

**Impact:** Les ecritures vers `.planning/` ne sont pas protegees contre les injections de prompt.

**Recommandation:**
1. Vient avec la mise a jour GSD
2. Le hook gsd-prompt-guard s'installe automatiquement
3. Documenter la politique de securite dans le template

---

### 4.3 MCP tool awareness pour subagents (GSD v1.26) — PRIORITE MOYENNE

**Ecart:** Les subagents GSD peuvent maintenant decouvrir et utiliser les outils MCP.

**Impact:** Actuellement, les subagents GSD n'ont pas acces aux MCP configures (Supermemory, Context7, etc.).

**Recommandation:** Vient avec la mise a jour GSD. Pas de changement template.

---

### 4.4 Exa/Firecrawl MCP support (GSD v1.27) — PRIORITE BASSE

**Ecart:** Support pour les MCP de recherche Exa et Firecrawl dans les agents de recherche.

**Recommandation:** Evaluer si ces MCPs ajoutent de la valeur vs WebSearch/WebFetch natifs. Si oui, ajouter dans tool-routing.md et settings.

---

### 4.5 Developer profiling (GSD v1.26) — PRIORITE BASSE

**Ecart:** `/gsd:profile-user` analyse l'historique de session pour construire un profil comportemental sur 8 dimensions. Genere USER-PROFILE.md et CLAUDE.md section.

**Impact:** Personalisation des reponses Claude. Prerequis pour advisor mode.

**Recommandation:** Disponible apres mise a jour GSD. Considerer comme etape de bootstrap du projet (`/project-bootstrap` pourrait proposer le profiling).

---

## Plan d'action revise — Apres deepening

### Phase 0 : Decisions architecturales (AVANT toute implementation)

| # | Decision | Action | Fichier |
|---|----------|--------|---------|
| 0a | Auto memory vs MEMORY.md | Definir contrat de precedence (recommande : MEMORY.md = verite, auto memory = supplementaire read-only) | DECISIONS.md |
| 0b | Context monitor vs pre-compact.sh | Choisir : A (garder pre-compact), B (remplacer par GSD), ou C (layerer) | DECISIONS.md |
| 0c | Rollback tag | `git tag pre-sync-v2.46` | — |

### Phase 1 : Mises a jour upstream + verification

| Action | Commande |
|--------|----------|
| Mettre a jour CE plugin | `bunx @every-env/compound-plugin install compound-engineering` |
| Mettre a jour GSD | `/gsd:update` |
| **Compatibility gate** | Executer `/ce:review`, `/ce:compound`, `/gsd:plan-phase` une fois chacun |
| Verifier versions + breaking changes | Check changelogs |

**Gains passifs (aucun travail template) :** HANDOFF.json (1.4), stub detection (2.10), resolve-todo-parallel (2.11), MCP awareness (4.3), decision IDs (3.4), security hardening (4.2), context budget precheck (1.2)

**Prerequisites infra optionnels (CLI et MCP externes) :**

| Outil | Installation | Benefice | Requis par |
|-------|-------------|----------|------------|
| Codex CLI | `npm install -g @openai/codex` (cle API OpenAI) | Review cross-AI | `/gsd:review --all` |
| Gemini CLI | `npm install -g @anthropic-ai/gemini-cli` (compte Google) | Review cross-AI | `/gsd:review --all` |
| Exa MCP | `claude mcp add exa -s user -e EXA_API_KEY=$EXA_API_KEY -- npx -y exa-mcp-server` | Recherche semantique technique (docs, code) pour agents research | `/gsd:research-phase`, `/gsd:phase-researcher` |

Ces outils sont conditionnels — les workflows fonctionnent sans, mais produisent de meilleurs resultats avec. Documenter leur existence dans README.md section "Optional integrations".

### Phase 2 : Template changes (8 edits cibles)

| # | Action | Fichier | Lignes | Ref |
|---|--------|---------|--------|-----|
| 1 | Ajouter parcours immediat `/gsd:fast` + mentionner `/gsd:next` et `/gsd:ship` dans parcours existants | CLAUDE.md.template | +7 | 2.1, 2.2, 2.6 |
| 2 | Enrichir Rule 4 avec plan depth (Lightweight/Standard/Deep) + execution posture "si present, suivre" | CLAUDE.md.template | +3 | 3.1, 3.2, 3.3 |
| 3 | Ajouter cross-phase regression gate | execution-quality.md | +2 | 2.7 |
| 4 | Mentionner context monitor + auto memory dans Rules #3 et table fichiers | CLAUDE.md.template | +2 | 1.1, 1.6 |
| 5 | Ajouter `/gsd:autonomous` (conditionnel : plan GO + 0 finding HIGH) + `/gsd:review --all` (conditionnel : >3 fichiers OU securite/auth OU CLI dispo) dans parcours | CLAUDE.md.template | +2 | 2.4, 4.1 |
| 6 | Mettre a jour init-project.sh si nouveaux fichiers rules/ | init-project.sh | ~0 | F15 |
| 7 | Ajouter etape 1.5 dans flywheel-workflow.md : consulter auto memory avant documentation | flywheel-workflow.md | +2 | 1.1 |
| 8 | Ajouter section "Optional integrations" dans README.md : CLI externes (Codex, Gemini) + MCP (Exa) avec benefices et installation | README.md | ~10 | 4.1, 4.4 |

**Total : +14 lignes template (~460 CLAUDE.md.template + 2 flywheel) + ~10 lignes README. Pas d'extraction necessaire.**

### Phase 3 : Deferre (implementer quand pain point confirme)

| # | Action | Condition de declenchement |
|---|--------|--------------------------|
| D1 | Threads persistants (1.3) | MEMORY.md prouve insuffisant pour investigations multi-session |
| D2 | Verification debt tracking (2.9) | Items UAT perdus en production |
| D3 | Requirements coverage gate dans pre-flight (2.8) | Plans incomplets detectes post-execution |

### Coupe (ne pas implementer)

| # | Raison |
|---|--------|
| 1.5 WAITING.json | Pas de use case multi-agent dans le template |
| 1.7 Session report | Nice-to-have, le closure protocol suffit |
| 2.3 /gsd:do | Decouvert naturellement, pas besoin de doc template |
| 2.5 Notes/seeds | 4eme systeme de capture = confusion. LESSONS.md + Supermemory suffisent |
| 3.5 Advisor mode | Depend de profiling, complexite disproportionnee |
| 3.6 ce:ideate | 4 etapes pre-execution = over-engineering |
| 4.4 Firecrawl | Exa suffit pour la recherche semantique, Firecrawl redondant |
| 4.5 Developer profiling | Power-user feature, pas template concern |

---

## Risques et mitigations (revise)

| Risque | Severity | Mitigation |
|--------|----------|------------|
| Breaking changes CE v2.40→v2.46 | HIGH | Compatibility gate Phase 1 + tag rollback |
| Context monitor vs pre-compact.sh conflit | HIGH | Decision DEC-B obligatoire avant Phase 2 |
| Auto memory asymetrie hooks | HIGH | Decision DEC-A + contrat "read-only supplementaire" |
| Rule 4+8 over-complication | MEDIUM | Merger plan depth dans Rule 4 (extension du trigger 2-of-5) |
| init-project.sh desynchronise | MEDIUM | Item explicite Phase 2 #6 |
| CARL rule slots proches du max | LOW | Verifier capacite domain template |
| Pas de migration pour projets existants | MEDIUM | Creer guide migration en Phase 3 si besoin |

---

## Metriques de succes

| Objectif | Metrique | Cible |
|----------|---------|-------|
| Contexte | Sessions interrompues par degradation contexte | -50% |
| Taches | Taches triviales via /gsd:fast | < 2 min |
| CoT | Plans Standard+ avec depth classifie | 100% |
| Simplicite | CLAUDE.md.template lignes | < 460 |
| Rollback | Tag pre-sync disponible | Avant Phase 1 |
