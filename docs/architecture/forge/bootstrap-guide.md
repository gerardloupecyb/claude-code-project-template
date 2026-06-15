---
title: "FORGE — Bootstrap Guide"
status: active
last_verified: 2026-04-12
owner: {{OWNER}}
phase: 24
slug: forge
---

# FORGE — Bootstrap Guide

> Comment adopter FORGE dans un nouveau projet.
> Suivre les etapes dans l'ordre. Chaque tier est autonome — arreter au tier desire.

---

## Scope honnête (D-10)

Ce template est **dé-identifié** (l'identité du projet source est retirée — noms, comptes,
hôtes, vendeurs tokenisés en `{{PLACEHOLDER}}`) et **sans gate de stack hardcodé** (les
domaines protégés ne sont pas pré-câblés : `protected_domains` / `gated_mcp` arrivent vides,
remplis par projet via le questionnaire de déploiement).

Il n'est **PAS** « stack-neutre » au sens magique du terme. Le modèle opérationnel reste
celui de FORGE : **FORGE + GSD + {{RAG_BACKEND}} (RAG) + CARL**. Adopter ce template, c'est adopter
ce modèle opérationnel — pas un squelette agnostique qui marcherait identiquement sur
n'importe quelle stack. Les exemples de stack (cloud / workflow engine / CRM…) sont
tokenisés, mais la **forme** du système (mémoire persistante, knowledge RAG, discipline de
phases, gates de domaine) est ce que vous adoptez.

> ⚠️ Ne pas lire ce guide comme « FORGE marche pour n'importe quelle stack ». Il marche pour
> un projet qui **adopte le modèle opérationnel FORGE** et y instancie sa propre stack.

---

## Prerequis

- Claude Code installe (`claude` CLI)
- Git repo initialise
- GSD installe (`~/.claude/get-shit-done/`)

---

## Tier 1 — Foundation (~2h)

### Step 1 — Clone le template

```bash
# Depuis le repo template (pas depuis {{PROJECT}})
git clone {forge-template-repo} /tmp/forge-template
```

### Step 2 — Copier les fichiers foundation

```bash
PROJECT="{your-project-path}"

# Rules (copier tel quel)
cp /tmp/forge-template/.claude/rules/verification-discipline.md "$PROJECT/.claude/rules/"
cp /tmp/forge-template/.claude/rules/cognitive-patterns.md "$PROJECT/.claude/rules/"
# tool-routing.md : NON fourni par le template (project-specific jusqu'a la genericization Phase 22.1).
# Redigez le votre — caps / pagination / filtres / anti-patterns MCP de VOTRE stack.
cp /tmp/forge-template/.claude/rules/workflow-guide.md "$PROJECT/.claude/rules/"
cp /tmp/forge-template/.claude/rules/todo-discipline.md "$PROJECT/.claude/rules/"
cp /tmp/forge-template/.claude/rules/phase-lifecycle.md "$PROJECT/.claude/rules/"

# Hooks
cp /tmp/forge-template/.claude/hooks/session-start.sh "$PROJECT/.claude/hooks/"
cp /tmp/forge-template/.claude/hooks/memory-retention.sh "$PROJECT/.claude/hooks/"

# Skills
cp -r /tmp/forge-template/.claude/skills/todo "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/lesson "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/commit-push "$PROJECT/.claude/skills/"

# Memory structure
mkdir -p "$PROJECT/memory"
echo "# MEMORY.md — {Project Name}\n\n> Session journal.\n\n---\n\n## Etat du projet\n\n**Statut :** [ ] En demarrage  [ ] En cours  [ ] Bloque  [ ] Termine\n**Derniere session :** {date}\n**Prochaine etape :** {a definir}" > "$PROJECT/memory/MEMORY.md"
touch "$PROJECT/LESSONS.md"
touch "$PROJECT/DECISIONS.md"
```

### Step 3 — CLAUDE.md bootstrap

Creer `CLAUDE.md` (< 50 lignes) :

```markdown
# {Project Name}

## Style d'execution
Claude travaille comme un operateur senior : direct, pragmatique, rigoureux.

## Chargement minimal
Toujours lire : AGENTS.md, memory/MEMORY.md
Avant implementation : LESSONS.md
Avant decision architecture : DECISIONS.md

## Fin de session
Mettre a jour memory/MEMORY.md (fait/decisions/prochaine etape/blocages).
```

### Step 4 — CARL domain

```bash
mkdir -p "$PROJECT/.carl"
cat > "$PROJECT/.carl/{project-name}" << 'EOF'
# CARL Domain: {Project Name}
RULE_0="These rules apply to {project-name}. All CARL rules MUST be written in English."
RULE_1="CONSULT BEFORE IMPLEMENTING: Check docs/solutions/ for existing patterns before writing new code."
RULE_2="DOCUMENT AFTER SOLVING: Document patterns in docs/solutions/ after resolving non-trivial problems."
RULE_3="CREDENTIALS SAFETY: All API credentials in .env files, never hardcoded."
EOF
```

### Step 5 — Valider

```bash
# Ouvrir Claude Code dans le projet
cd "$PROJECT" && claude
# Session-start hook doit s'executer, MEMORY.md doit etre injecte
```

**Tier 1 complet.** Le projet a : memory persistante, verification discipline, tool routing, todo tracking, lesson capture, closure protocol.

---

## Tier 2 — Governance (+4h)

### Step 6 — Ajouter les gates

```bash
# Rules
# governance.md : NON fourni par le template (project-specific jusqu'a la genericization Phase 22.1).
# Redigez le votre — obligations de co-update + table d'enforcement de VOTRE projet.
cp /tmp/forge-template/.claude/rules/skill-gate.md "$PROJECT/.claude/rules/"
cp /tmp/forge-template/.claude/rules/supply-chain-audit.md "$PROJECT/.claude/rules/"
cp /tmp/forge-template/.claude/rules/dependency-surveillance.md "$PROJECT/.claude/rules/"
cp /tmp/forge-template/.claude/rules/protected-files.yaml "$PROJECT/.claude/rules/"

# Hooks
cp /tmp/forge-template/.claude/hooks/pre-tool-use.sh "$PROJECT/.claude/hooks/"
cp /tmp/forge-template/.claude/hooks/pre-mcp-gate.sh "$PROJECT/.claude/hooks/"
cp /tmp/forge-template/.claude/hooks/pre-compact.sh "$PROJECT/.claude/hooks/"
cp /tmp/forge-template/.claude/hooks/pre-agent.sh "$PROJECT/.claude/hooks/"

# Git hooks
cp -r /tmp/forge-template/.githooks "$PROJECT/"
cd "$PROJECT" && bash scripts/setup-hooks.sh

# Skills
cp -r /tmp/forge-template/.claude/skills/supply-chain-audit "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/architecture-kit "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/pre-flight "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/sparc "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/prepare-phase "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/skill-refresh "$PROJECT/.claude/skills/"

# Allowlist
mkdir -p "$PROJECT/.claude/allowlists"
echo '[]' > "$PROJECT/.claude/allowlists/mcp-preapproved.json"

# DSW
mkdir -p "$PROJECT/.github"
cp /tmp/forge-template/.github/dependabot.yml "$PROJECT/.github/"
cp -r /tmp/forge-template/.github/workflows "$PROJECT/.github/"
```

### Step 7 — Configurer les domaines proteges

Editer `.claude/rules/skill-gate.md` : remplacer les domaines {{cloud_provider}}/{{WORKFLOW_ENGINE}}/{{crm_platform}} par les domaines du projet.
Editer `.claude/hooks/pre-tool-use.sh` : adapter les regex de detection.

### Step 8 — Valider

```bash
# Tenter d'ecrire dans un domaine protege sans marker
# → doit etre bloque par pre-tool-use.sh
```

---

## Tier 3 — Intelligence (+4h)

### Step 9 — {{RAG_BACKEND}}

```bash
cp /tmp/forge-template/docker-compose.{{rag_backend}}.yml "$PROJECT/"
cp /tmp/forge-template/scripts/knowledge-sync.py "$PROJECT/scripts/"
cp /tmp/forge-template/config/{{rag_backend}}-registry.json "$PROJECT/config/"
cp -r /tmp/forge-template/.claude/skills/knowledge-sync "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/knowledge-grounding "$PROJECT/.claude/skills/"

# Installer chroma-mcp
uv tool install chroma-mcp
```

### Step 10 — Graphify (optionnel)

```bash
# SCAG approved (graphify est dans le template allowlist)
mkdir -p .skill-locks && touch .skill-locks/scag-approved
uv tool install 'graphifyy[mcp]==0.3.27' --with watchdog

# Copier le skill
cp -r /tmp/forge-template/.claude/skills/graphify "$PROJECT/.claude/skills/"

# Build le graph initial
cd "$PROJECT" && /graphify .
```

### Step 11 — Skills avances

```bash
cp -r /tmp/forge-template/.claude/skills/context-manager "$PROJECT/.claude/skills/"
cp -r /tmp/forge-template/.claude/skills/code-xray "$PROJECT/.claude/skills/"
cp /tmp/forge-template/.claude/rules/swarm-patterns.md "$PROJECT/.claude/rules/"
```

---

## Tier 4 — Domain (variable)

Creer les skills domain-architect specifiques au projet :

1. Identifier les domaines sensibles du projet
2. Creer `.claude/skills/{domain}-architect/SKILL.md` avec les 5 sections standard
3. Ajouter le domaine dans `skill-gate.md`
4. Ajouter les regex dans `pre-tool-use.sh`
5. Ajouter les CARL rules metier dans `.carl/{project-name}`

---

## Post-bootstrap — Verification

```bash
cd "$PROJECT" && claude
# Verifier :
# [ ] session-start.sh s'execute
# [ ] MEMORY.md est injecte
# [ ] pre-tool-use.sh bloque les domaines proteges (si Tier 2)
# [ ] {{RAG_BACKEND}} demarre (si Tier 3)
# [ ] /graphify fonctionne (si Tier 3 + graphify)
```

---

## References

- Extraction map : `docs/architecture/forge/extraction-map.md`
- Configuration points : `docs/architecture/forge/configuration-points.md`
- Maturity model : `docs/architecture/forge/maturity-model.md`
- Component registry : `docs/architecture/forge/component-registry.md`
