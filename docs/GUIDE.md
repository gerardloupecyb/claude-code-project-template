# Guide complet — Claude Code Project Template

> Ce guide explique comment utiliser le template et toutes ses fonctionnalites.
> Pour l'installation rapide, voir le [README](../README.md).

---

## Table des matieres

1. [Le probleme que ce template resout](#1-le-probleme)
2. [Architecture 3 couches](#2-architecture-3-couches)
3. [Cycle de vie d'une session](#3-cycle-de-vie-session)
4. [Les 7 skills inclus](#4-les-7-skills)
5. [Le systeme de hooks](#5-hooks)
6. [CARL — regles dynamiques](#6-carl)
7. [Capturer les lecons — /lesson](#7-capturer-les-lecons)
8. [Registre de decisions — DECISIONS.md](#8-decisions)
9. [Bootstrap cross-projet](#9-bootstrap)
10. [Workflows de developpement](#10-workflows)
11. [Quality score et closure](#11-quality-score)
12. [Session-gate — 13 checks](#12-session-gate)
13. [Reference files — 4 couches](#13-reference-files)
14. [Gestion du contexte long](#14-contexte-long)
15. [FAQ et troubleshooting](#15-faq)

---

<a id="1-le-probleme"></a>
## 1. Le probleme que ce template resout

Claude Code est puissant, mais il a trois limites structurelles :

- **Memoire de session limitee** — la fenetre de contexte est finie et se reinitialise a chaque nouvelle session
- **Pas d'apprentissage automatique** — les corrections et preferences disparaissent si tu ne les captures pas
- **Le fine-tuning classique n'est pas adapte** — trop lourd, trop cher pour des projets quotidiens

**Consequences sans ce template :**
- Tu repetes ton contexte a chaque session
- Tu corriges les memes erreurs
- Claude re-propose des approches deja rejetees
- Pas d'impression que l'IA "s'ameliore" avec toi

**Ce que ce template resout :**
- Donne a Claude une **memoire externe structuree**
- Transforme chaque erreur en **lecon durable**
- Construit une boucle ou ton IA devient **plus competente a chaque interaction**

---

<a id="2-architecture-3-couches"></a>
## 2. Architecture 3 couches

Le template utilise une architecture en 3 couches, pensee comme un cache CPU (L1/L2/L3) :

```
┌─────────────────────────────────────────────────────┐
│  LAYER 1 — Toujours actif (auto-injecte)            │
│  CARL rules + CLAUDE.md + hooks                     │
│  Cout : 0 token (injecte par le systeme)            │
├─────────────────────────────────────────────────────┤
│  LAYER 2 — Contexte projet (lu a chaque session)    │
│  MEMORY.md + LESSONS.md + DECISIONS.md              │
│  Cout : ~500-1500 tokens                            │
├─────────────────────────────────────────────────────┤
│  LAYER 3 — Archive profonde (lu a la planification) │
│  Supermemory + docs/solutions/                      │
│  Cout : variable, a la demande                      │
└─────────────────────────────────────────────────────┘
```

### Layer 1 — Defaults globaux (toujours actifs)

Ce qui est automatiquement charge a chaque prompt, sans action de ta part :

| Composant | Fichier | Comment ca marche |
|-----------|---------|-------------------|
| Regles CARL | `.carl/{domaine}` | Injectees automatiquement quand les keywords du domaine sont detectes dans le prompt |
| Rules Claude Code | `.claude/rules/*.md` | Charges automatiquement par Claude Code pour les fichiers concernes |
| Hooks | `.claude/hooks/*.sh` | Executes automatiquement sur les evenements de session (demarrage, compaction) |
| CLAUDE.md | `CLAUDE.md` | Lu automatiquement par Claude Code a chaque session |

**Tu n'as rien a faire** — c'est le systeme qui gere l'injection.

### Layer 2 — Contexte par projet (lu a chaque session)

Les fichiers que Claude lit en debut de session pour comprendre ou il en est :

| Fichier | Role | Quand le lire |
|---------|------|---------------|
| `memory/MEMORY.md` | Etat courant : ou on en est, prochaine etape, blocages | Debut de chaque session |
| `LESSONS.md` | Lecons apprises, format quand/faire/parce que (cap 50) | Debut de chaque session |
| `DECISIONS.md` | Decisions architecturales, format ADR-light (cap ~25) | A la planification |

### Layer 3 — Archive profonde (a la demande)

Les sources consultees seulement quand Claude a besoin de plus de contexte :

| Source | Quand la consulter | Comment |
|--------|-------------------|---------|
| Supermemory (projet) | Planification (`/gsd:plan-phase`, `/ce:plan`) | `recall` avec keywords du domaine |
| `docs/solutions/` | Fallback si Supermemory indisponible, ou besoin de code detaille | Agent `Explore` |

---

<a id="3-cycle-de-vie-session"></a>
## 3. Cycle de vie d'une session

### Debut de session

```
1. Hook session-start.sh s'execute automatiquement
   → Injecte MEMORY.md + les 10 premieres lecons de LESSONS.md

2. CARL charge le domaine selon les keywords du prompt
   → Regles injectees dans le contexte

3. Claude lit CLAUDE.md (automatique)
   → Connait les regles, les workflows, la structure du projet

4. Optionnel : /session-gate start
   → Verifie que MEMORY.md est a jour et coherent (13 checks)
```

### Pendant la session

```
Travailler normalement. Claude applique les regles CARL,
suit les workflows de CLAUDE.md, et consulte LESSONS.md
quand il rencontre un probleme similaire a une lecon existante.
```

### Fin de session

```
1. Mettre a jour MEMORY.md :
   - Ce qui a ete fait (3-5 lignes)
   - Decisions prises
   - Prochaine etape (une seule, actionnable)
   - Blocages

2. Si fix non-trivial resolu → /lesson

3. Optionnel : /session-gate end
   → Verifie que MEMORY.md est pret pour la prochaine session

4. Commiter MEMORY.md + LESSONS.md avec le code
```

### Si le contexte se degrade

```
Claude devient imprecis, repete des questions → checkpoint :

1. /context-checkpoint
   → Sauvegarde l'etat dans MEMORY.md en < 5 tool calls

2. Ouvrir une nouvelle session
   → session-start.sh re-injecte automatiquement le contexte
```

---

<a id="4-les-7-skills"></a>
## 4. Les 7 skills inclus

Chaque skill est un fichier `.claude/skills/{nom}/SKILL.md` — une instruction specialisee que Claude charge quand tu l'invoques.

### /lesson — Capture rapide de lecons

**Quand l'utiliser :** Apres avoir resolu un probleme non-trivial.

```
/lesson
→ Claude propose une lecon au format quand/faire/parce que
→ Tu confirmes (oui/non)
→ La lecon va dans LESSONS.md
→ Si critique ou repetee (3+) → propose promotion en regle CARL
→ Si cap 50 atteint → propose /lesson migrate
```

**Exemple de lecon :**
```markdown
### [api] Rate limiting sur l'endpoint /search
**Quand** on fait plus de 100 requetes/min sur /search
**Faire** ajouter un throttle cote client avec backoff exponentiel
**Parce que** l'API retourne 429 et coupe l'acces pendant 60s
_Date: 2026-03-14_
```

### /session-gate — Validation mecanique

**Quand l'utiliser :** En debut ou fin de session pour verifier l'etat.

```
/session-gate start    → Verifie que MEMORY.md est pret (9 checks)
/session-gate end      → Verifie que MEMORY.md est a jour avant commit (9 checks)
/session-gate          → Tous les 13 checks
```

Les checks sont mecaniques (pas de jugement) et advisory (jamais bloquants).

### /context-checkpoint — Sauvegarde rapide

**Quand l'utiliser :** Quand le contexte se degrade ou avant une pause.

```
/context-checkpoint
→ Resume l'etat en < 200 mots dans MEMORY.md
→ Liste les decisions prises
→ Identifie la prochaine tache
→ Propose /lesson si pertinent
→ Valide avec /session-gate end
```

### /project-bootstrap — Bootstrap cross-projet

**Quand l'utiliser :** Apres `init-project.sh`, pour injecter les lecons pertinentes d'autres projets.

```
/project-bootstrap
→ Lit les keywords CARL du projet
→ Recall Supermemory avec ces keywords
→ Filtre les lecons par tags ([lesson:*], [skill:*], [convention:*], [decision:*])
→ Propose les 10 plus pertinentes
→ Injecte dans LESSONS.md avec tag Heritage

/project-bootstrap --dry-run
→ Meme chose mais sans ecrire (preview seulement)
```

### /pre-flight — Review multi-agent des plans

**Quand l'utiliser :** Apres `/gsd:plan-phase`, avant `/gsd:execute-phase`.

```
/pre-flight
→ Lance 4 agents en parallele sur le plan :
  1. Architecture strategist
  2. Security sentinel
  3. Performance oracle
  4. Spec flow analyzer
→ Produit un rapport GO / CONDITIONAL GO / NO-GO
```

### /context-manager — Reference contextuelle

**Quand l'utiliser :** Se charge automatiquement quand tu parles de contexte, memoire, ou sessions.

C'est un skill de reference — il rappelle les regles de gestion du contexte definies dans CLAUDE.md.

### /project-sync — Synchronisation externe

**Quand l'utiliser :** Pour synchroniser l'etat du projet avec des outils externes (Linear, GSD).

---

<a id="5-hooks"></a>
## 5. Le systeme de hooks

Les hooks sont des scripts shell qui s'executent automatiquement sur certains evenements de Claude Code.

### pre-compact.sh — Avant la compaction du contexte

Quand Claude Code compacte le contexte (pour liberer de la fenetre), ce hook :

1. Extrait "Prochaine etape" de MEMORY.md
2. Extrait les 3 derniers commits + fichiers modifies
3. Ecrit un snapshot de < 200 mots entre les markers `<!-- pre-compact snapshot -->`
4. Commit automatique de MEMORY.md + LESSONS.md
5. Toujours exit 0 (ne bloque jamais la compaction)

### session-start.sh — Au demarrage de session

Se declenche sur **4 evenements** : `startup`, `compact`, `resume`, `clear`.

1. Lit MEMORY.md et l'injecte dans le contexte (stdout → additionalContext)
2. Lit les 10 premieres lecons de LESSONS.md
3. Ajoute un message contextuel selon l'evenement :
   - `compact` : "Session resumed after compaction"
   - `clear` : "Context cleared — MEMORY.md re-injected"

**Resultat :** Claude retrouve son contexte automatiquement, meme apres une compaction ou un `/clear`.

---

<a id="6-carl"></a>
## 6. CARL — regles dynamiques

[CARL](https://github.com/ChristopherKahler/carl) injecte des regles dans le prompt de Claude selon le contexte detecte.

### Comment ca marche

1. Tu tapes un prompt qui contient un keyword du domaine (ex: "api", "billing")
2. CARL detecte le keyword et charge le fichier `.carl/{domaine}`
3. Les regles sont injectees dans le prompt avant que Claude ne reponde
4. Claude suit les regles sans que tu aies a les rappeler

### Les 10 regles du template

| Rule | Nom | Ce qu'elle fait |
|------|-----|-----------------|
| 0 | Context | Identifie le projet et son chemin |
| 1 | Flywheel Consult | Consulter LESSONS.md + Supermemory avant d'implementer |
| 2 | Flywheel Capture | Proposer `/lesson` apres chaque fix non-trivial |
| 3 | Credentials | Jamais de credentials hardcodes |
| 4 | Loop Closure | SUMMARY.md obligatoire apres chaque execution |
| 5 | Deviation Logging | Logger les deviations dans MEMORY.md |
| 6 | Tool Routing | Utiliser Glob/Grep au lieu de Bash find/grep |
| 7 | MCP Discipline | Toujours utiliser des limites sur les appels MCP |
| 8 | Planning Recall | Recall Supermemory + lire DECISIONS.md avant de planifier |
| 9 | Reference Files | Router vers le bon fichier de reference (L1-L3) + staleness detection |

### Ajouter des regles projet

```
# Dans .carl/{domaine}, decommenter RULE_10 :
MONWORKFLOW_RULE_10=Description de ma regle specifique.
```

---

<a id="7-capturer-les-lecons"></a>
## 7. Capturer les lecons — le flywheel

Le flywheel est la boucle qui transforme chaque probleme resolu en capital reutilisable.

### Deux chemins de capture

```
Probleme resolu
     |
     ├── Simple / rapide (80% des cas)
     │   → /lesson → LESSONS.md
     │   → Si critique → promotion CARL
     │   → Si cap 50 → /lesson migrate → Supermemory + docs/solutions/
     │
     └── Complexe / avec code (20% des cas)
         → /ce:compound → docs/solutions/ (pattern complet)
         → Si reutilisable → CARL rule
         → Si cross-projet → Supermemory
```

### Cycle de vie d'une lecon

```
1. Capture      → /lesson → LESSONS.md (quand/faire/parce que)
2. Application  → Lu a chaque session, Claude l'applique automatiquement
3. Promotion    → Si critique (3+ occurrences) → regle CARL (toujours active)
4. Migration    → Si cap 50 → Supermemory (archive cherchable) + docs/solutions/ (backup git)
```

### Pourquoi ce systeme marche

- **LESSONS.md** est lu a chaque session → les lecons sont **impossibles a oublier**
- **CARL** est injecte a chaque prompt → les regles critiques sont **impossibles a ignorer**
- **Supermemory** est cherchable → les lecons archivees sont **retrouvables** via `recall`
- Chaque couche ajoute du detail, Claude ne descend que quand il a besoin de plus

---

<a id="8-decisions"></a>
## 8. Registre de decisions — DECISIONS.md

Les decisions architecturales et metier sont capturees dans un registre ADR-light.

### Pourquoi un fichier separe

- **MEMORY.md** est nettoye regulierement → les vieilles decisions disparaissent
- **LESSONS.md** capture les "faire X quand Y" → pas le "pourquoi on a choisi X sur Y"
- **DECISIONS.md** capture le **raisonnement** : contexte, choix, alternatives rejetees

### Format d'une decision

```markdown
### DEC-001: Auth via Entra ID [auth] [infrastructure]
- **Date:** 2026-03-10 | **Statut:** ACCEPTED
- **Contexte:** Multi-tenant B2B, SSO requis pour les clients enterprise
- **Decision:** Utiliser Entra ID comme provider d'authentification
- **Rejete:** Firebase (pas de SSO enterprise natif), Auth0 (cout par MAU trop eleve)
- **Consequences:** Necessite expertise Azure AD, mais SSO + Conditional Access inclus
```

### Le champ "Rejete" est crucial

Sans ce champ, Claude re-proposera les alternatives deja rejetees. C'est le **probleme #1** des ADR pour les LLMs — documenter explicitement ce qui a ete rejete et pourquoi.

### Quand c'est consulte

- **A la planification** — Rule de consultation (step 2) : "Lire DECISIONS.md pour les decisions actives"
- **CARL RULE_8** — enforce automatiquement la lecture avant `/gsd:plan-phase` ou `/ce:plan`
- **Session-gate Check 12** — signale les decisions actives > 30 jours (peut-etre obsoletes)

### Statuts

| Statut | Signification |
|--------|---------------|
| ACCEPTED | Active et contraignante |
| SUPERSEDED | Remplacee par une decision plus recente (garder pour historique) |
| DEPRECATED | Plus pertinente (contexte change, feature supprimee) |

**Jamais supprimer** — changer le statut et deplacer dans la section "Decisions archivees".

---

<a id="9-bootstrap"></a>
## 9. Bootstrap cross-projet

Quand tu crees un nouveau projet, LESSONS.md est vide. Le skill `/project-bootstrap` injecte les lecons pertinentes de tes autres projets.

### Comment ca marche

```
1. Lire les keywords CARL du nouveau projet (.carl/manifest)
2. Recall Supermemory avec ces keywords
3. Filtrer par tags : [lesson:*], [skill:*], [convention:*], [decision:*]
4. Trier par date (plus recentes d'abord)
5. Verifier le cap LESSONS.md (max 50)
6. Presenter les 10 candidats a l'utilisateur
7. Injecter les lecons confirmees avec tag Heritage
```

### Heritage entries

Les lecons injectees par bootstrap sont marquees :

```markdown
### [api] Rate limiting sur les API tierces
**Quand** on integre une API REST tierce avec throttling
**Faire** implementer backoff exponentiel des le premier appel
**Parce que** decouvert sur STR System — API coupe l'acces 60s apres 429
_Date: 2026-02-15 | Heritage: STR System_
```

Le tag `Heritage:` dans la date identifie la source. Le tag `[api]` reste le domaine technique (pas le projet source) pour la compatibilite avec `/lesson migrate`.

---

<a id="10-workflows"></a>
## 10. Workflows de developpement

### Quel parcours choisir ?

```
Tu recois une tache
     |
     ├── "Je sais exactement quoi faire et comment"
     │   → Parcours rapide (pas de brainstorm)
     │
     ├── "Je sais quoi faire mais pas comment"
     │   → Parcours standard (/ce:brainstorm optionnel)
     │
     └── "Je ne sais pas exactement quoi faire"
         → Parcours complet (/ce:brainstorm obligatoire)
```

**Regle simple :** si la tache a plus d'une interpretation possible,
commence par `/ce:brainstorm`. Le brainstorm repond a **QUOI** construire,
le plan repond a **COMMENT** le construire.

### Parcours rapide — bug fix, tache mecanique

**Quand :** scope clair, 1 fichier, pas de decision d'architecture.

```
/gsd:plan-phase → /pre-flight → /gsd:execute-phase
→ closure → /lesson → /gsd:verify-work → /ce:review
```

### Parcours standard — feature a planifier

**Quand :** feature claire mais implementation a definir, ou requirements un peu flous.

```
/ce:brainstorm (si requirements flous — repond a QUOI)
→ /gsd:plan-phase (repond a COMMENT — lit le brainstorm automatiquement)
→ /pre-flight → /gsd:execute-phase
→ closure → /lesson → /gsd:verify-work → /ce:review
```

**Le brainstorm est optionnel ici**, mais recommande des que :
- Plusieurs approches sont possibles
- Tu n'es pas sur de ce que l'utilisateur veut vraiment
- La feature touche plus de 2 fichiers
- Il y a des tradeoffs a explorer

### Parcours complet — grosse feature multi-phases

**Quand :** grosse feature, architecture a definir, plusieurs phases.

```
/ce:brainstorm (explore QUOI construire — decisions de design)
→ /ce:plan (plan CE strategique — cross-phases, detaille)
→ /gsd:discuss-phase (capturer les decisions specifiques a la phase)
→ /gsd:plan-phase (plan GSD tactique — taches, waves, AC)
→ /pre-flight (4 agents review le plan)
→ /gsd:execute-phase
→ closure → /lesson → /gsd:verify-work → /ce:review → /ce:compound
```

### /ce:brainstorm vs /gsd:plan-phase — la difference

| | /ce:brainstorm | /gsd:plan-phase |
|--|----------------|-----------------|
| **Repond a** | QUOI construire | COMMENT le construire |
| **Output** | `docs/brainstorms/` | `.planning/` |
| **Contenu** | Decisions de design, approches, tradeoffs | Taches, waves, AC, fichiers a modifier |
| **Interaction** | Dialogue — questions une a une | Autonomous — research + plan |
| **Quand skipper** | Requirements clairs et explicites | Jamais (toujours planifier avant d'executer) |

### Chainages automatiques

- Si un **brainstorm** existe (< 7 jours), `/gsd:plan-phase` le lit automatiquement — pas besoin de le re-specifier
- `/ce:plan` detecte aussi les brainstorms existants et les utilise comme input
- La **Rule de consultation** s'applique a toute planification : LESSONS.md → DECISIONS.md → Supermemory → docs/solutions/
- **CARL RULE_8** enforce le recall Supermemory + DECISIONS.md avant toute commande de planification

### Quand NE PAS brainstormer

- Bug fix avec root cause identifiee
- Refactoring mecanique (renommer, deplacer)
- Tache ou l'utilisateur a fourni des AC explicites
- Tache < 50 LOC dans 1 fichier

---

<a id="11-quality-score"></a>
## 11. Quality score et closure

### Le protocole closure (7 etapes)

Apres chaque `/gsd:execute-phase`, le protocole closure est **obligatoire** :

1. Ecrire `.planning/{phase}-{N}-SUMMARY.md` (planifie vs realise)
2. Mettre a jour `memory/MEMORY.md`
3. Logger les deviations
4. Proposer `/lesson` si fix non-trivial
5. Lancer les tests
6. **Quality score** → ecrire dans le SUMMARY.md :
   - AC coverage : X/Y AC satisfaits
   - Deviations : N deviations loguees
   - Verdict : **CLEAN** (0 deviations + tous AC) | **ROUGH** (tout le reste)
   - Si ROUGH → `/lesson` focus "pourquoi le plan n'a pas tenu"
7. **Decision capture** → proposer l'ajout dans DECISIONS.md si des decisions ont ete prises

### Pourquoi le quality score

Sans mesure, les memes patterns de plans mediocres se repetent. Le score CLEAN/ROUGH est **mecanique** (pas de jugement subjectif) et cree une boucle de feedback :

```
Plan mediocre → ROUGH → /lesson "plan trop vague"
→ Prochaine planification consulte cette lecon
→ Plan plus precis → CLEAN
```

---

<a id="12-session-gate"></a>
## 12. Session-gate — 13 checks

Session-gate est un validateur mecanique qui verifie l'etat de MEMORY.md. Tous les checks sont **advisory** — ils ne bloquent jamais la session.

### Les 13 checks

| # | Check | Mode | Type |
|---|-------|------|------|
| 1 | MEMORY.md existe et non vide | START, END | `[ok]`/`[!!]` |
| 2 | Age de la derniere session | START | `[--]` info |
| 3 | Deviations videes | START | `[ok]`/`[!!]` |
| 4 | "Ce qui a ete fait" max 5 | START, END | `[ok]`/`[!!]` |
| 5 | "Prochaine etape" presente | START, END | `[ok]`/`[!!]` |
| 6 | "Derniere session" = aujourd'hui | END | `[ok]`/`[!!]` |
| 7 | MEMORY.md stage avec le code | END | `[ok]`/`[!!]` |
| 8 | LESSONS.md existe et non vide | START, END | `[ok]`/`[!!]` |
| 9 | COT plan block dans les plans modifies | END | `[ok]`/`[!!]` |
| 10 | Qualite LESSONS.md (nombre d'entrees) | END | `[--]` info |
| 11 | DECISIONS.md existe et non vide | START, END | `[ok]`/`[!!]` |
| 12 | Decisions actives > 30 jours | START | `[--]` info |
| 13 | Age derniere lecon capturee | START | `[--]` info |

### Legende

- `[ok]` = check passe
- `[!!]` = action recommandee
- `[--]` = informatif (jamais bloquant)

---

<a id="13-reference-files"></a>
## 13. Reference files — systeme de reference en 4 couches

Le template inclut un systeme de fichiers de reference dans `docs/references/` pour documenter l'architecture, les patterns de code, l'infrastructure, et le codebase.

### Les 4 couches

| Couche | Fichier | Quand le lire |
|--------|---------|---------------|
| L1 — Architecture/Securite | `architecture-security.md` | Planifier une feature, choisir une approche auth/securite |
| L2 — Coding Patterns | `coding-patterns.md` | Ecrire ou reviewer du code |
| L3 — Infra/Services | `services-and-access.md` | SSH, Docker, secrets, MCP, deploy, API keys |
| L3 — Codebase | `codebase-context.md` | Appeler des modules partages, modifier des schemas |

Le fichier `Reference-files-index-routing.md` sert d'index et de decision tree pour savoir quel fichier lire.

### CARL RULE_9 — routing automatique

La regle CARL `RULE_9` enforce la consultation du bon fichier de reference avant de commencer le travail. Claude route automatiquement vers le bon layer selon la tache.

### Regle de mise a jour

Les fichiers de reference doivent etre mis a jour **dans le meme commit** que le changement qu'ils documentent :

- Nouveau secret cree → ajouter dans `services-and-access.md`
- Nouveau MCP ajoute → `services-and-access.md` + `.claude/rules/tool-routing.md`
- Schema modifie → `codebase-context.md`
- Decision d'architecture → `architecture-security.md` + `DECISIONS.md`

### Detection de staleness

Si un nom de secret, un endpoint, ou un ID dans un fichier de reference ne correspond plus a la realite → le fichier est stale. Corriger AVANT tout travail qui en depend.

---

<a id="14-contexte-long"></a>
## 14. Gestion du contexte long

### Le probleme

Claude Code a une fenetre de contexte finie. Quand elle se remplit, les performances se degradent : reponses imprecises, questions deja repondues, perte de fil.

### Les protections du template

```
Protection 1 : Tool routing (.claude/rules/tool-routing.md)
→ Empeche le flooding du contexte par des outputs bruts
→ Table de routing : quel outil pour quelle situation
→ Anti-patterns nommes avec cout en tokens

Protection 2 : Hooks anti-compaction
→ pre-compact.sh sauvegarde l'etat avant la perte
→ session-start.sh re-injecte le contexte apres

Protection 3 : /context-checkpoint
→ Sauvegarde manuelle rapide quand tu sens la degradation
→ < 5 tool calls, < 200 mots

Protection 4 : MCP discipline (CARL RULE_7)
→ Limites obligatoires sur tous les appels MCP
→ Empeche un seul appel de consommer 60K tokens
```

### Quand faire un checkpoint

- Claude repete des questions deja repondues
- Les reponses deviennent vagues ou generiques
- Tu enchaines beaucoup de tool calls dans une meme session
- Tu sens que "ca rame"

**Ne pas continuer une session degradee** — une coupure propre avec MEMORY.md a jour vaut mieux qu'une heure de contexte pourri.

---

<a id="15-faq"></a>
## 15. FAQ et troubleshooting

### "Claude ne lit pas MEMORY.md au demarrage"

Le hook `session-start.sh` devrait l'injecter automatiquement. Verifier :
1. `.claude/settings.json` contient la config des hooks
2. `.claude/hooks/session-start.sh` est executable (`chmod +x`)
3. Relancer Claude Code apres toute modification de settings.json

Fallback : dire a Claude "Lis memory/MEMORY.md" manuellement.

### "CARL ne charge pas le domaine"

1. Verifier que CARL est installe : taper `*carl` dans un prompt
2. Verifier que `.carl/manifest` contient les bons keywords
3. Verifier que le prompt contient un keyword du domaine
4. Redemarrer Claude Code apres l'installation de CARL

### "LESSONS.md atteint le cap de 50"

Lancer `/lesson migrate` :
1. Les 10 plus anciennes lecons sont migrees vers Supermemory
2. Copie dans `docs/solutions/` (backup git)
3. Retirees de LESSONS.md
4. Nouveau compte : N/50

### "Je veux utiliser le template sans CARL"

Ca marche. MEMORY.md, LESSONS.md, DECISIONS.md, les skills, et les hooks fonctionnent sans CARL. Tu perds :
- L'injection automatique des regles dans le prompt
- La promotion lecon → regle CARL
- Les context brackets (FRESH/WARM/HOT)
- Le recall par keywords

### "Je veux utiliser le template sans Supermemory"

Ca marche aussi. Tu perds :
- Le bootstrap cross-projet (`/project-bootstrap`)
- L'archivage des lecons (`/lesson migrate` vers Supermemory)
- Le recall a la planification

Les lecons restent dans LESSONS.md + `docs/solutions/` (backup local).

### "Comment migrer un projet existant vers ce template"

Pas de script de migration automatique (prevu pour une future version). En attendant :

1. Copier les skills de `.claude/skills/` vers le projet existant
2. Copier les hooks de `.claude/hooks/` + `settings.json`
3. Copier les rules de `.claude/rules/`
4. Creer `memory/MEMORY.md` depuis le template
5. Creer `LESSONS.md` depuis le template
6. Creer `DECISIONS.md` depuis le template
7. Creer `.carl/manifest` et `.carl/{domaine}` manuellement

### "Comment ajouter un MCP sans flooder le contexte"

1. Installer le MCP : `claude mcp add <name> ...`
2. Mettre a jour `.claude/rules/tool-routing.md` :
   - Trouver le parametre de limite natif du MCP (`limit`, `maxResults`, `$top`, etc.)
   - Ajouter une ligne dans la table "Discipline MCP"
   - Si pas de parametre natif → ajouter "subagent obligatoire"

---

## Resume visuel

```
┌──────────────────────────────────────────────────────┐
│                  VOTRE PROJET                        │
│                                                      │
│  CLAUDE.md ← regles + workflows                     │
│  MEMORY.md ← etat courant (lu/ecrit chaque session) │
│  LESSONS.md ← lecons (lu chaque session, cap 50)    │
│  DECISIONS.md ← decisions ADR (lu a la planif)       │
│                                                      │
│  .carl/{domaine} ← regles critiques (auto-injectees)│
│  .claude/hooks/ ← anti-compaction (automatique)      │
│  .claude/rules/ ← routing + flywheel (automatique)   │
│  .claude/skills/ ← 7 skills invocables               │
│                                                      │
│  Supermemory ← archive cross-projet (recall)         │
│  docs/solutions/ ← backup git + patterns detailles   │
└──────────────────────────────────────────────────────┘

Boucle d'amelioration :
  Probleme → /lesson → LESSONS.md → CARL rule → Supermemory
  Chaque session, Claude est plus competent que la precedente.
```
