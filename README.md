# Claude Code Project Template

Template de projet pour Claude Code avec flywheel de capitalisation, gestion de contexte multi-session, et injection de regles dynamiques via CARL.

## Pourquoi ce template

Claude Code perd son contexte entre les sessions. Sans systeme structure, chaque nouvelle session repart de zero : memes erreurs, memes questions, memes decouvertes.

Ce template resout ca avec 4 couches complementaires :

| Couche | Fichier | Requis | Role |
|--------|---------|--------|------|
| Etat courant | `memory/MEMORY.md` | Oui | Ou on en est, decisions actives, prochaine etape |
| Patterns durables | `docs/solutions/` | Oui | Lecons apprises, patterns valides, anti-patterns |
| Regles dynamiques | `.carl/` | Recommande | Injectees automatiquement selon le contexte du prompt |
| Memoire cross-projet | Supermemory (MCP) | Optionnel | Lecons qui s'appliquent a tous les projets |

Le **flywheel** fait tourner ces couches : chaque probleme resolu est classe, documente, et reinjecte dans les sessions futures.

**Sans CARL ni Supermemory**, le template fonctionne quand meme — tu gardes le flywheel (`MEMORY.md` + `docs/solutions/` + context-manager skill). CARL et Supermemory ajoutent l'automatisation et la memoire cross-projet.

## Prerequis

### Requis

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installe et fonctionnel

### Recommande

- **[CARL](https://github.com/ChristopherKahler/carl)** — injection dynamique de regles selon le contexte du prompt. Sans CARL, les fichiers `.carl/` sont ignores et les regles ne sont pas injectees automatiquement.

### Optionnel

- **[Supermemory](https://supermemory.ai)** — memoire cross-projet persistante via MCP. Sans Supermemory, les etapes "cross-projet" du flywheel sont sautees.
- **[Context7](https://github.com/upstash/context7)** — documentation librairies en temps reel via MCP
- **[GSD](https://github.com/coleam00/gsd)** — execution structuree avec subagents
- **[Compound Engineering](https://github.com/ColemanDuPless);** — planning, review, capitalisation

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
├── CLAUDE.md                              <- Regles projet + flywheel + workflow
│
├── .claude/
│   └── skills/
│       └── context-manager/
│           └── SKILL.md                   <- Gestion contexte (universel)
│
├── .carl/
│   ├── manifest                           <- Config domaine CARL
│   └── {domaine}                          <- Regles CARL projet
│
├── memory/
│   └── MEMORY.md                          <- Etat courant (lu en premier)
│
├── docs/
│   ├── solutions/                         <- Patterns valides (flywheel)
│   ├── plans/                             <- Output /workflows:plan
│   └── brainstorms/                       <- Output /workflows:brainstorm
│
├── todos/                                 <- Output /triage
│
└── src/                                   <- Code projet
```

## Comment ca marche

### Le flywheel en 5 etapes

```
   Probleme resolu
        |
        v
  1. Classifier -----> ponctuel / reutilisable / cross-projet
        |
        v
  2. Documenter -----> docs/solutions/{domaine}/{pattern}.md
        |
        v
  3. CARL rule ------> .carl/{domaine} (si reutilisable + CARL installe)
        |
        v
  4. Supermemory ----> memoire cross-projet (si cross-projet + Supermemory installe)
        |
        v
  5. Commit ---------> code + MEMORY.md + docs + CARL dans un seul commit
```

### Cycle de session

```
  Debut session                         Fin session
  ┌─────────────┐                      ┌──────────────┐
  │ Lire        │                      │ Mettre a jour│
  │ MEMORY.md   │──── travailler ────> │ MEMORY.md    │
  │ docs/       │                      │ flywheel si  │
  │ Supermemory │                      │ pattern      │
  │ CARL auto   │                      │ commit       │
  └─────────────┘                      └──────────────┘
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
| docs/solutions/ (flywheel) | Oui | Oui |
| context-manager skill | Oui | Oui |
| Regles injectees auto par prompt | Non | Oui |
| Keywords recall par domaine | Non | Oui |
| Context brackets (FRESH/WARM/HOT) | Non | Oui |

Sans CARL, les fichiers `.carl/` existent mais ne sont pas lus automatiquement. Les regles dans CLAUDE.md et le context-manager skill restent actifs.

## Fichiers du template

| Fichier | Type | Description |
|---------|------|-------------|
| `init-project.sh` | Script | Genere un projet complet a partir des templates |
| `CLAUDE.md.template` | Template | Regles projet avec `{{PLACEHOLDER}}` |
| `memory/MEMORY.md.template` | Template | Etat courant avec `{{PLACEHOLDER}}` |
| `.carl/manifest.template` | Template | Config domaine CARL |
| `.carl/domain.template` | Template | Regles CARL (3 flywheel + slots) |
| `.claude/skills/context-manager/SKILL.md` | Skill | Copie tel quel (universel) |

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
