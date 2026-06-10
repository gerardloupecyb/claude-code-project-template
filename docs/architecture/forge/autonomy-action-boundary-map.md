---
title: "Autonomy & Action — Boundary Map (D1.1 / D1 fédération documentée)"
status: RESOLVED 2026-06-02 — FORGED « (Deterministic) » + Phase 28 in-repo (DEC-044)
origin: docs/brainstorms/2026-06-02-forged-autonomy-and-action-model-brainstorm.md § D1/D1.1
purpose: Résout les deux coherence bugs nommés (collision de nommage FORGED + frontière repo {{project}}-sdlc↔Phase 28) et cartographie les 4 modèles d'autonomie/action — « quel modèle gouverne quoi ». Fédération documentée, PAS unification (lean 1 ETP).
review: D1.1 = pré-condition à tout import d'objet de gouvernance externe (cross-vendor verdict 2026-06-02, .claude/workspace/2026-06-02-ecc-adoption-analysis.md § Cross-vendor)
---

# Autonomy & Action — Boundary Map

> **Ce que ce doc fait** : il ne fusionne pas les 4 modèles (ce serait l'unification D1(b), lourde, V2+). Il pose **une carte de frontières** + aligne le **vocabulaire commun**, pour que les imports futurs (ECC ou autre) atterrissent dans le bon modèle sans créer de doublon sans owner.
> **Ce que ce doc NE fait PAS** : il ne rouvre pas 2026-05-13 (pipeline dev-plane) ni Phase 37 (enveloppe unattended) ni l'ActionArchetype (27.5). Il les prend comme acquis et règle leurs jointures + nommage.

---

## Décision 1 — Collision de nommage FORGED  ·  RESOLVED 2026-06-02 (DEC-044)

**Le bug (réel, présent) :** deux expansions canoniques coexistent.

| Source | Expansion | Autorité |
|---|---|---|
| `docs/architecture/forge/agentic-engineering-layered-architecture.md` (titre) | Framework for Operational Governed Engineering **(Deterministic)** | Doc d'architecture, {{RAG_BACKEND}}-indexé = source of truth |
| `docs/brainstorms/2026-05-13-{{project}}-forged-agentic-sdlc` (K2, « D = Delivery ») | Framework for Governed Agentic Engineering **Delivery** | Brainstorm (autorité inférieure) |

**Résolution (confirmée 2026-06-02, DEC-044) :** **FORGED = « Framework for Operational Governed Engineering (Deterministic) »** (le doc d'architecture gagne par précédence de source-of-truth).

- Le `(Deterministic)` est la **propriété architecturale portante** — les gates FORGED sont déterministes, jamais LLM-judge. Ça vient d'être **re-confirmé comme invariant** par la cross-vendor review du 2026-06-02 (« deterministic graders, never LLM-judge as a gate »). Garder « Deterministic » verrouille ce principe dans le nom même.
- Le « Delivery » de 2026-05-13 décrivait le **pipeline de livraison dev-plane** — c'est une **implémentation** de l'Execution Layer de FORGED (= Phase 28), **pas** une redéfinition du framework.
- **Conséquence nommage :** on **abandonne « FORGED-Delivery »** comme nom de framework concurrent. Le pipeline SDLC dev-plane s'appelle **« FORGED dev-plane delivery »** (descriptif), livré canoniquement comme **Phase 28 « Engineering Execution Baseline »** (in-repo).

> **Confirmé 2026-06-02 :** « Deterministic » retenu. Le « D = Delivery » de 2026-05-13 (K2) est **superseded** pour le nommage (DEC-044).

---

## Décision 2 — Frontière repo `{{project}}-sdlc` ↔ Phase 28  ·  RESOLVED 2026-06-02 (DEC-044)

**Le bug (double overload, plus large que le brainstorm ne le notait) :** `{{project}}-sdlc` désigne **deux choses différentes** qui partagent un nom.

1. Un **repo git séparé** *proposé mais jamais créé* (2026-05-13, « à créer après sign-off », explicitement une `[User decision]` ouverte). Chevauche **Phase 28 in-repo** (« Engineering Execution Baseline », canonique).
2. Un **namespace de données scope_guard/{{KNOWLEDGE_BACKEND}} déjà live** : `{{project}}-sdlc:*` (source-URI allowlist, `runtime-plane.md` D-04), `{{project}}-sdlc-lessons`, `{{project}}-sdlc-decisions` (scope-guard-dataset-allowlist), `{{project}}:dataclass-instance/{{project}}-sdlc/...` (ontology-standards). **En production.**

**Résolution (confirmée 2026-06-02, DEC-044) :**

- **PAS de repo git `{{project}}-sdlc` séparé maintenant.** Le dev-plane SDLC se construit **dans ce repo, comme Phase 28** (« Engineering Execution Baseline », déjà canonique avec CONTEXT.md autoritatif) + Phase 28.1 (« Zero-Trust Engineering Activation »).
- Un repo séparé productisable = décision **V2 / productisation**, que **K12 (2026-05-13)**, la **cross-vendor review (anti-« architecture astronautics »)** et `customer-discovery-discipline.md` disent tous de **différer**.
- **`{{project}}-sdlc` reste strictement le namespace de données** scope_guard/{{KNOWLEDGE_BACKEND}} (sens #2). Si un repo séparé est créé un jour (V2), il prendra un **nom différent** pour ne pas collisionner avec ce namespace live.

> Cette résolution règle **les deux** problèmes d'un coup : le chevauchement de scope (repo vs Phase 28) **et** l'overload de nom (repo vs namespace de données).

---

## La carte des 4 modèles — « quel modèle gouverne quoi »

| # | Modèle | Plane gouverné | Unité gouvernée | Sûreté | Statut |
|---|---|---|---|---|---|
| **M1** | **FORGED-arch** (vocabulaire 5-couches) | dev (méta) | `EngineeringContract` (code) | déterminisme, `EvidenceBundle` WORM, gates 7-étapes | vocabulaire + `evidence-contract-v1.schema.json` shipped ; Execution Layer non bâti |
| **M2** | **FORGED dev-plane delivery** (= Phase 28/28.1 in-repo, ex-« FORGED-Delivery ») | dev | feature → PR | 2 gates humains, runner GHA éphémère, context-pack ingress | brainstorm 2026-05-13 ; Gate 0 pré-pilote à courir. **Implémentation de l'Execution Layer de M1.** |
| **M3** | **execute-phase-auto + Phase 37** | dev → staging | exécution d'**une phase GSD** | invariant **danger one-way**, enveloppe isolée, kill-gate | Tranche 1 plan-ready ; Tranche 2 deferred (isolation non prouvée) |
| **M4** | **Cascade MSP** (WhatIf/Apply) | **ops (prod réelle, tenants clients)** | **action sur tenant client** | dry-run→apply, skill-gate, `pre-mcp-gate`, `/promote` | **en prod, hors vocabulaire FORGED** |

**Frontière des planes :**
- **Dev-plane** (code/specs/ADRs, jamais de données métier — invariant data-sovereignty) : gouverné par **M1** (primitives) + **M2** (pipeline de livraison) + **M3** (exécution par phase).
- **Ops-plane** (prod réelle, tenants/personnes) : gouverné par **M4** (cascade) aujourd'hui ; le net-new **ActionArchetype (candidate Phase 27.5)** *généralise M4* sous gouvernance unifiée. **M4 est le modèle d'action réutilisable** — c'est lui qu'on étend, pas M1.

**Règle de non-débordement :** un objet conçu pour un plane n'autorise jamais une action dans l'autre. M1/M2/M3 (dev) ne peuvent pas muter un tenant ; M4 (ops) ne passe pas par les gates dev-plane mais par skill-gate + `pre-mcp-gate` + `/promote`. {{COMPLIANCE_FRAMEWORK_PRIMARY}} art 12.1 (décision automatisée sur une personne) **ne mord que l'ops-plane** (M4 / 27.5), jamais le dev-plane.

---

## Vocabulaire commun — primitives partagées (alignement, pas fusion)

Trois primitives FORGED sont **transverses** aux 4 modèles et doivent garder **une seule définition** :

| Primitive | Définition unique | Usage par modèle |
|---|---|---|
| `DataClass` | classification d'une donnée (public / internal / restricted-PHI…) qui drive ingress/egress | M1 type ; M2/M3 ingress sanitization ; M4 egress gate (D4.2) |
| `EvidenceBundle` | enveloppe d'evidence signée + durable (WORM) produite par un gate | M1 vocab + `evidence-contract-v1.schema.json` ; M2 par-gate ; M3 par-phase ; M4 par-action (forme à définir, 27.5) |
| `CapabilityGrant` | grant scopé (tools+paths+DataClass+time-box) | M1 vocab ; M3 enveloppe Phase 37 ; **M4/27.5 = extension action-aware** (`target_scope`/`reversibility`/`blast_radius`/`approval_class`/`idempotency`, brainstorm D2) |

L'extension action-aware du `CapabilityGrant` (D2) est le **seul net-new de vocabulaire** ; tout le reste est de l'alignement.

---

## Ce que ce doc ne tranche PAS (différé)

- **D1 niveau d'ambition** (fédération documentée vs unification sous FORGED) : ce doc **EST** la fédération documentée (lean). L'unification (rétrofit M2/M3/M4 sous EngineeringContract) reste V2+.
- **D2/D3/D5** (schéma exact ActionArchetype, pont cascade↔FORGED, échelle L0→L4) : déférés au planning de la phase 27.5 candidate.
- **D4.x** (gardes intelligence-layer) : déférés ; voir l'analyse ECC (`.claude/workspace/2026-06-02-ecc-adoption-analysis.md`) pour le séquencement.
- **Création éventuelle d'un repo séparé** (V2/productisation) : hors scope, hors `customer-discovery-discipline`.

---

## Suite (2 décisions confirmées 2026-06-02, DEC-044)

1. ✅ Note ajoutée dans `agentic-engineering-layered-architecture.md` (pointe vers cette carte + verrouille « Deterministic »).
2. ✅ `DECISIONS.md` DEC-044 : FORGED « (Deterministic) » ; pas de repo {{project}}-sdlc séparé ; {{project}}-sdlc = namespace données uniquement.
3. Backlink `linked_phase` depuis le brainstorm 2026-06-02 quand 27.5 est créée.
4. (Optionnel) cross-vendor pass si la carte acquiert des « teeth » (contrats enforcés) — pour l'instant elle est descriptive.
