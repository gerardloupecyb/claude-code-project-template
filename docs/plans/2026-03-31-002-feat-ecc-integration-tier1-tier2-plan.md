---
title: "feat: ECC integration — Tier 1 & 2 improvements"
type: feat
status: active
date: 2026-03-31
origin: docs/brainstorms/2026-03-31-ecc-integration-requirements.md
---

# ECC Integration — Tier 1 & Tier 2 Improvements

## Overview

Intègre 5 patterns sélectionnés du repo `everything-claude-code` et `agentshield`
dans le project-template. R2 supprimé (redondant avec `swarm-patterns.md` auto-chargé).
Tier 3 (R7-R9) est explicitement hors scope (voir origin doc — décision architecturale requise).

| ID  | Item                                  | Tier | Type            |
|-----|---------------------------------------|------|-----------------|
| R3  | Bash audit log hook                   | 1    | settings.json   |
| R4  | Deep-context capture in prepare-phase | 2    | Modifier skill  |
| R5  | `/rules-distill` skill                | 2    | Nouveau skill   |
| R6  | Agent definition files `.claude/agents/` | 2 | Nouveaux fichiers |
| R10 | `/security-audit` skill (AgentShield) | 2   | Nouveau skill   |

## Problem Statement

Le template est solide sur l'orchestration et la mémoire, mais manque de :

- Traçabilité des commandes shell exécutées par Claude pendant une session
- Capture de contexte codebase avant implémentation (pattern ECC "prp-plan")
- Automatisation du flywheel LESSONS → CARL (step manuel, souvent sauté)
- Subagents nommés invocables (rôles définis dans swarm-patterns mais pas en fichiers)
- Audit de sécurité on-demand des configs Claude Code

## Proposed Solution

4 phases livrables séquentiellement, les unes indépendantes des autres.

---

## Implementation Phases

### Phase 1 — Tier 1 quick win (R3)

#### R3 — Bash audit log (PostToolUse/Bash hook)

Modification de `.claude/settings.json` — ajout d'un bloc PostToolUse :

```json
{
  "matcher": "Bash",
  "hooks": [{
    "type": "command",
    "command": "HOOK_INPUT=$(cat); CMD=$(echo \"$HOOK_INPUT\" | jq -r '.tool_input.command // \"?\"' 2>/dev/null | tr '\\n' ' '); CMD=$(echo \"$CMD\" | sed 's/--token[= ][^ ]*/--token=<REDACTED>/g; s/AKIA[A-Z0-9]\\{16\\}/<REDACTED>/g; s/sk-ant-[A-Za-z0-9_-]*/<REDACTED>/g; s/sk-proj-[A-Za-z0-9_-]*/<REDACTED>/g; s/ghp_[A-Za-z0-9_]*/<REDACTED>/g; s/github_pat_[A-Za-z0-9_]*/<REDACTED>/g'); mkdir -p ~/.claude; echo \"[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $CMD\" >> ~/.claude/bash-commands.log 2>/dev/null; printf '%s' \"$HOOK_INPUT\""
  }]
}
```

Règles :
- Exit 0 toujours (non-blocking — un log raté ne doit pas bloquer Claude)
- Fallback si `jq` absent : logge `[timestamp] <jq-unavailable>`
- `printf '%s' "$HOOK_INPUT"` en sortie (PostToolUse doit repasser le payload)
- `chmod 600 ~/.claude/bash-commands.log` après création (permissions restrictives)
- Log global intentionnel (debug cross-sessions, cross-projects) — données locales à la machine
- **Opt-out** : il suffit de retirer le bloc PostToolUse/Bash de `settings.json`

Format de log : `[2026-03-31T14:23:11Z] git commit -m "feat: ..."`

---

### Phase 2 — New skills (R5, R6, R10)

#### R5 — Skill `/rules-distill`

Nouveau fichier `.claude/skills/rules-distill/SKILL.md`.

Process :

1. Lire `LESSONS.md` — extraire toutes les leçons (section `## Lecons`)
2. Lire les skills installés dans `.claude/skills/*/SKILL.md` — extraire les patterns mentionnés
3. Identifier clusters cross-cutting : leçons qui partagent un domaine ou un mécanisme
4. Pour chaque cluster (≥ 2 leçons) :
   - Formuler règle CARL format `{DOMAIN_UPPER}_RULE_{N}=Toujours X quand Y.`
   - Identifier le prochain `N` disponible dans `.carl/{domain}` (lire le fichier, compter les règles)
   - Présenter à l'utilisateur : règle proposée + leçons sources
5. Si validé → invoquer `/carl:tasks:add-rule` (confirmé présent : `~/.claude/commands/carl/tasks/add-rule.md`)
6. Si aucun cluster détecté → informer "Pas assez de patterns répétés pour distiller une règle"

Contrainte : ne jamais créer une règle sans validation explicite de l'utilisateur.

#### R6 — Agent definition files

Nouveau répertoire `.claude/agents/` avec 4 fichiers.

Chaque fichier suit le format Claude Code natif (frontmatter YAML + corps Markdown) :

**`.claude/agents/architect.md`**
```yaml
---
name: architect
description: >
  Software architecture specialist. Use PROACTIVELY when planning new features,
  refactoring large systems, or making architectural decisions. Routes to Opus.
tools: ["Read", "Grep", "Glob"]
model: claude-opus-4-6
---
```
Corps : rôle (design système, APIs, boundaries), process (analyse état actuel →
requirements → proposal → trade-offs), checklist sortie (diagram, ADR proposé,
risks identifiés).

**`.claude/agents/code-reviewer.md`**
```yaml
---
name: code-reviewer
description: >
  Expert code review specialist. Use after writing or modifying code.
  Reviews for quality, security, and maintainability.
tools: ["Read", "Grep", "Glob", "Bash"]
model: claude-sonnet-4-6
---
```
Corps : checklist par sévérité (CRITICAL security → HIGH quality → MEDIUM perf → LOW style),
règle confidence-based filtering (reporter seulement si > 80% certain), format de sortie.

**`.claude/agents/tdd-guide.md`**
```yaml
---
name: tdd-guide
description: >
  Test-driven development specialist. Use PROACTIVELY for new features and bug fixes.
  Enforces RED → GREEN → IMPROVE cycle.
tools: ["Read", "Grep", "Glob", "Bash"]
model: claude-sonnet-4-6
---
```
Corps : cycle TDD strict, structure des tests, règles de coverage.

**`.claude/agents/security-reviewer.md`**
```yaml
---
name: security-reviewer
description: >
  Security specialist. Use for auth flows, payment code, user data, or any
  security-sensitive changes. Applies OWASP top 10 analysis.
tools: ["Read", "Grep", "Glob"]
model: claude-sonnet-4-6
---
```
Corps : OWASP checklist, secrets detection, auth/authz review, input validation.

Note : ces agents sont additifs à `swarm-patterns.md` — ils ne le remplacent pas.
`swarm-patterns.md` reste la source de vérité pour l'orchestration SPARC.

**Validation du support :** Claude Code 2.1.76 supporte `.claude/agents/` (confirmé :
`~/.claude/agents/` existe avec 56 agents). Le test R6 validera le support project-level.

#### R10 — Skill `/security-audit`

Nouveau fichier `.claude/skills/security-audit/SKILL.md`.

Process :

1. Vérifier que `npx` est disponible (`command -v npx`) — sinon afficher message d'installation
2. Invoquer `npx ecc-agentshield scan --path .claude/` (ou `--path ~/.claude/` si invoqué global)
3. Option `--fix` : ajouter le flag pour auto-corriger les issues simples (remplace secrets hardcodés par refs env vars)
4. Parser le rapport de sortie :
   - Afficher le grade (A-F) et score (0-100)
   - Lister les CRITICAL en premier, puis HIGH
   - Résumer MEDIUM/LOW en comptage
5. Si `ANTHROPIC_API_KEY` présent dans l'env → suggérer `--opus` pour analyse adversariale Opus 4.6

Usage : `/security-audit` ou `/security-audit --fix`

---

### Phase 3 — Prepare-phase extension (R4)

#### Modification de `.claude/skills/prepare-phase/SKILL.md`

Flow actuel : `discuss → plan → deepen? → pre-flight`
Flow nouveau : `context-capture → discuss → plan → deepen? → pre-flight`

**Nouveau Step 0 — Context Capture (automatique, avant discuss)**

Objectif : capturer tout ce que Claude devra connaître pendant l'implémentation,
*avant* de commencer à discuter ou planifier. Principe ECC : "si tu aurais besoin
de chercher pendant l'implémentation, capture maintenant."

Actions :

1. Lire `CLAUDE.md` — extraire stack, outils actifs, conventions
2. Lire `LESSONS.md` — extraire les leçons pertinentes à la feature demandée
3. Lire `.claude/rules/*.md` — extraire règles applicables
4. Grep les fichiers source pour patterns similaires à la feature (ex : si OAuth, grep "auth", "session", "token")
5. Produire `.claude/workspace/context-capture-{N}.md` avec sections :
   - `## Stack détectée` — langages, frameworks, versions
   - `## Patterns existants` — chemins + courte description (ex: `src/auth/session.rb:42 — session store pattern`)
   - `## Conventions établies` — règles non-négociables tirées de CARL/rules
   - `## Gotchas documentés` — leçons LESSONS.md pertinentes
   - `## Questions à lever` — ambiguïtés détectées avant discuss

6. Informer l'utilisateur : "Context capture prêt → `.claude/workspace/context-capture-{N}.md`"
7. Passer le path à `gsd:discuss-phase` et `gsd:plan-phase` comme contexte additionnel

Contrainte : step léger (lecture + grep, pas d'inférence lourde). Si LESSONS.md vide
ou aucun pattern trouvé → section vide, pas d'erreur.

**Mise à jour de la section Sequence dans SKILL.md** :

```
### Step 0 — Context Capture (automatic)
...

### Step 1 — Discuss Phase (automatic)
...
```

---

### Phase 4 — init-project.sh updates

Ajouter dans `init-project.sh` :

**mkdir -p** :
```bash
mkdir -p "${PROJECT_DIR}/.claude/skills/rules-distill"
mkdir -p "${PROJECT_DIR}/.claude/skills/security-audit"
mkdir -p "${PROJECT_DIR}/.claude/agents"
```

**cp skills** :
```bash
cp "${TEMPLATE_DIR}/.claude/skills/rules-distill/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/rules-distill/SKILL.md"
cp "${TEMPLATE_DIR}/.claude/skills/security-audit/SKILL.md" \
   "${PROJECT_DIR}/.claude/skills/security-audit/SKILL.md"
```

**cp agents** :
```bash
cp "${TEMPLATE_DIR}/.claude/agents/architect.md"         "${PROJECT_DIR}/.claude/agents/architect.md"
cp "${TEMPLATE_DIR}/.claude/agents/code-reviewer.md"     "${PROJECT_DIR}/.claude/agents/code-reviewer.md"
cp "${TEMPLATE_DIR}/.claude/agents/tdd-guide.md"         "${PROJECT_DIR}/.claude/agents/tdd-guide.md"
cp "${TEMPLATE_DIR}/.claude/agents/security-reviewer.md" "${PROJECT_DIR}/.claude/agents/security-reviewer.md"
```

`settings.json` est déjà copié par `cp "${TEMPLATE_DIR}/.claude/settings.json"` — le hook R3
sera inclus automatiquement si settings.json est mis à jour dans le template.

**Mise à jour du message de succès** : ajouter dans la liste des skills installés
`rules-distill, security-audit` et dans `.claude/agents/` la mention des 4 agents.

---

## Acceptance Criteria

### R3 — Bash audit log

- [ ] Après toute commande Bash, `~/.claude/bash-commands.log` contient une nouvelle entrée
- [ ] Les tokens (`--token=xxx`), API keys (`sk-ant-`, `AKIA*`), PATs (`ghp_*`) sont redactés
- [ ] Tester avec une commande contenant un faux token → vérifier que le token est `<REDACTED>` dans le log
- [ ] Le hook exit 0 même si `jq` est absent ou si l'écriture échoue
- [ ] Le payload original est repassé sur stdout (PostToolUse ne bloque pas)
- [ ] `~/.claude/bash-commands.log` a permissions `600` après création

### R4 — Context capture

- [ ] `/prepare-phase N` génère `.claude/workspace/context-capture-N.md` avant discuss
- [ ] Le fichier contient au moins : stack + conventions (même si LESSONS.md vide)
- [ ] Si aucun pattern trouvé via grep, le step passe sans erreur (sections vides acceptables)
- [ ] Le flow complet (step 0→4) se termine sans intervention manuelle supplémentaire
- [ ] **Test de valeur** : tester sur `project-template-v2` lui-même (riche en LESSONS, rules, patterns) — pas seulement sur projet frais vide

### R5 — `/rules-distill`

- [ ] Sur un LESSONS.md avec 3 leçons dans le même domaine → propose au moins 1 règle CARL
- [ ] La règle proposée suit le format `{DOMAIN_UPPER}_RULE_{N}=Toujours X quand Y.`
- [ ] L'utilisateur doit confirmer avant que la règle soit ajoutée
- [ ] Compatible avec `/carl:tasks:add-rule`

### R6 — Agent files

- [ ] Les fichiers `.claude/agents/*.md` ont un frontmatter YAML valide (`name`, `description`, `tools`, `model`)
- [ ] Invoquer `architect` via `Agent` tool → comportement Opus, biais "propose la meilleure solution"
- [ ] `init-project.sh` installe les 4 fichiers dans un projet frais

### R10 — `/security-audit`

- [ ] `/security-audit` invoque AgentShield et affiche grade + findings CRITICAL/HIGH
- [ ] Si `npx` absent → message d'erreur actionnable (pas de crash silencieux)
- [ ] `/security-audit --fix` passe le flag `--fix` à agentshield

### Global

- [ ] `init-project.sh` installe tous les nouveaux items dans un projet test frais
- [ ] Chaque item validé manuellement dans un projet init-isé (voir Testing Requirements dans origin doc)
- [ ] R10 testé : `/security-audit` dans un projet avec `settings.json` → grade + findings affichés
- [ ] R10 testé : invocation sans `npx` → message d'erreur actionnable (pas crash silencieux)

## System-Wide Impact

- **prepare-phase** : Step 0 s'exécute avant discuss — si le grep prend trop de temps sur
  un grand repo, ajouter un timeout ou limiter à `.claude/` + racine du projet
- **settings.json** : le hook R3 est PostToolUse/Bash — non-blocking, pas d'impact sur
  les hooks existants (PreCompact, PreToolUse/Agent, SessionStart)
- **init-project.sh** : ajouts purement additifs, aucune modification des lignes existantes
- **LESSONS.md** : R5 lit mais ne modifie jamais LESSONS.md

## Dependencies & Risks

| Risque | Mitigation |
|--------|-----------|
| R6 : `.claude/agents/` non supporté par la version locale de Claude Code | Vérifier via test dans projet frais avant de committer — si non supporté, noter dans AC et documenter comme "ready for when supported" |
| R3 : `jq` absent sur certaines machines | Fallback : logge `<jq-unavailable>` et exit 0 |
| R4 : grep trop large sur grand repo | Limiter le grep à `.claude/`, `src/` (1 niveau), et racine |
| R10 : `npx` absent | Check préalable dans le skill, message d'installation claire |

## Sources & References

### Origin

- **Origin document:** [docs/brainstorms/2026-03-31-ecc-integration-requirements.md](docs/brainstorms/2026-03-31-ecc-integration-requirements.md)
  Décisions portées : R1 et R2 supprimés, R4 intégré dans prepare-phase (pas standalone),
  shell-only pour R3-R6, `npx` acceptable pour R10 (audit on-demand)

### Internal References

- Skill à modifier : [.claude/skills/prepare-phase/SKILL.md](.claude/skills/prepare-phase/SKILL.md)
- Hook config : [.claude/settings.json](.claude/settings.json)
- Model routing source : [.claude/rules/swarm-patterns.md](.claude/rules/swarm-patterns.md)
- Init script : [init-project.sh](init-project.sh)

### External References

- ECC source : https://github.com/affaan-m/everything-claude-code (commands/rules-distill.md, agents/*.md)
- AgentShield : https://github.com/affaan-m/agentshield
