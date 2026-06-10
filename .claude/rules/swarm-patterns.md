---
paths:
  - ".claude/rules/swarm-patterns.md"
  - ".claude/rules/router-rules.md"
  - ".claude/skills/prepare-phase/SKILL.md"
  - ".claude/skills/sparc/SKILL.md"
  - "docs/architecture/workflow-architecture.md"
  - "docs/architecture/forge/operating-model.md"
---

# Swarm Patterns — Multi-Agent Conventions

> **Scope:** Intra-Anthropic subagent orchestration — Opus lead dirige des
> workers Sonnet / Haiku via le Agent tool natif Claude Code. Single source
> of truth pour les rôles, la topologie, et le model routing tier.
>
> **Pour les handoffs cross-vendor** (Claude → OpenAI Codex / Google Gemini),
> voir [`router-rules.md`](router-rules.md). Les deux fichiers sont
> complémentaires et couvrent des mécanismes distincts — ne pas les confondre.
>
> Ce fichier est référencé par SPARC, pre-flight, prepare-phase et tout skill
> d'orchestration multi-agents.

## Agent Roles

| Rôle | Responsabilité | Model tier | Biais |
|------|---------------|------------|-------|
| `architect` | Design système, APIs, boundaries | Opus (tier 3) | Propose la meilleure solution |
| `critic` | Challenge, edge cases, over-engineering | Opus (tier 3) | Cherche activement les problèmes |
| `coder` | Implémentation, TDD | Sonnet (tier 2) | Best practices |
| `reviewer` | Code review structurée | Sonnet/Opus | Qualité + sécurité |
| `tester` | Tests, edge cases, couverture | Sonnet (tier 2) | Couverture exhaustive |
| `security-auditor` | OWASP, auth, data exposure | Sonnet/Opus | Paranoid |
| `spec-writer` | Requirements, AC mesurables | Sonnet (tier 2) | Clarté + traçabilité |
| `logic-planner` | Pseudocode, logique, TDD anchors | Sonnet (tier 2) | Structure |
| `researcher` | Scan, inventaire, extraction structurée, mapping codebase, rédaction mécanique à partir d'un plan défini | Sonnet (tier 2) | Exhaustivité + structure, pas de décision |

## When to use team agents (parallel researchers)

Le pattern hiérarchique (Pattern 1) accepte **un seul agent ou une équipe**.
Utiliser une équipe de plusieurs researchers en parallèle quand :

1. **Les chemins à explorer sont naturellement parallélisables** — domaines
   indépendants avec des formats de fichiers différents (ex: `.claude/rules/`
   markdown vs `.github/workflows/` yaml vs `scripts/` shell).
2. **Le volume total est grand** — un seul agent ferait trop de tool calls
   et risquerait le context overflow.
3. **La spécialisation par format / domaine améliore la qualité** — un
   agent qui n'a qu'un type de fichier à parser produit un meilleur output
   qu'un agent qui jongle avec tout.
4. **Le travail est additif** — chaque agent produit une partition du
   résultat final que le lead consolide par concaténation + dédoublonnage.

Ne pas utiliser une équipe quand :

- La tâche est séquentielle par nature (chaque étape dépend de la précédente)
- Le scope est petit (< 20 fichiers) — l'overhead d'orchestration dépasse le gain
- Les résultats dépendent d'un contexte partagé que chaque agent devrait
  reconstruire individuellement (coût duplication contexte)

**Max team size : 3-5 researchers en parallèle pour une tâche d'inventaire
ou de mapping. Au-delà, le coût de consolidation par le lead explose.**

## Topology and Anti-Drift

**Pattern 1 — Hierarchical**: Claude principal = lead, subagents = workers.
Lead reads outputs and synthesizes. Workers NEVER call each other (context flooding).

**Pattern 2 — Anti-drift**:
- **Before spawning** any subagent or team: read `memory/agents-feedback.md` § "Intra-Anthropic subagents" or § "Multi-agent teams" for known failure modes. Apply mitigations upfront in the agent prompt.
- Always pass full context in each agent prompt (subagents don't read parent context)
- Checkpoint after each agent: read output before spawning next
- Agent returns < 3 lines or "unable to proceed" → stop chain, diagnose
- Include {{RAG_BACKEND}} grounding context: which facts must the subagent verify via {{RAG_BACKEND}}? (collection + kind filter)
- **After the run**, if a subagent or team deviated from expectations (false positive, scope drift, weak output, context loss): add a new entry to `memory/agents-feedback.md` in the relevant section using the template at the bottom of the file.

**Pattern 3 — Shared namespace**:
- No magic shared memory between subagents
- Convention: write outputs to `.claude/workspace/{task-id}-{agent}.md`
- Subsequent agents read those files explicitly

**Pattern 4 — Knowledge Grounding ({{RAG_BACKEND}})**:
- Before making claims about architecture, patterns, services, or past decisions, query the relevant {{RAG_BACKEND}} collection via `chroma_query_documents`
- Collection routing: see `.claude/skills/knowledge-grounding/SKILL.md` for domain-to-collection table
- Session-start hook injects collection names into additionalContext — pass these to subagent context
- Always include `where` clause with `kind` filter (D-B7) — do not rely on semantic search alone
- Queries are stateless — no conversation isolation needed (simpler than NotebookLM)
- If {{RAG_BACKEND}} unavailable: fallback to direct file reads (non-blocking)
- Honest framing: {{RAG_BACKEND}} provides grounded retrieval, not guaranteed truth — always verify critical claims against source files

## Model Routing

| Tier | Model | When | Examples |
|------|-------|------|---------|
| 1 | Haiku | Simple task < 30% complexity | Search, formatting, grep, rename |
| 2 | Sonnet | Standard implementation (default) | Feature, bugfix, refactor, tests |
| 3 | Opus | Escalation: arbitration, security, costly decisions | Critical design, contradictions, bounded contexts |

**SPARC routing by phase:**

| Phase | Agent | Model |
|-------|-------|-------|
| 1 Spec | spec-writer | Sonnet |
| 2 Pseudo | logic-planner | Sonnet |
| 3 Arch | architect + critic | Opus |
| 4 Refine | implementation | Sonnet |
| 5 Complete — standard | reviewer | Sonnet |
| 5 Complete — security/contradiction | reviewer + critic | Opus |

Escalate to Opus when: auth/security, bounded contexts, architect↔critic contradiction unresolved,
2nd NO-GO on same task, decision costly to reverse (schema, API contract, data model).

## Implementer Status Contract

Convention de sortie pour les subagents intra-Anthropic. Le subagent place un status header **en première ligne** de son output (ou du fichier produit) :

| Status | Sens | Action du lead |
|--------|------|----------------|
| `DONE` | Travail terminé | Lire l'output, vérifier avant de continuer |
| `DONE_WITH_CONCERNS` | Terminé mais doutes flaggés | Lire les concerns avant de passer à l'étape suivante |
| `BLOCKED` | Ne peut pas continuer | Diagnostiquer : (1) contexte insuffisant → fournir + re-dispatch, (2) tâche trop complexe → escalader model tier, (3) tâche trop grande → découper, (4) plan incorrect → escalader humain |

**Règle critique :** Le status header ne remplace pas la lecture de l'output. `DONE` est une indication, pas une preuve — l'Iron Law de `verification-discipline.md` s'applique toujours. Ne jamais forcer un re-dispatch sans changer quelque chose (contexte, model tier, ou découpage).

**Scope :** Subagents intra-Anthropic uniquement (Agent tool). Pour les executors cross-vendor (Codex, Gemini), le protocole de `router-rules.md` § "Failure & Retry Protocol" prend précédence.

## Limits

- Max simultaneous agents: 6-8 standard, 12 complex systems
- Each agent returns < 200 words summary (unless file output requested)
- Never spawn an agent without verifying the previous succeeded (except explicit parallel)
