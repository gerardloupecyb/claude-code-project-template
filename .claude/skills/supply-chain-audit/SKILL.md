# Supply-Chain Audit — Skill

> Orchestre le pipeline IBA + triad (sast-scanner + security-sentinel + adversarial-reviewer) sur un package externe avant introduction dans le repo.

## Trigger

`/supply-chain-audit <target> [--package <name>] [--version <version>]`

- `<target>` : chemin vers le repo/package cloné localement (ex: `/tmp/graphify-audit-2`)
- `--package` : nom du package PyPI/npm (ex: `graphifyy`)
- `--version` : version évaluée (ex: `0.3.27`)

## Prérequis

Le package doit être cloné localement avant invocation. Ce skill ne fait PAS de `git clone` ni de `pip install` — il audite du code déjà présent sur disque.

## Workflow

### Step 0 — Validation des inputs

- Vérifier que `<target>` existe et contient du code
- Vérifier que `--package` et `--version` sont fournis
- Créer le dossier d'output : `docs/audits/dependencies/{package}-v{version}-{YYYY-MM-DD}/`
- Charger `.claude/rules/protected-files.yaml` et `.claude/skills/supply-chain-audit/patterns/iba-patterns.yaml`

### Step 1 — Install Behavior Audit (IBA) — mécanique, déterministe

**Type** : Step déterministe (Grep + Read), **pas un agent LLM**.

**Objectif** : Détecter les comportements d'install dangereux avant de dépenser les tokens du triad.

**Procédure** :

1. Lister les fichiers à scanner dans `<target>/` selon `scan_file_types` de `iba-patterns.yaml`
2. Pour chaque classe de pattern (7 classes : governance_modification, global_user_config, git_hook_install, auto_install_no_pin, shell_exec_unsandboxed, shell_config_modification, slopsquatting) :
   - Si la classe a un champ `helper:` (ex: slopsquatting) : invoquer le helper script avec chaque candidat (package name pour slopsquatting, extrait via parsing de requirements*.txt / package.json / pyproject.toml). Le helper retourne un verdict JSON `{package, verdict, distance, nearest, reason}`. Mapper `verdict: high` vers un finding de sévérité `high`.
   - Sinon (classes 1-6) : exécuter `Grep` avec le `patterns:` de la classe sur la liste de fichiers filtrée par `scan_file_types`.
   - Pour chaque match/verdict : extraire file, line, 5 lignes de contexte avant/après (ou équivalent pour les verdicts helper).
3. Pour chaque finding sur un path qui ressemble à un fichier protégé :
   - Cross-référencer avec `protected-files.yaml` (classe critical/high/medium)
   - Appliquer la sévérité correspondante
4. Pour chaque finding, vérifier le bloc `whitelist` dans `protected-files.yaml` :
   - Si match → dégrader la sévérité à `Info`
5. Compter les findings par sévérité
6. Déterminer le verdict IBA :
   - **CLEAN** : 0 findings
   - **LOCAL** : findings uniquement dans le package dir (pas de path sortant)
   - **USER_CONFIG** : findings touchent ~/.bashrc etc. (pas de fichier de gouvernance)
   - **GOVERNANCE_VIOLATION** : ≥ 1 critical sur un fichier de `protected-files.yaml` class critical
   - **EXTREME_VIOLATION** : > 10 critical findings
7. Écrire `iba-findings.md` dans le dossier d'output (template : `docs/architecture/templates/iba-findings-template.md`)

**Décision IBA** :

| Verdict | Action |
|---|---|
| CLEAN / LOCAL / USER_CONFIG | Procède à Step 2 (triad) |
| GOVERNANCE_VIOLATION | Procède à Step 2 (triad) mais **force Conditional/Reject au Step 4** |
| EXTREME_VIOLATION | **Court-circuit** — skip Step 2, saute directement à Step 4 avec verdict Reject |

### Step 2 — Triad d'audit (3 agents en parallèle, foreground)

Lancer les 3 agents **simultanément** via le tool `Agent` :

**Agent 1 — sast-scanner** (compound-engineering)
```
Contexte : audit supply-chain du package {package} v{version}
Cible : {target}/
Focus : gitleaks (secrets hardcodés), Semgrep (CWE/OWASP patterns)
Output : résumé structuré avec sévérité par finding
```

**Agent 2 — security-sentinel** (compound-engineering)
```
Contexte : audit supply-chain du package {package} v{version}
Cible : {target}/
Focus : SSRF, auth, input validation, boundaries, exécution de code,
        appels réseau non documentés, accès filesystem, shell=True, eval/exec
Output : résumé structuré avec sévérité par finding
```

**Agent 3 — adversarial-reviewer**
```
Contexte : audit supply-chain du package {package} v{version}
Cible : {target}/
Focus : construire activement des scénarios d'attaque. Comment un attaquant
        pourrait-il abuser de ce package une fois installé dans notre repo ?
        Considérer : prompt injection via labels, git hook code execution,
        MCP server abuse, data exfiltration, dependency confusion
Output : scénarios d'attaque classés par plausibilité et impact
```

### Step 3 — Consolidation

Écrire les 5 artefacts dans le dossier d'output :
1. `iba-findings.md` — output du Step 1 (mécanique)
2. `sast-findings.md` — output brut agent 1
3. `sentinel-findings.md` — output brut agent 2
4. `adversarial.md` — output brut agent 3
5. `AUDIT.md` — verdict consolidé (template : `docs/architecture/templates/dependency-audit-template.md`)

**Scoring rubric contract (D-07).** Every finding in `iba-findings.md`, `sast-findings.md`, `sentinel-findings.md`, `adversarial.md`, AND `AUDIT.md` MUST emit both categorical and numeric severity per `docs/references/security-review/scoring-rubric.md`. Output line format:

```
- **{Finding title}** — {Categorical} ({numeric band}) — rubric: docs/references/security-review/scoring-rubric.md#per-cwe-example-bands
  {description}
```

Slopsquatting findings default to **High (7)** per rubric per-CWE example band. Composite severity applies when a slopsquatting finding chains with another IBA class (e.g. slopsquat + auto_install_no_pin → Critical per rubric `#composite-severity-for-chained-findings`).

### Step 4 — Décision

| Condition IBA | Condition triad | Verdict | Signature |
|---|---|---|---|
| CLEAN / LOCAL | 3 agents 100% clean | **Approve** | Auto-sign Claude |
| CLEAN / LOCAL | Finding(s) non-critiques | **Conditional** | Humain obligatoire |
| CLEAN / LOCAL | Finding(s) critiques | **Reject** | Humain obligatoire |
| USER_CONFIG | 3 agents 100% clean | **Conditional** (warning) | Humain obligatoire |
| GOVERNANCE_VIOLATION | Any | **Conditional ou Reject** (forcé) | Humain obligatoire |
| EXTREME_VIOLATION | Skipped | **Reject** (auto) | Humain obligatoire pour override |

### Step 5 — Post-approve (si Approve ou Conditional validé)

**5a. Créer le marker d'approbation pour le hook pre-tool-use :**

```bash
mkdir -p .skill-locks && touch .skill-locks/scag-approved
```

Ce marker est session-scoped (gitignored). Il est consommé en **one-shot** par `pre-tool-use.sh` au moment de l'install : le hook le lit, le supprime, et laisse passer la commande. Chaque install requiert son propre cycle SCAG + marker.

**5b. Rappeler les mises à jour obligatoires post-install** (ne pas les exécuter automatiquement) :
- `.claude/integrations.md`
- `docs/codebase/services-and-access.md`
- `.claude/rules/tool-routing.md` (si MCP)
- Ajout à `.github/dependabot.yml` scope (si package Python/Node)

## Ce que ce skill ne fait PAS

- N'installe pas le package
- Ne modifie pas `.mcp.json` ni `settings.json`
- Ne fait pas de monitoring CVE continu (c'est DSW)
- Ne fait pas de `git clone` (le package doit être cloné avant)

## Classification d'exemption

Si le package est listé dans `.claude/allowlists/mcp-preapproved.json`, informer l'utilisateur que SCAG peut être skippé et demander confirmation.

## Références

- Rule SCAG : `.claude/rules/supply-chain-audit.md`
- Protected files : `.claude/rules/protected-files.yaml`
- IBA patterns : `.claude/skills/supply-chain-audit/patterns/iba-patterns.yaml`
- Architecture : `docs/architecture/security/supply-chain-controls.md`
- Pattern solution : `docs/solutions/security/supply-chain-audit-pattern.md`
- First dogfood : `docs/solutions/security/supply-chain-audit-graphify-dogfood.md`
