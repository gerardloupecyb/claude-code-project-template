---
paths:
  - ".task-briefs/**/*.md"
  - "memory/agents-feedback.md"
  - ".claude/rules/router-rules.md"
  - ".claude/rules/swarm-patterns.md"
  - ".claude/skills/prepare-phase/SKILL.md"
  - ".claude/skills/sparc/SKILL.md"
  - "docs/architecture/workflow-architecture.md"
  - "docs/architecture/forge/operating-model.md"
---

# Router Rules

> **Scope:** This file is the canonical source for **cross-vendor handoffs**
> (Anthropic → OpenAI Codex / Google Gemini) via task-briefs, plus domain
> overrides and quality gates for those handoffs.
>
> **Pour les subagents intra-Anthropic** (Opus lead → Sonnet / Haiku workers
> via le Agent tool natif), voir [`swarm-patterns.md`](swarm-patterns.md).
> Les deux fichiers sont complémentaires et couvrent des mécanismes
> distincts — ne pas les confondre.

Claude (Opus) est le context orchestrator. Il décide et synthétise.
Les workers — subagents Anthropic intra-session (swarm-patterns.md) ou
executors externes cross-vendor (ce fichier) — exécutent.

## Classification v1 — ternaire

| Type de tâche | Routing | Mécanisme | Rule canonique |
|---|---|---|---|
| **Décision** — architecture, design, tradeoffs, audit décisionnel, review stratégique, planification, synthèse, arbitrage, ambiguë | **Opus stay** | Exécution directe dans la session principale | *(défaut — pas de règle spécifique)* |
| **Exécution mécanique intra-Anthropic** — scan, inventaire, extraction structurée, transformation data-heavy non-code, rédaction mécanique à partir d'un plan défini, review codebase structurée | **Sonnet subagent** (ou Haiku pour tâches triviales tier 1) | Agent tool avec `model: "sonnet"` / `"haiku"`, pattern hiérarchique, output dans `.claude/workspace/{task-id}-{agent}.md` | [`swarm-patterns.md`](swarm-patterns.md) |
| **Exécution cross-vendor** — code ({{SCRIPTING_LANG}}, Bicep, TypeScript, Python, KQL), scripting, automation, CI/CD, tests, large-context audits {{CLOUD_PROVIDER}}, diff review multi-million tokens | **External executor** | `.task-briefs/{NNN}-{slug}.md` + Codex CLI (OpenAI) / Gemini CLI (Google) / OpenRouter (fallback) | ce fichier |

**Default si ambiguë → Opus stay** — le modèle le plus cher fait la décision
de routing, c'est moins cher qu'une mauvaise délégation.

**Critère de distinction entre "mécanique intra-Anthropic" et "cross-vendor" :**

- Si la tâche est **de la rédaction structurée ou du scan / extraction sur des fichiers existants** (pas de génération de code compilable ou exécutable), → Sonnet subagent.
- Si la tâche est **de la génération de code qui doit compiler / passer des tests / être déployée**, → external executor via task-brief.
- Si la tâche est **un audit large-context** (> 200k tokens de logs, > 50 fichiers à corréler), → Gemini via task-brief même si c'est un "audit" (large-context path — voir Executor Registry ci-dessus).

## Executor Registry

**Principe : Native first, broker second.**

- Pour les **modèles OpenAI**, utiliser **Codex CLI** (GitHub Copilot) par défaut.
- Pour les **modèles non-OpenAI**, utiliser **OpenRouter** — **exception DeepSeek** : endpoint direct officiel (voir ligne DeepSeek ci-dessous), choix opérateur 2026-05-26.
- Utiliser OpenRouter pour les modèles OpenAI uniquement en **fallback** : Codex CLI indisponible, ou workflow GSD autonome (pas d'accès Copilot).

| Model family | Preferred transport | Fallback |
|---|---|---|
| OpenAI (`gpt-5.3-codex`, `o3`, `gpt-4.1-mini`, etc.) | **Codex CLI** | **OpenRouter** — modèle canonique `openai/gpt-5.5` (clé dans le secrets manager — cf. la doc services & accès du projet § OpenRouter) — quand Codex CLI indisponible (quota/auth), Copilot absent, ou GSD autonome. **Voix OpenAI canonique du cross-vendor D-15 quand Codex CLI est down** (cf. `verification-discipline.md` § Cross-vendor) |
| Google Gemini — architecture review | **Gemini CLI** (`gemini-3-pro-preview`) | `gemini-3-flash-preview` (cascade quota) |
| Google Gemini — code/diff review | **Gemini CLI** (`gemini-3-pro-preview`) | `gemini-3-flash-preview` |
| Google Gemini — large context ({{CLOUD_PROVIDER}} audit) | **Gemini CLI** (`gemini-3-pro-preview`) | OpenRouter |
| DeepSeek — **code-gen** ({{SCRIPTING_LANG}}, {{WORKFLOW_ENGINE}}, Bicep, scripts) + review adversariale | **`deepseek-exec.sh`** (endpoint direct `api.deepseek.com/anthropic`, `deepseek-v4-pro`) | Opus reprend si executor indisponible |

**DeepSeek executor (2026-05-26)** — routing à trois tiers qui referme la Classification v1 :
- **Opus** (session) : décision, orchestration, one-liners, retouches texte triviales, review du code écrit par DeepSeek.
- **Sonnet** (subagent intra-Anthropic) : écriture de **texte** (docs, SUMMARY, prose, rédaction structurée).
- **DeepSeek** (`~/.claude/scripts/deepseek-exec.sh`, headless, endpoint direct) : écriture de **code** / exécution substantielle.
- **Exclusion confidentialité** : logique sensible à valeur de reconnaissance (rôles GDAP exacts, design break-glass, scoping SP) reste Anthropic/Codex — pas DeepSeek.
- **Review** : DeepSeek = 3ᵉ voix adversariale (`{{project}}-review` Step 6.5), **règle auteur ≠ reviewer** (s'il a écrit le diff, il ne le review pas). Détails + accès : memory `reference_deepseek_executor.md`, la doc services & accès du projet § DeepSeek executor, `.claude/integrations.md`.

## Handoff — ce que Claude fait pour chaque tâche "external"

0. **Lire `memory/agents-feedback.md` § Codex CLI (ou § Gemini CLI selon le transport)** — appliquer les mitigations connues upfront au brief (enumération explicite in-scope/out-of-scope, literal vs semantic ACs, Codex Observations section obligatoire). Ne pas redécouvrir les incidents passés à la vérification.
1. Collecter le contexte pertinent depuis la doc codebase du projet (L1-L3 selon la tâche)
2. Extraire les snippets de code pertinents (pas les fichiers entiers)
3. Écrire `.task-briefs/{NNN}-{slug}.md` avec frontmatter (status + target_model) — **enumérer explicitement Files to CREATE, Files to EDIT, et Out of Scope**
4. Self-check : "Le brief contient-il tout pour que l'executor produise du code qui compile et passe les AC sans lire d'autres fichiers ?"
5. Afficher : `→ Codex VS Code : "lis .task-briefs/{NNN}-{slug}.md et exécute"`

## Return Signal Protocol

Quand l'executor a fini :
1. User tape dans Claude Code : `Codex done {slug}` (ex: `Codex done 002`)
2. Claude exécute :
   - `git diff` pour voir les changements
   - `git status` + bucket par mtime (avant/après handoff) pour isoler la drift ambiante de la delta Codex
   - Vérifie chaque AC du brief — re-run les commandes live, ne jamais accepter les claims self-reported de Codex (voir `memory/agents-feedback.md` § Codex CLI § "Codex done verification must be re-run locally")
   - Met à jour `status` dans le frontmatter
   - Si PASS → next task. Si FAIL → retry protocol.
3. **Si une déviation notable est observée** (false positive, scope creep, AC ambiguïté, output format surprise) : ajouter une entrée à `memory/agents-feedback.md` § Codex CLI avec le template en bas du fichier. Rule name + Why (incident + brief ID) + How to apply. Les entrées compound.

## Failure & Retry Protocol

```
Claude review (git diff + AC check)
  ├── PASS → status: reviewed → next task
  └── FAIL → attempt += 1
        ├── attempt ≤ 2
        │   → Écrire corrections dans le brief
        │   → status: pending (retry)
        │   → "lis .task-briefs/{slug}.md et corrige"
        └── attempt > 2
            → status: rejected
            → Claude exécute la tâche lui-même (Opus)
            → Log: "Escalated: [raison]"
```

Jamais plus de 2 retries. Si l'executor ne peut pas, le contexte est insuffisant — Opus reprend.

## Sources de contexte pour les briefs

Le task-router consulte l'index de références du projet :
- **Tâche archi/security** → extraire de la doc architecture & sécurité (niveau L1)
- **Tâche code** → extraire de la doc patterns de code (L2) + contexte codebase (L3)
- **Tâche infra** → extraire de la doc services & accès (L3)

