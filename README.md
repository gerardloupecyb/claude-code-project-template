# Claude Code Project Template

Template de projet pour Claude Code avec flywheel de capitalisation, gestion de contexte multi-session, et injection de regles dynamiques via CARL.

## Pourquoi ce template

Claude Code perd son contexte entre les sessions. Sans systeme structure, chaque nouvelle session repart de zero : memes erreurs, memes questions, memes decouvertes.

Ce template resout ca avec un systeme de retention a 4 couches, comme un cache L1/L2/L3/L4 :

| Couche | Fichier | Acces | Role |
|--------|---------|-------|------|
| CARL rules | `.carl/` | Auto-injecte chaque prompt | Regles critiques, impossibles a ignorer |
| Cache chaud | `LESSONS.md` | Lu chaque session (cap 50) | Lecons recentes, quand/faire/parce que |
| Archive | Supermemory (projet) | `recall` a la planification | Lecons archivees, cherchables |
| Backup | `docs/solutions/` | Agent search (fallback/profondeur) | Copie git + patterns detailles |

Chaque couche ajoute du detail. Claude descend dans la pile seulement quand il a besoin de plus.

**Le flywheel** : chaque probleme resolu est capture via `/lesson` (10 sec), puis promu en regle CARL si critique, puis migre vers Supermemory quand le cap est atteint.

**Sans CARL ni Supermemory**, le template fonctionne quand meme — tu gardes `MEMORY.md` + `LESSONS.md` + context-manager skill. CARL et Supermemory ajoutent l'injection automatique et l'archivage.

## Prerequis

### Requis

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installe et fonctionnel

### Recommande

- **[CARL](https://github.com/ChristopherKahler/carl)** — injection dynamique de regles selon le contexte du prompt. Sans CARL, les fichiers `.carl/` sont ignores et les regles ne sont pas injectees automatiquement.

### Optionnel

- **[Supermemory](https://supermemory.ai)** — memoire cross-projet persistante via MCP. Sans Supermemory, les etapes "cross-projet" du flywheel sont sautees.
- **[Context7](https://github.com/upstash/context7)** — documentation librairies en temps reel via MCP
- **[GSD](https://github.com/coleam00/gsd)** — execution structuree avec subagents
- **[Compound Engineering](https://github.com/ColemanDuPlessis/compound-engineering)** — planning, review, capitalisation

## Installation des dependances

### Installer CARL

```bash
npx carl-core
```

L'installeur propose deux modes :

| Mode | Scope | Ou |
|------|-------|----|
| Global | Toutes les sessions Claude Code | `~/.claude/` + `~/.carl/` |
| Local | Projet courant seulement | `./.claude/` + `./.carl/` |

> Choisir **Global** si tu comptes utiliser CARL sur plusieurs projets.
> Redemarrer Claude Code apres l'installation.

Pour mettre a jour CARL :

```bash
npx carl-core@latest
```

Pour verifier que CARL fonctionne, taper `*carl` dans un prompt Claude Code.

### Installer Supermemory (optionnel)

[Supermemory](https://supermemory.ai) fournit une memoire persistante cross-session et cross-projet.

**Option A — Installation automatique (recommandee) :**

```bash
npx -y install-mcp@latest https://mcp.supermemory.ai/mcp --client claude --oauth=yes
```

L'installeur ouvre un flow OAuth dans le navigateur pour l'authentification.

**Option B — Configuration manuelle :**

1. Creer un compte sur [app.supermemory.ai](https://app.supermemory.ai) et generer une API key (commence par `sm_`)

2. Ajouter dans `~/.mcp.json` :

```json
{
  "mcpServers": {
    "supermemory": {
      "url": "https://mcp.supermemory.ai/mcp",
      "headers": {
        "Authorization": "Bearer sm_YOUR_API_KEY"
      }
    }
  }
}
```

3. Redemarrer Claude Code

**Verifier l'installation :** les outils `memory`, `recall`, `listProjects` et `whoAmI` doivent apparaitre dans les outils disponibles.

### Installer Context7 (optionnel)

```bash
npx -y install-mcp@latest https://mcp.context7.ai/mcp --client claude
```

Ou manuellement :

```bash
claude mcp add context7 -s user -- npx -y @upstash/context7-mcp@latest
```

## Quick Start

### 1. Cloner le template

```bash
git clone https://github.com/gerardloupecyb/claude-code-project-template.git
cd claude-code-project-template
```

### 2. Initialiser un nouveau projet

```bash
./init-project.sh "Mon Projet" monprojetworkflow "keyword1,keyword2,keyword3"
```

**Arguments :**

| Argument | Description | Exemple |
|----------|-------------|---------|
| Nom du projet | Nom d'affichage, utilise dans les headers | `"Mon SaaS"` |
| Domaine CARL | Minuscules, sans tirets | `saasworkflow` |
| Keywords CARL | Declencheurs du domaine (comma-separated) | `"saas,api,billing,stripe"` |

Le projet est cree dans le **dossier parent** du template. Tu peux changer ca avec :

```bash
WORKSPACE_DIR=/mon/autre/dossier ./init-project.sh "Mon Projet" monworkflow "keys"
```

**Exemples concrets :**

```bash
# Projet SaaS
./init-project.sh "Mon SaaS" saasworkflow "saas,api,subscription,billing,stripe,webhook"

# Projet E-commerce
./init-project.sh "Ma Boutique" ecommerceworkflow "ecommerce,shopify,product,cart,checkout,order"

# Projet Data Pipeline
./init-project.sh "Data Pipeline" datapipelineworkflow "pipeline,etl,dbt,airflow,warehouse,transform"
```

### 3. Completer les placeholders

Le script remplace automatiquement le nom du projet, le domaine CARL, et la date. Il reste des `{{PLACEHOLDER}}` a remplir manuellement :

**Dans `CLAUDE.md` :**

| Placeholder | Quoi mettre |
|-------------|-------------|
| `{{STACK_ITEM_1}}`, `{{STACK_ITEM_2}}` | Technologies du projet |
| `{{MCP_EXTRA_1}}`, `{{MCP_EXTRA_2}}` | MCP additionnels (ou supprimer les lignes) |
| `{{SKILLS_DESCRIPTION}}` | Skills installes dans `.claude/skills/` |
| `{{SOLUTION_DOMAINS}}` | Sous-dossiers de `docs/solutions/` |
| `{{DOMAIN_1}}`, `{{DOMAIN_2}}` + colonnes | Domaines actifs du projet |

**Dans `memory/MEMORY.md` :**

| Placeholder | Quoi mettre |
|-------------|-------------|
| `{{NEXT_STEP}}` | Premiere action a faire |
| `{{PROJECT_DESCRIPTION}}` | Description courte du projet (3-5 lignes) |
| `{{INIT_ACTION_1}}`, `{{INIT_ACTION_2}}` | Actions d'initialisation faites |
| `{{DECISION_1}}`, `{{REASON_1}}` | Premiere decision architecturale |
| `{{STACK_ITEM_1}}`, `{{STACK_ITEM_2}}` | Stack technique |
| `{{REPO_URL}}` | URL du repo Git |

### 4. Ajouter les sous-dossiers domaine

```bash
# Exemple pour un projet SaaS
mkdir -p docs/solutions/api
mkdir -p docs/solutions/auth
mkdir -p docs/solutions/billing
mkdir -p src/api
mkdir -p src/auth
mkdir -p src/billing
```

### 5. Ajouter des regles CARL specifiques

Editer `.carl/{domaine}` et decommenter/ajouter les regles projet :

```
MONWORKFLOW_RULE_4=Description de la regle specifique au projet.
MONWORKFLOW_RULE_5=Autre regle specifique.
```

### 6. Ajouter des skills projet (optionnel)

Creer `.claude/skills/{skill-name}/SKILL.md` pour chaque skill supplementaire :

```bash
mkdir -p .claude/skills/mon-skill-expert
# Editer .claude/skills/mon-skill-expert/SKILL.md
```

## Structure generee

```
Mon Projet/
├── CLAUDE.md                              <- Regles projet + workflows
├── LESSONS.md                             <- Cache chaud lecons (cap 50, /lesson)
├── DECISIONS.md                           <- Registre ADR decisions (cap ~25 actives)
│
├── .claude/
│   ├── skills/
│   │   ├── context-manager/SKILL.md       <- Gestion contexte (universel)
│   │   ├── pre-flight/SKILL.md            <- Review multi-agent des plans
│   │   ├── session-gate/SKILL.md          <- Validation MEMORY.md (13 checks)
│   │   ├── project-sync/SKILL.md          <- Sync outils externes
│   │   ├── project-bootstrap/SKILL.md     <- Bootstrap cross-projet (Supermemory)
│   │   ├── context-checkpoint/SKILL.md    <- Checkpoint avant coupure
│   │   └── lesson/SKILL.md               <- Capture rapide de lecons
│   ├── hooks/
│   │   ├── pre-compact.sh                 <- Snapshot MEMORY.md avant compaction
│   │   └── session-start.sh               <- Re-injection contexte au demarrage
│   └── rules/
│       ├── tool-routing.md                <- Routing outils + anti-flooding
│       └── flywheel-workflow.md           <- Workflow capitalisation
│
├── .carl/
│   ├── manifest                           <- Config domaine CARL
│   └── {domaine}                          <- Regles CARL projet (RULE_0-8 + slots)
│
├── memory/
│   └── MEMORY.md                          <- Etat courant (lu en premier)
│
├── docs/
│   ├── solutions/                         <- Backup local lecons + patterns detailles
│   ├── plans/                             <- Output /ce:plan
│   └── brainstorms/                       <- Output /ce:brainstorm
│
├── todos/                                 <- Output /triage
│
└── src/                                   <- Code projet
```

## Comment ca marche

### Deux chemins de capture

```
   Probleme resolu
        |
        v
   /lesson (rapide, 80% des cas)
        |
        v
   LESSONS.md (quand/faire/parce que)
        |
        +-- si critique ou repetee --> promotion CARL rule
        |
        +-- si cap 50 atteint ------> /lesson migrate :
        |                               1. Supermemory (projet)
        |                               2. docs/solutions/ (backup git)
        |
   /ce:compound (complet, 20% des cas)
        |
        v
   docs/solutions/ (pattern detaille + code + anti-patterns)
        +-- si reutilisable --> CARL rule
        +-- si cross-projet --> Supermemory
```

### Cycle de session

```
  Debut session                         Fin session
  ┌─────────────┐                      ┌──────────────┐
  │ Lire        │                      │ Mettre a jour│
  │ MEMORY.md   │──── travailler ────> │ MEMORY.md    │
  │ LESSONS.md  │                      │ /lesson si   │
  │ CARL auto   │                      │ fix non-triv │
  └─────────────┘                      │ commit       │
                                       └──────────────┘
```

### Gestion du contexte long

Quand le contexte se degrade (~60-70% utilise) :

1. Claude annonce "Contexte a X% - checkpoint recommande"
2. MEMORY.md est mis a jour avec l'etat complet
3. Nouvelle session demarre en lisant MEMORY.md
4. Zero perte d'information

### Ce qui fonctionne sans CARL

| Fonctionnalite | Sans CARL | Avec CARL |
|----------------|-----------|-----------|
| MEMORY.md (etat session) | Oui | Oui |
| LESSONS.md (cache chaud) | Oui | Oui |
| /lesson (capture rapide) | Oui | Oui |
| context-manager skill | Oui | Oui |
| Regles injectees auto par prompt | Non | Oui |
| Promotion lecon → regle CARL | Non | Oui |
| Keywords recall par domaine | Non | Oui |
| Context brackets (FRESH/WARM/HOT) | Non | Oui |

Sans CARL, les fichiers `.carl/` existent mais ne sont pas lus automatiquement. Les lecons restent dans LESSONS.md et Supermemory.

## Fichiers du template

| Fichier | Type | Description |
|---------|------|-------------|
| `init-project.sh` | Script | Genere un projet complet a partir des templates |
| `CLAUDE.md.template` | Template | Regles projet avec `{{PLACEHOLDER}}` |
| `LESSONS.md.template` | Template | Cache chaud des lecons (cap 50) |
| `DECISIONS.md.template` | Template | Registre ADR decisions (cap ~25 actives) |
| `memory/MEMORY.md.template` | Template | Etat courant avec `{{PLACEHOLDER}}` |
| `.carl/manifest.template` | Template | Config domaine CARL |
| `.carl/domain.template` | Template | Regles CARL (RULE_0-8 + slots) |
| `.claude/skills/context-manager/SKILL.md` | Skill | Gestion contexte (universel) |
| `.claude/skills/lesson/SKILL.md` | Skill | Capture rapide de lecons |
| `.claude/skills/pre-flight/SKILL.md` | Skill | Review multi-agent des plans |
| `.claude/skills/session-gate/SKILL.md` | Skill | Validation MEMORY.md (13 checks) |
| `.claude/skills/project-sync/SKILL.md` | Skill | Sync outils externes |
| `.claude/skills/project-bootstrap/SKILL.md` | Skill | Bootstrap cross-projet (Supermemory) |
| `.claude/skills/context-checkpoint/SKILL.md` | Skill | Checkpoint avant coupure de session |

## Ajouter des skills tiers

Le template est concu pour accueillir des skills supplementaires. Exemple avec [claude-ads](https://github.com/AgriciDaniel/claude-ads) :

```bash
# Cloner et installer les skills ads
git clone https://github.com/AgriciDaniel/claude-ads /tmp/claude-ads
cp -r /tmp/claude-ads/skills/* .claude/skills/
cp -r /tmp/claude-ads/agents/* .claude/agents/
cp -r /tmp/claude-ads/ads/* .claude/skills/ads/
rm -rf /tmp/claude-ads
```

Les skills tiers vont dans `.claude/skills/`, les regles CARL dans `.carl/`.
Ne pas melanger les deux : CARL = injection automatique, skills = invocation explicite.

## Conventions

### Nommage CARL

- Domaines : minuscules, sans tirets (`saasworkflow`, pas `saas-workflow`)
- Rules : `{DOMAIN_UPPER}_RULE_{N}=Description courte et actionnable.`
- Keywords : termes que l'utilisateur utilise naturellement dans ses prompts

### Nommage docs/solutions

- Un fichier par pattern : `docs/solutions/{domaine}/{pattern-name}.md`
- Mettre a jour l'existant plutot que dupliquer
- Template de pattern dans le CLAUDE.md

### Nommage skills

- Un dossier par skill : `.claude/skills/{skill-name}/SKILL.md`
- Frontmatter YAML obligatoire avec `name` et `description`
- Description = triggers pour le chargement automatique

## Credits

- [CARL](https://github.com/ChristopherKahler/carl) par Christopher Kahler — injection dynamique de regles
- [claude-ads](https://github.com/AgriciDaniel/claude-ads) par Daniel Agrici — skills audit publicitaire
- [Supermemory](https://github.com/supermemoryai/supermemory) — memoire persistante cross-session

## License

MIT
