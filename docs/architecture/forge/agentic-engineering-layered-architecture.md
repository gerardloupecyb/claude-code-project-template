---
title: "FORGED — Framework for Operational Governed Engineering (Deterministic)"
type: forged-meta-architecture
version: "0.2.0"
date: "2026-04-22"
status: draft
maintained_by: "{{OWNER}}"
{{rag_backend}}_collection: "reference"
{{rag_backend}}_kind: "architecture"
supersedes: "docs/architecture/forge/ (incremental migration, recoverable patterns kept)"
---

# FORGED — Framework for Operational Governed Engineering (Deterministic)

> Successeur de **FORGE** (Framework for Governed Agentic Operations Engineering).
> Le **D** signale que la gouvernance et l'exécution sont **déterministes** par design : pipelines YAML, policies as code, fan-out/fan-in formalisé, evidence signée. Les LLM sont encadrés par des couches déterministes qui valident leurs outputs.
> FORGED remplace progressivement FORGE ; les patterns existants recoupables (`thin-composed-control-plane.md`, `specialized-runtime-plane.md`, `cross-phase-data-plane.md`, `security-architecture.md`, `component-registry.md`) sont hérités et intégrés sous les 5 couches FORGED.
>
> **Cible d'explicabilité :** CISO, audit, legal, DPO, AI officer.
> **Source canonique du modèle en couches.** Distingue explicitement **référentiels**, **stockage**, **gouvernance**, **exécution déterministe**, **agents IA**.
>
> **Frontière dev-plane ↔ ops-plane + carte des 4 modèles d'autonomie/action** : voir [`autonomy-action-boundary-map.md`](autonomy-action-boundary-map.md) (D1.1, fédération documentée, DEC-044). L'expansion FORGED **« (Deterministic) »** ci-dessus est **canonique** ; le « D = Delivery » du brainstorm 2026-05-13 est superseded. Le pipeline SDLC dev-plane (ex-« FORGED-Delivery ») = **Phase 28 « Engineering Execution Baseline » in-repo**, une *implémentation* de l'Execution Layer — pas un framework concurrent, pas un repo `{{project}}-sdlc` séparé.

---

## 1. Principes directeurs

### 1.1 Déterminisme d'abord

- Pipelines d'exécution = **déclaratifs, versionnés, reproductibles** (YAML)
- Policies = **déclaratives** (YAML DSL ou Rego), pas générées par LLM en runtime
- Contract compiler = **fonction pure** (mêmes inputs → mêmes outputs, hash stable)
- Agent outputs = **wrappés par l'orchestrateur** avec validation de schéma + capture d'evidence
- Tout composant non-déterministe (LLM, heuristique) est **encadré par un composant déterministe** qui valide son output

### 1.2 Explicabilité native

Pour chaque décision produite par le système, on doit pouvoir répondre en < 5 min à :

- **CISO** : « Quelles menaces ont été considérées ? Quels contrôles appliqués ? Quel résidu risque ? »
- **Legal / DPO** : « Quelle loi s'applique ? Quelles obligations ? Quelle base légale ? Quel traitement des données personnelles ? »
- **AI Officer** : « Quel modèle a décidé ? Quelle supervision humaine ? Quel risque selon NIST AI RMF / EU AI Act ? »
- **Audit** : « Qui a approuvé quoi, quand, avec quelles preuves ? »

La réponse doit être queryable (Cypher sur le graph) ET immuable (hash + signature sur les EvidenceBundle WORM).

### 1.3 Séparation des rôles

| Rôle | Qui | Peut |
|---|---|---|
| **Référentiels** | Frameworks externes (lois, normes) | Être ingérés comme ontologie, référencés par policies. **NE peuvent pas** décider. |
| **Knowledge Layer** | {{KNOWLEDGE_BACKEND}} + Neo4j + pgvector + {{RAG_BACKEND}} + broker | Stocker, requêter, projeter. **NE peut pas** gouverner. |
| **Control Plane** | Git + policies + compiler + capability model | Définir les règles, compiler les contrats, scoper les grants. **NE peut pas** exécuter. |
| **Engineering Execution Layer** | Harness (ou équivalent) | Orchestrer le SDLC déterministe, appliquer les gates, capturer l'evidence. **NE peut pas** improviser hors pipeline. |
| **Agent Runtime Layer** | Claude Code, Codex, Gemini, {{WORKFLOW_ENGINE}} agents | Exécuter des capacités spécialisées sous contrat. **NE peut pas** se gouverner seul, ni bypass les gates. |

### 1.4 Extractibilité

Chaque couche expose ses artefacts sous forme **structurée et exportable** (JSON, YAML, Cypher result set). Jamais de "savoir enfoui dans un prompt". Jamais de dépendance sur un run interactif pour reproduire une décision.

---

## 2. Les 5 couches

### 2.1 Frameworks Layer (référentiels externes)

**Rôle.** Corpus normatif externe ingéré comme ontologie référentielle. Read-only, versionné par émetteur.

**Contenu.** Lois, règlements, standards, frameworks sectoriels :

| Domaine | Frameworks actuellement ingérés | Phase |
|---|---|---|
| Privacy | {{COMPLIANCE_FRAMEWORK_PRIMARY}} ({{JURISDICTION}}), {{COMPLIANCE_FRAMEWORK_HEALTH}} / {{COMPLIANCE_FRAMEWORK_HEALTH}} (santé QC), {{COMPLIANCE_FRAMEWORK_FEDERAL}} (Canada), GDPR (UE) | 27.1 ({{COMPLIANCE_FRAMEWORK_PRIMARY}} + NIST CSF), 29 (autres) |
| Security | NIST CSF 2.0, OWASP ASVS + Top 10, CIS Controls v8, MITRE ATT&CK | 27.1 (NIST CSF), 29 (autres) |
| AI Governance | NIST AI RMF, EU AI Act, AIDA (Canada, si adopté), ISO/IEC 42001 | 29 |
| General Governance | ISO/IEC 27001, COBIT (optionnel) | 29 |

**Principe clé.** Les frameworks sont **des référentiels**, pas des agents. Ils définissent les obligations ; les policies du Control Plane en dérivent les contraintes exécutables ; les gates du Execution Layer les enforcent.

**Versioning.** Chaque framework a une version source (ex: {{COMPLIANCE_FRAMEWORK_PRIMARY}} dernière modification CAI, NIST CSF 2.0 rev 1) capturée dans la propriété `framework.version` du graph. Un watcher (Phase 24.2 existant) détecte les amendements et propose un re-ingestion.

**Stockage.** Dans le Knowledge Layer, sous nœuds `Framework` → `Obligation` → `maps_to` entre frameworks (crosswalk).

### 2.2 Knowledge Layer (infrastructure de stockage et query)

**Rôle.** Infrastructure runtime qui stocke les référentiels, les projections des specs Git, les compiled contracts, les embeddings, les résultats de query, les evidence metadata. Expose tout via MCP à travers le broker FastAPI.

**Composants (Phase 27) :**

- **{{KNOWLEDGE_BACKEND}}** (orchestrateur ontologique Python)
- **Neo4j Community Edition** (graph store — Cypher queryable)
- **PostgreSQL + pgvector** (vector store — embeddings ontology)
- **{{RAG_BACKEND}}** (legacy, corpus semantic Phase 23, no-sync parallel)
- **FastAPI broker** (gateway — per-agent API keys, authz + query budgets + audit)
- **Tailscale** (network — VPS non public)

**Principe clé.** Ne **gouverne rien**. Ne décide rien. Stocke et retourne des réponses à des queries. La source de vérité canonique reste Git pour les specs / archetypes / policies ; le graph est une **projection** reconstructible.

**Détails.** Voir [`.planning/phases/planned/27-knowledge-layer-infrastructure/27-CONTEXT.md`](../../../.planning/phases/planned/27-knowledge-layer-infrastructure/27-CONTEXT.md) et brainstorm [`docs/brainstorms/linked/knowledge-layer-brainstorm.md`](../../brainstorms/linked/knowledge-layer-brainstorm.md).

### 2.3 Control Plane (gouvernance)

**Rôle.** Définit les règles, compile les contrats, scope les grants, gère les approbations, spécifie le format d'evidence. Étend [`docs/architecture/control-plane.md`](../control-plane.md) existant avec une couche policy-as-code + compiler.

**Composants (Phases 27.1 + 28) :**

- **Git** — source de vérité canonique (specs, archetypes, PolicyRule YAML, exceptions templates, framework version pins)
- **PolicyRule DSL** (YAML déclaratif custom)
- **Capability Model** (scopes RBAC pour agents : tools + file-paths + data classes + time-box)
- **Contract Compiler** (Specification + ComponentArchetype + PolicyRule → EngineeringContract YAML + JSON Schema + cosign signature)
- **ApprovalGate registry** (humain ou automatisé, conditions d'acceptation)
- **EvidenceBundle schema** (JSON Schema strict, cosign signature, {{CLOUD_PROVIDER}} Blob WORM)
- **{{CLOUD_PROVIDER}} Key Vault** (secrets — API keys agents, cosign keys, rotation documentée)

**Principe clé.** **Déterministe, auditable, reviewable en PR.** Toute modification passe par Git + review humaine. Aucune règle n'émerge en runtime sans passer par un commit traçable.

**Explicabilité.** Chaque EngineeringContract compilé liste explicitement :
- Les Obligations référentielles applicables (par framework, par article, par domaine)
- Les Constraints dérivées (auto + authored overrides)
- Les EvidenceRequirements (tests, scans, approvals)
- Le CapabilityGrant associé (tools + paths + data class + expiry)
- Les ApprovalGate requis (qui, combien, signatures)

### 2.4 Engineering Execution Layer (GitHub Actions v1 → Harness future)

**Rôle.** Orchestration déterministe du SDLC. Prend en input un EngineeringContract + du code, applique les pipelines, capture l'evidence à chaque gate, signe les EvidenceBundle. Ne décide pas — exécute ce que le Control Plane a compilé.

**Decision 2026-04-23 (Gemini + Codex review, Scenario D contract-first) :**

| Rôle | Choix {{PROJECT}} |
|---|---|
| **v1 Engineering Execution Layer** | **GitHub Actions** — ingère `evidence-contract-v1` records produits par les phases, bloque PR merge sur records malformés, exécute pytest/SAST/Pester sur les diffs pertinents. Livré en **Phase 28 (Engineering Execution Baseline)**. |
| **Agent Harness PoC candidate** | **Archon** — évalué en Phase 28 pour agent-driven issue triage + plan decomposition. Go/No-Go documenté dans `docs/audits/archon-poc-YYYY-MM-DD.md`. |
| **Issue intake / triage pattern candidate** | **GitHubIssueTriager** — évalué en Phase 28 conjointement avec Archon. |
| **Mature multi-project harness** | **Harness.io** (ou alternative) — **Phase 32**, à réouvrir seulement si GitHub Actions devient structurellement insuffisant (triggers §9 control-plane). Pas avant que Phase 28 + 28.1 soient solides. |

**Alternatives considérées (archive) — tranchées en faveur de GitHub Actions v1 pour ces raisons :**

| Option | Verdict | Raison |
|---|---|---|
| **GitHub Actions** | **RETENU v1** | Intégré au repo, OIDC federation {{CLOUD_PROVIDER}} (pas de PAT long-lived), communauté massive, free tier suffisant pour 1-ETP MSP, OPA ajoutable plus tard pour policies zero-trust (Phase 28.1) |
| **Harness.io** | Reporté Phase 32 | CI/CD + policies + approvals + evidence natifs, mais SaaS propriétaire hors-CA hosting — trop lourd pour v1 1-ETP |
| **Argo Workflows / Tekton** | Rejeté | Besoin de Kubernetes que {{PROJECT}} n'a pas déployé, sur-ingénierie pour 1 ETP |
| **Dagger** | Rejeté | Jeune écosystème, approval/evidence = custom à construire |

**Mapping phases :**

- **Phase 28 (Engineering Execution Baseline)** — GHA workflows + evidence ingestion + Archon PoC + GSD→GHA ownership matrix
- **Phase 28.1 (Zero-Trust Engineering Activation)** — contract compiler + pre-tool-use hook (warn-only) + EvidenceBundle pipeline signé (v2 extends `evidence-contract-v1` backward-compatibly)
- **Phase 32 (Mature Harness)** — contract-aware pipelines, hard enforcement, multi-project template, Harness.io re-évalué

**Composants attendus :**

- **Pipeline declaratif** — YAML versionné, par archetype
- **Gate engine** — plan / design / code / review / test / promote (chaque gate lit le EngineeringContract, vérifie les EvidenceRequirement correspondants, refuse sinon)
- **Policy engine** — OPA/Rego ou Harness OPA-native, applique les PolicyRule compilées
- **Evidence capture** — à chaque step, produit un fragment d'EvidenceBundle signé
- **Approval UX** — humains signent via Teams card / CLI prompt / email signed link (Phase 28.1)
- **Agent invocation** — appelle les agents IA via MCP avec CapabilityGrant scopé

**Principe clé.** **Un changement de production n'arrive pas sans avoir traversé un pipeline Harness.** Le pipeline est l'enforcement runtime du Control Plane. Pas de `kubectl apply` manuel, pas de `git push` vers main qui bypass le pipeline, pas d'exécution ad-hoc de script de déploiement en dehors d'un pipeline.

### 2.5 Agent Runtime Layer

**Rôle.** Capacités spécialisées IA, invoquées par le Engineering Execution Layer sous contrat. Ne gouvernent pas, ne s'auto-invoquent pas, ne bypass pas les gates.

**Composants (existants + à étendre) :**

| Agent | Force | Contexte d'usage |
|---|---|---|
| **Claude Code** (Opus / Sonnet) | Raisonnement nuancé, compliance, sécurité, planning | Plan jobs, design ADRs, compliance review, final audit |
| **Codex CLI** (GPT-5 / o3 famille) | Vélocité implémentation, refactors mécaniques, batch transformations | Implementation jobs, multi-file refactors |
| **Gemini CLI** (2.5 Pro / Flash) | Large context (1M), codebase-wide reasoning | Review cross-module, audits architecturaux, détection d'interactions non-triviales |
| **{{WORKFLOW_ENGINE}} agents** (Claude API) | Orchestration automatisée, hooks background, workflows | Self-enriching graph, watchers, scheduled audits |

**Principe clé.** Chaque agent est **invoqué sous CapabilityGrant** produit par le Control Plane. Le grant définit : quels tools, quels fichiers, quelles DataClass, pour quelle durée. Le pre-tool-use hook côté client (Phase 28.1) ET le broker côté serveur (Phase 27) enforcent le scope.

**Distinction avec [runtime-plane.md](../runtime-plane.md).** Le `runtime-plane.md` existant décrit les runtimes spécialisés d'exécution de workloads applicatifs ({{WORKFLOW_ENGINE}} orchestration, agent-service MASS, scanner-service, {{CLOUD_PROVIDER}} Automation, etc.). Le **Agent Runtime Layer** ici est une sous-classe : les agents IA invocables dans un pipeline d'ingénierie. Un même {{WORKFLOW_ENGINE}} peut être runtime plane (exécution de workflows client) ET Agent Runtime Layer (exécution de workflows d'ingénierie dans Harness).

---

## 3. Les 4 domaines orthogonaux

Pour l'explicabilité, chaque décision est classifiée sur **4 axes distincts**. Une même contrainte peut toucher plusieurs axes ; un même framework peut émettre des obligations sur plusieurs axes.

| Domaine | Question fondamentale | Audit principal | Frameworks types |
|---|---|---|---|
| **Governance** (général) | « Est-ce qu'on suit nos propres règles ? » | Interne / ISO 27001 | ISO 27001, COBIT, CIS Controls |
| **Security** | « Est-ce qu'on est protégé contre les menaces ? » | CISO / pentest | NIST CSF 2.0, OWASP, CIS Controls, MITRE ATT&CK |
| **Privacy** | « Les droits des personnes sont-ils respectés ? » | DPO / CAI | {{COMPLIANCE_FRAMEWORK_PRIMARY}}, {{COMPLIANCE_FRAMEWORK_HEALTH}}, GDPR, {{COMPLIANCE_FRAMEWORK_FEDERAL}} |
| **AI Governance** | « L'IA est-elle utilisée de manière responsable ? » | AI Officer / régulateur | NIST AI RMF, EU AI Act, AIDA, ISO/IEC 42001 |

### 3.1 Règle de classification

Chaque **PolicyRule** dans le Control Plane déclare explicitement dans son frontmatter :

```yaml
policy:
  id: POL-123
  domains: [security, privacy]      # au moins un, souvent plusieurs
  frameworks:                       # référentiels mobilisés
    - name: NIST CSF 2.0
      version: rev-1
      clauses: [PR.AC-01, PR.DS-02]
    - name: {{COMPLIANCE_FRAMEWORK_PRIMARY}}
      version: 2026-01
      articles: [art-10, art-12]
  ...
```

### 3.2 Explicabilité par domaine

Chaque EngineeringContract compilé produit **une vue par domaine** (extraction déterministe depuis le graph) :

```
$ contract-compiler explain CTR-2026-045 --domain privacy
Contract: CTR-2026-045 (WebhookReceiver for Phase 15 billing)
Domain: Privacy

Applicable obligations:
- {{COMPLIANCE_FRAMEWORK_PRIMARY}} art. 10 (minimisation) — DataClass "restricted" limits stored fields
- {{COMPLIANCE_FRAMEWORK_PRIMARY}} art. 17 (residency) — CapabilityGrant forbids egress outside CA
- {{COMPLIANCE_FRAMEWORK_PRIMARY}} art. 3.5 (notification) — EvidenceRequirement: breach detection log present

Constraints derived:
- payload-fields-allowlist: [customer_id, invoice_id, amount_cents, status]
- egress-region: ca-c{{identity_provider}}l-1
- retention: 24 months
- breach-detection-hook: required

Approvals: DPO signoff required if DataClass "restricted" (POL-P-012)
```

Même contrat, même décision, explicable indépendamment à DPO / CISO / AI officer selon le domaine demandé.

### 3.3 Anti-pattern

**Ne jamais mélanger les domaines dans un même PolicyRule sans étiquetage explicite.** Un policy "security + privacy" qui vérifie à la fois auth + PII minimization est acceptable SI les deux domaines sont listés dans le frontmatter. Sinon, le gap d'explicabilité est réel : un DPO qui lit le contrat ne verra pas les contraintes privacy parce qu'elles sont cachées sous une étiquette security.

---

## 4. Flux canoniques (SDLC gouverné)

### 4.1 Flux complet (happy path)

```
┌──────────────────────────────────────────────────────────────────┐
│ 1. PLAN                                                           │
│    Input  : Specification (Git YAML — intent, non-goals, refs)   │
│    Layers : Control Plane (compile) + Knowledge Layer (query)    │
│    Output : EngineeringContract CTR-YYYY-NNN (YAML + JSON Schema │
│             + cosign signature) + CapabilityGrant + ApprovalGate │
│             registry + EvidenceRequirement list                  │
│    Gate   : Plan Gate — contract syntactically valid, every REQ  │
│             mapped to at least one PolicyRule, domain coverage OK│
└─────────────────────────┬────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 2. DESIGN                                                         │
│    Input  : Contract + Archetype relations from Knowledge Layer  │
│    Layers : Agent Runtime (Claude Code) + Execution Layer gate   │
│    Output : Design doc (ADR) + data flow + API contract          │
│    Gate   : Design Gate — Constraints respected (data flow,      │
│             API surface, DataClass) ; EvidenceRequirement for    │
│             design review signed                                  │
└─────────────────────────┬────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 3. CODE                                                           │
│    Input  : Contract + CapabilityGrant + Design ADRs             │
│    Layers : Agent Runtime (Codex CLI / Claude Code) + Execution  │
│             Layer (pre-tool-use hook enforces CapabilityGrant)    │
│    Output : Code commits scoped to grant ; Violation log if any  │
│    Gate   : Code Gate — all Violations resolved or Exception     │
│             documented with expiry ; grant expired = code frozen │
└─────────────────────────┬────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 4. REVIEW                                                         │
│    Input  : Code + Contract + Violation log                      │
│    Layers : Agent Runtime (Gemini CLI for cross-module, Claude   │
│             for compliance) + Execution Layer gate                │
│    Output : Review findings + resolution log                      │
│    Gate   : Review Gate — every EvidenceRequirement of type      │
│             "review" satisfied ; human approvals collected        │
└─────────────────────────┬────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 5. TEST                                                           │
│    Input  : Code + Contract + TestScenario list                  │
│    Layers : Execution Layer (runs tests) + Knowledge Layer       │
│             (TestScenario derivation from Constraint + Risk)      │
│    Output : Test results + SAST/DAST scan artifacts              │
│    Gate   : Test Gate — coverage matches AcceptanceCriterion ;   │
│             no high-severity SAST findings without Exception     │
└─────────────────────────┬────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 6. PROMOTE                                                        │
│    Input  : Contract + complete EvidenceBundle                    │
│    Layers : Execution Layer (pipeline step) + Control Plane      │
│             (/promote skill checks EvidenceBundle completeness)  │
│    Output : Artifact promoted to next env (staging, prod)        │
│             with immutable version pin                            │
│    Gate   : Promote Gate — EvidenceBundle 100% complete ;        │
│             ApprovalGate signed by all required humans ; break-  │
│             glass NOT active                                      │
└─────────────────────────┬────────────────────────────────────────┘
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│ 7. OPERATE                                                        │
│    Input  : Running system + Contract terms                       │
│    Layers : Runtime plane ({{WORKFLOW_ENGINE}} / AA / service) + Knowledge Layer │
│             (Violation detection via drift monitor)               │
│    Output : Operational metrics + Violation events + Learning    │
│             loop candidates                                       │
│    Gate   : Drift Gate — Violation detected → Exception or       │
│             rollback ; learning loop proposes PolicyRule update  │
└──────────────────────────────────────────────────────────────────┘
```

### 4.2 Evidence accumulation

À chaque gate, l'EvidenceBundle associé au contrat s'enrichit d'un fragment signé :

```
CTR-2026-045/evidence/
├─ plan-gate.json.sig            (contract compilation audit)
├─ design-gate.json.sig          (ADR review approval)
├─ code-gate.json.sig            (Violation log + resolution)
├─ review-gate.json.sig          (human approvals + agent findings)
├─ test-gate.json.sig            (test run artifacts + SAST)
├─ promote-gate.json.sig         (promotion checklist + break-glass status)
└─ operate-events/               (drift events + remediations, ongoing)
```

Stockage : {{CLOUD_PROVIDER}} Blob WORM, container `zero-trust-evidence`, retention {{COMPLIANCE_FRAMEWORK_PRIMARY}} art. 10 × DataClass × finalité.

Lecture : per-agent via MCP (FastAPI broker), RBAC, audit trail.

### 4.3 Deviation path (sad path)

Toute étape peut produire une **Violation** ou requérir une **Exception**.

- **Violation** — l'état observé diverge du contrat. Auto-détectée par gate ou monitor.
- **Exception** — dérogation explicite, **expirante**, avec owner, raison, review cadence. Documented dans le Control Plane, référencée dans le EvidenceBundle.

Pas d'exception implicite. Pas d'exception sans expiration. Pas d'exception cumulable indéfiniment (quota par ComponentArchetype + review trimestriel).

---

## 5. Mapping vers les phases {{PROJECT}}

### 5.1 Phases livrant les couches

| Couche | Phase(s) | Livrable principal |
|---|---|---|
| Frameworks Layer — {{COMPLIANCE_FRAMEWORK_PRIMARY}} + NIST CSF 2.0 | Phase 27.1 | Graph populated, crosswalk validé par legal expert |
| Frameworks Layer — {{COMPLIANCE_FRAMEWORK_FEDERAL}} + {{COMPLIANCE_FRAMEWORK_HEALTH}} + NIST AI RMF + EU AI Act + AIDA + ISO 42001 + ISO 27001 + CIS v8 + OWASP | Phase 29 | Graph populated, crosswalks |
| Knowledge Layer (infrastructure) | Phase 27 | {{KNOWLEDGE_BACKEND}} + Neo4j + pgvector + {{RAG_BACKEND}} legacy + broker + Tailscale + KV + audit |
| Control Plane (extension) — zero-trust entities + compiler + PolicyRule DSL + CapabilityGrant + EvidenceBundle schema + hook v1 | Phase 28.1 | Compiler fonctionnel, 1 archetype exécutable (WebhookReceiver) |
| Engineering Execution Layer — Harness (ou équivalent) | Phase 32 (proposed) | Pipelines déclaratifs par archetype, gates actives, evidence capture, agent invocation scopée |
| Agent Runtime Layer — agents existants (Claude Code, Codex, Gemini, {{WORKFLOW_ENGINE}}) | Existant | Utilisés tels quels, enrichis par CapabilityGrant quand Phase 28.1 + Phase 32 livrent |

### 5.2 Phases d'évolution

| Phase | Scope | Status |
|---|---|---|
| 27 | Knowledge Layer Infrastructure | Planned |
| 27.1 | Domain Ontology + {{COMPLIANCE_FRAMEWORK_PRIMARY}} + NIST CSF 2.0 | Planned |
| 28 | Zero-Trust Engineering Foundations (contract compiler + hook v1 + 1 archetype) | Planned |
| 29 | Framework Extension (6 frameworks restants) + 2 archetypes restants + Risk/Hardening | Planned |
| 30 | Execution Gates hard mode (plan/design/code/review/test/promote tous actifs) | Planned |
| 31 | Learning loop + D1b Cloudflare re-eval | Planned |
| **32 (proposed)** | **Engineering Execution Layer — Harness ou équivalent** | **To be created** |

### 5.3 Phase 32 préalables

Pour qu'une phase d'implémentation Harness ait du sens, les préalables suivants doivent être en place :

- Phase 27 / 27.1 / 28 livrées (knowledge + frameworks + contract compiler)
- Phase 29 (ou suffisamment avancée) — assez d'archetypes pour justifier un pipeline
- Un brainstorm dédié `docs/brainstorms/engineering-execution-layer-brainstorm.md` comparant Harness vs alternatives avec critères {{PROJECT}} (CA hosting, déterminisme, coût, lock-in, intégration OPA, integration MCP pour appeler agents)

---

## 6. Contraintes non-négociables

### 6.1 Déterminisme

- Toute décision binaire dans un gate est tranchée par une **fonction pure** (policies + inputs → output reproductible)
- Les LLM ne produisent **jamais** de décision de gate directement — ils produisent des artefacts (code, docs, tests, analyses) qui sont ensuite validés par des gates déterministes
- Les pipelines Harness sont **versionnés** ; un run ancien doit pouvoir être re-exécuté bit-pour-bit avec les mêmes inputs

### 6.2 Explicabilité

- Tout EngineeringContract est re-compilable (reproducibility hash)
- Toute décision de gate est queryable (Cypher sur le graph)
- Toute evidence est immuable (WORM + cosign)
- Toute dérogation est expirante (Exception avec owner + review)

### 6.3 Extractibilité

- Frameworks : exportables en JSON-LD / RDF (réversibilité ontologie)
- Contracts : YAML + JSON Schema (portable, diff-able)
- Evidence bundles : JSON schema + cosign (portable, vérifiable)
- Pipeline definitions : YAML (portable, versionable)

### 6.4 Séparation privacy / security / AI governance

- Chaque PolicyRule déclare ses domaines explicitement
- Chaque EngineeringContract produit une vue par domaine
- Un DPO peut lire le contrat sans bruit security ; un CISO sans bruit privacy ; un AI officer sans bruit governance général

### 6.5 Souveraineté des données

- Frameworks Layer + Knowledge Layer + Control Plane + EvidenceBundle : tout vit au Canada (VPS CA ou {{CLOUD_PROVIDER}} CA). Pas de cross-border sans évaluation {{COMPLIANCE_FRAMEWORK_PRIMARY}} art. 17.
- Les LLM externes (Anthropic, OpenAI, Google) reçoivent du **code et des specs**, jamais des données client sans consentement explicite + DataClass compatible.

---

## 7. Relation avec l'architecture existante

Ce document est une **vue meta** qui structure les architectures existantes en un modèle en couches pour l'ingénierie agentique. Il ne les remplace pas — il les cadre.

| Doc existant | Relation avec ce doc |
|---|---|
| [`docs/architecture/control-plane.md`](../control-plane.md) | Définit le control plane infra {{PROJECT}} (KV, AA, Blob WORM). Ce doc **étend** cette couche avec policies + compiler + capability model (voir §2.3) |
| [`docs/architecture/runtime-plane.md`](../runtime-plane.md) | Définit les runtimes spécialisés d'exécution workload. Ce doc introduit **Agent Runtime Layer** comme sous-classe pour les agents IA dans le SDLC (voir §2.5) |
| [`docs/architecture/product-data-plane.md`](../product-data-plane.md) | Définit où vivent les données métier ({{PRODUCT_DB}}). Ce doc confirme que le graph {{KNOWLEDGE_BACKEND}} + pgvector ne sont **pas** product data plane (voir §2.2) |
| [`docs/architecture/forge/thin-composed-control-plane.md`](thin-composed-control-plane.md) | Pattern FORGE sur control plane composé. Ce doc **applique** ce pattern au Control Plane §2.3 |
| [`docs/architecture/forge/specialized-runtime-plane.md`](specialized-runtime-plane.md) | Pattern FORGE sur runtimes spécialisés. Ce doc **applique** ce pattern au Agent Runtime Layer §2.5 |
| [`docs/architecture/forge/cross-phase-data-plane.md`](cross-phase-data-plane.md) | Pattern FORGE sur data plane cross-phase. Ce doc **complète** avec Knowledge Layer (§2.2) comme plan de stockage distinct |

---

## 8. Open questions

### 8.1 Engineering Execution Layer (Phase 32)

- **Harness vs alternatives** — décision en brainstorm dédié (docs/brainstorms/, à créer)
- **Hosting** — Harness SaaS (hors-CA) vs Harness self-managed (on-prem CA VPS) vs alternatives OSS
- **Agent invocation pattern** — comment Harness appelle Claude Code / Codex / Gemini avec CapabilityGrant scopé ? MCP call? API wrap?
- **OPA integration** — Harness natif OPA ou OPA en sidecar ? Comment partage-t-il les PolicyRule avec le Control Plane ?

### 8.2 Capability Model maturity

- **Granularité des scopes** — tranché en Phase 28.1 : hybride tool + file-path + DataClass + contract-scoped time-box
- **Break-glass procedure** — qui peut invoquer l'exception d'urgence ? Quelle trace ?
- **Multi-tenant si {{PROJECT}} attaque MSP** — scoping par client tenant_id ?

### 8.3 Framework evolution

- **Re-ingestion workflow** — quand un framework est amendé (ex: {{COMPLIANCE_FRAMEWORK_PRIMARY}} amendement CAI), comment le watcher Phase 24.2 propage-t-il dans les Contracts compilés actifs ?
- **Legacy contract validity** — un contrat compilé il y a 6 mois sous framework v1 reste-t-il valide si framework v2 ships ? Grace period ? Re-compile obligatoire ?

### 8.4 Explicabilité runtime

- **Dashboard CISO/DPO/AI-officer** — une UI unifiée qui présente les vues par domaine pour un contrat ou une période ? Phase 30+ ?
- **Reportez compliance** — génération automatique de rapports conformes (ex: rapport CAI, SOC 2) depuis le graph ?

---

## 9. Success metrics (long-term)

Le modèle en couches est un succès si, en exploitation réelle :

1. **Un nouveau développement ne peut pas atteindre production sans passer par le pipeline gouverné** (0 bypass toléré sans Exception documentée)
2. **Un audit CISO / CAI / AI officer peut être répondu en < 1 jour** pour n'importe quel changement des 12 derniers mois
3. **Une modification de framework (ex: {{COMPLIANCE_FRAMEWORK_PRIMARY}} amendement) se propage dans < 30 jours** dans les contrats actifs
4. **Le coût marginal de conformité par feature ajoutée diminue avec le temps** (réutilisation des Constraints, PolicyRule partagées, archetypes matures)
5. **Les agents IA produisent du code qui passe les gates du premier coup ≥ 80% du temps** (signe que les Constraints sont calibrées, pas trop strictes ni trop laxistes)

Ces métriques sont revisitées trimestriellement une fois Phase 32 live.

---

## 9b. Reference Implementation — Security Review Vertical Slice

> Cette section est une **référence concrète** d'un usage FORGED. Elle montre comment une seule préoccupation (security review) s'instancie à travers les 5 couches avec une empreinte minimale, extractible, et sans couplage runtime à l'app.

### 9b.1 Folder structure (extractible, local, propre)

```
my-project/
├─ src/                            # application code (agnostic to FORGED)
├─ tests/
├─ docs/
│  └─ architecture.md              # system architecture
│
├─ security/                       # security reasoning (grouped, standalone)
│  ├─ orchestrator.md              # orchestration prompt (parallel + fan-in pattern)
│  └─ archetypes/                  # agent personas (Control Plane capabilities)
│     ├─ architect.md              # reviews trust boundaries + controls
│     ├─ attacker.md               # STRIDE-like threat scenarios
│     ├─ risk_analyst.md           # likelihood + impact + exposure
│     ├─ data_privacy.md           # {{COMPLIANCE_FRAMEWORK_PRIMARY}} / GDPR reasoning
│     └─ threat_model.md           # correlator, produces final report
│
├─ criteria/                       # Frameworks Layer projection (YAML referentials)
│  ├─ authorization.yaml           # authn/authz constraints
│  ├─ sensitive_data.yaml          # DataClass + minimisation rules
│  ├─ {{compliance_framework_primary}}.yaml                   # {{COMPLIANCE_FRAMEWORK_PRIMARY}} obligations extracted
│  ├─ {{compliance_framework_health}}.yaml                    # {{COMPLIANCE_FRAMEWORK_HEALTH}} {{COMPLIANCE_FRAMEWORK_HEALTH}} obligations
│  └─ gdpr.yaml                    # GDPR obligations (if clients EU)
│
├─ reports/                        # EvidenceBundle output
│  ├─ design-review.json           # early gate evidence
│  ├─ pre-prod-review.json         # pre-promote gate evidence
│  └─ final-review.json            # post-deploy evidence
│
├─ harness/                        # Engineering Execution Layer pipeline steps
│  └─ ai-security-step.yaml        # Harness declarative step that invokes orchestrator
│
└─ README.md
```

**Propriétés invariantes :**

- Tout ce qui raisonne "sécurité" est regroupé sous `security/` — audit simple, reviewable en isolation
- **Zéro dépendance runtime** à `src/` — le raisonnement tourne sans démarrer l'app
- Les référentiels (`criteria/*.yaml`) sont **projetés depuis la Frameworks Layer** ingérée en Phase 27.1, synchronisés par un watcher
- Les archetypes (`security/archetypes/*.md`) sont **authored en Git** — reviewable, versionnable, diff-able
- Les rapports (`reports/*.json`) sont **signés par cosign + stockés en {{CLOUD_PROVIDER}} Blob WORM** (cf §2.3) à la capture — ce qui est committé en Git est un pointeur vers le bundle WORM, pas le payload complet

**Mapping vers les 5 couches :**

| Dossier/fichier | Couche FORGED | Rôle |
|---|---|---|
| `criteria/*.yaml` | Frameworks Layer (projection) | Référentiels normatifs extraits |
| (implicit) {{KNOWLEDGE_BACKEND}} queries | Knowledge Layer | Résolution d'obligations depuis criteria |
| `security/orchestrator.md` + `security/archetypes/*.md` | Control Plane | Capability definitions + orchestration policy |
| `reports/*.json` | Control Plane (schema) + Object storage (payload) | EvidenceBundle (signé, WORM) |
| `harness/ai-security-step.yaml` | Engineering Execution Layer | Pipeline declarative invoking orchestrator |
| Agents invoqués par orchestrator | Agent Runtime Layer | Claude Code / Codex / Gemini remplissant archetypes |

### 9b.2 Orchestrator pattern — parallel analyses + fan-in correlation

L'orchestrateur applique le pattern **déterministe** : fan-out vers archetypes indépendants, fan-in pour corrélation et déduplication. **Aucun archetype ne voit les outputs des autres pendant la phase parallèle** — garantie de pluralité de raisonnement.

**Phase 1 — Parallel Analysis (fan-out) :**

```markdown
## Parallel Analysis Phase

You must now execute the following analyses independently.
Do not reuse reasoning or conclusions between them.

### Analysis A — Threat Modeling (archetype: attacker)
Apply STRIDE-like reasoning to identify threat scenarios.
Output JSON only.

### Analysis B — Risk Analysis (archetype: risk_analyst)
Assess likelihood, impact, exposure based solely on inputs.
Output JSON only.

### Analysis C — Architecture Trust Boundaries (archetype: architect)
Review trust boundaries and control placement.
Output JSON only.

Store results as:
  - threat_model_results
  - risk_analysis_results
  - architecture_results
```

**Phase 2 — Correlation (fan-in) :**

```markdown
## Correlation Phase

You must now correlate:
  - threat_model_results
  - risk_analysis_results
  - architecture_results

Rules:
  - Deduplicate overlapping issues
  - Score impact on a fixed scale (read criteria/*.yaml)
  - Assign priority (P0/P1/P2/P3)
  - Emit findings as structured JSON conforming to reports/*.json schema
  - Refuse to correlate if any analysis is missing or malformed
```

**Propriétés déterministes du pattern :**

- Phase 1 = N appels parallèles indépendants → pluralité garantie
- Phase 2 = **un seul appel** avec inputs structurés → correlation reproductible si mêmes inputs
- Chaque archetype produit **JSON strict** (schema validation côté orchestrateur)
- Refus explicite si inputs malformés → pas de correlation opaque
- Tous les outputs intermédiaires (threat_model_results, etc.) sont signés et joints au EvidenceBundle

### 9b.3 Vue conceptuelle

```
                    ┌────────────────────────────┐
                    │  Inputs pipeline           │
                    │  - IaC (Terraform)         │
                    │  - Manifests K8s           │
                    │  - Code / OpenAPI          │
                    │  - Diagrammes              │
                    └──────────────┬─────────────┘
                                   │
                                   ▼
                    ┌────────────────────────────┐
                    │  AI Orchestrator           │
                    │  (Security Review)         │
                    └──┬──────────┬──────────┬───┘
                       │          │          │
            ┌──────────▼──┐  ┌───▼──────┐  ┌▼──────────┐
            │  Architect  │  │ Attacker │  │  IA Sec   │
            │  archetype  │  │archetype │  │ archetype │
            └──────────┬──┘  └───┬──────┘  └┬──────────┘
                       │          │          │
                       └──────────┼──────────┘
                                  │  (structured JSON outputs)
                                  ▼
                    ┌────────────────────────────┐
                    │  Risk Correlator           │
                    │  - Dup removal             │
                    │  - Impact scoring          │
                    │  - Priority assignment     │
                    └──────────────┬─────────────┘
                                   │
                                   ▼
                    ┌────────────────────────────┐
                    │  Harness Gate              │
                    │  - Pass / Warn / Fail      │
                    │    pipeline                │
                    │  - EvidenceBundle signed   │
                    │  - WORM archived           │
                    └────────────────────────────┘
```

### 9b.4 Harness step (declarative, deterministic)

`harness/ai-security-step.yaml` (extrait) :

```yaml
step:
  type: Plugin
  name: ai-security-review
  identifier: ai_security_review
  spec:
    connectorRef: {{project}}-harness-mcp
    image: {{project}}-forged/security-orchestrator:v1
    settings:
      inputs_dir: <+pipeline.variables.inputs_dir>
      criteria_dir: <+pipeline.variables.criteria_dir>   # criteria/*.yaml
      archetypes_dir: <+pipeline.variables.archetypes_dir> # security/archetypes/
      evidence_bundle_out: <+pipeline.variables.reports_dir>/final-review.json
      fail_on: high   # gate: pipeline fails if any HIGH finding uncovered by Exception
    envVariables:
      {{KNOWLEDGE_BACKEND}}_MCP_URL: <+secrets.getValue("knowledge-layer-mcp-url")>
      {{KNOWLEDGE_BACKEND}}_API_KEY: <+secrets.getValue("knowledge-layer-api-key-harness")>
      COSIGN_KEY: <+secrets.getValue("forged-evidence-signing-key")>
  timeout: 30m
  failureStrategies:
    - onFailure:
        errors: [Timeout]
        action:
          type: Retry
          spec:
            retryCount: 1
            onRetryFailure:
              action:
                type: MarkAsFailure
```

**Propriétés enforcées par Harness :**

- Invocation déclarative (pas de bash ad-hoc dans le pipeline)
- Secrets pullés depuis {{CLOUD_PROVIDER}} Key Vault via connector Harness (pas hardcodé)
- Timeout strict (pas de runaway LLM)
- Failure strategy explicite (retry une fois puis fail-fast, pas de skip silent)
- Gate `fail_on: high` — pipeline fail si findings HIGH non couverts par Exception enregistrée

### 9b.5 Pourquoi ce pattern est "deterministic enough"

- **Orchestrator = prompt Git-versionné** → même prompt produit les mêmes appels
- **Archetypes = prompts Git-versionnés** → même archetype = même "persona" d'analyse
- **Criteria = YAML Git-versionnés** → obligations stables, diffables, auditables
- **Fan-out indépendant** → pluralité garantie, pas de biais de cascade
- **Fan-in = schema strict** → correlator ne peut pas produire de findings sans inputs structurés
- **Evidence signée cosign** → immutable, vérifiable ex post
- **Harness gate = fonction pure** (findings + criteria → pass/warn/fail) → pas de subjectivité runtime

Les LLM sont non-déterministes (température > 0, drift de modèle). FORGED les encadre : inputs déterministes, schemas de sortie stricts, correlation déterministe, evidence signée. Le non-déterminisme est **contenu** dans les fan-out LLM, **pas** dans les décisions de gate.

### 9b.6 Applicabilité à d'autres verticales

Le pattern "orchestrator + archetypes + criteria + reports + harness step" se réplique pour :

| Verticale | Archetypes types | Criteria |
|---|---|---|
| **Privacy Review** | data_privacy, retention_analyst, consent_analyst | {{compliance_framework_primary}}.yaml, {{compliance_framework_health}}.yaml, gdpr.yaml |
| **AI Governance Review** | ai_risk_analyst, model_auditor, bias_reviewer | nist_ai_rmf.yaml, eu_ai_act.yaml, aida.yaml |
| **Compliance Review** | compliance_auditor, evidence_collector | iso27001.yaml, cis_v8.yaml |
| **Architecture Review** | architect, scalability_analyst, reliability_analyst | arc_principles.yaml, reliability_targets.yaml |
| **Pre-Production Review** | meta_orchestrator agrège les 4 précédents | tous les criteria pertinents |

Chaque verticale : même structure de folders, même pattern d'orchestrator, mêmes propriétés déterministes. Un `pre-prod-review.json` final agrège les `*-review.json` verticaux.

---

## 10. Maintenance

Mettre à jour ce doc dans le même commit que :

- Un nouveau framework ajouté au Frameworks Layer (voir §2.1)
- Une nouvelle couche introduite (jamais sans brainstorm + décision documentée)
- Un changement de domaine orthogonal (§3) — ajout d'un 5e axe, fusion de deux axes
- Un changement d'un flux canonique §4 (nouveau gate, suppression d'un gate, reframe)
- Un changement de frontière avec un plan existant (§7)
- Un triggered d'évolution Phase 32 (§5.3)

Adjacent :

- [`.claude/rules/control-plane-gate.md`](../../../.claude/rules/control-plane-gate.md) — règles path-scopées pour le Control Plane
- [`.claude/rules/runtime-plane-gate.md`](../../../.claude/rules/runtime-plane-gate.md) — règles path-scopées pour les runtimes
- [`.claude/rules/data-plane-gate.md`](../../../.claude/rules/data-plane-gate.md) — règles path-scopées pour le data plane
- [`.claude/rules/communication-artifacts-gate.md`](../../../.claude/rules/communication-artifacts-gate.md) — règles pour les artefacts communicationnels

Quand ce doc change, considérer s'il faut une nouvelle règle path-scopée pour le Frameworks Layer, le Knowledge Layer ou le Engineering Execution Layer.
