---
forge_pattern: "supply-chain-audit-triad"
category: "security"
reusability: "high"
maturity: "implemented"
authored: "2026-04-12"
implementation_phase: "SCAG (fb46db0)"
---

# FORGE Pattern: Supply Chain Audit Triad

## Problem

Tout dépendance externe exécutable (package, MCP server, CLI tool, git submodule) introduit une surface d'attaque. Les outils classiques (Dependabot, OSV-Scanner) couvrent les CVE connus mais pas les menaces sémantiques (logique malicieuse, SSRF implanté, secret hardcodé) ni les scénarios offensifs construits par un adversaire. Un seul outil ou un seul point de vue ne suffit pas.

Le pattern `supply-chain-audit-triad` résout ce problème en imposant 3 agents d'audit en parallèle — mécanique, sémantique, offensif — avant toute installation. Le verdict est conditionné par les 3 agents simultanément, pas l'un après l'autre.

## When to use this pattern

- Nouveau package Python/Node/Ruby ajouté à un manifest de dépendances
- Nouveau MCP server configuré dans l'environnement agent
- Nouveau CLI tool externe ajouté au workflow
- Nouveau git submodule ou skill cloné depuis un repo externe
- Script d'install tiers via `curl | sh`
- Bump majeur (X.0.0) d'une dépendance déjà présente

## When NOT to use this pattern

- Bump patch/minor (x.Y.z → x.Y.z+1) d'une dépendance déjà auditée — le CVE-scanner continu (DSW) couvre ce cas
- Dépendances pré-approuvées dans une allowlist explicite (ex: packages de l'éditeur principal, tier-1 providers)
- Dépendances internes (même organisation, repo privé audité séparément)

## Generic architecture

### 1. Trigger et detection

Le gate se déclenche sur tout ajout de dépendance exécutable externe. La detection peut être :

- **Hook pre-commit** : diff du manifest (`package.json`, `pyproject.toml`, `.mcp.json`, `.gitmodules`)
- **Agent pre-action** : règle path-scoped qui s'injecte quand Claude touche un fichier de dépendances
- **CI gate** : job dédié avant merge

La detection doit distinguer : ajout vs bump minor vs bump major vs suppression.

### 2. Allowlist — exemptions pré-approuvées

Avant de déclencher la triade, vérifier l'allowlist :

```json
{
  "approved": [
    { "name": "package-name", "publisher": "org", "reason": "tier-1 provider", "approved_at": "YYYY-MM-DD" }
  ]
}
```

Si la dépendance est dans l'allowlist ET la version est couverte → skip SCAG, passer au monitoring continu.
Si bump majeur d'un package allowlisté → re-trigger SCAG (nouvelle surface d'attaque).

### 3. La triade — 3 agents en parallèle

Les 3 agents s'exécutent **simultanément** (foreground) — leur résultat conditionne la décision. L'ordre n'a pas d'importance ; tous les 3 doivent compléter avant le verdict consolidé.

| Agent | Rôle | Focus |
|---|---|---|
| `sast-scanner` | **Mécanique** | Secrets hardcodés (gitleaks), patterns CWE/OWASP (Semgrep), dépendances transitives vulnérables (OSV lookup) |
| `security-sentinel` | **Sémantique** | SSRF, auth bypass, input validation, trust boundaries, logique de sécurité globale |
| `adversarial-reviewer` | **Offensif** | Construction active de scénarios d'attaque — comment un attaquant exploiterait ce package |

Chaque agent retourne un rapport structuré :

```markdown
## {Agent} Findings — {package}@{version}

**Verdict partiel** : CLEAN | FINDINGS

**Findings** (si non-clean) :
- [{sévérité: CRITICAL|HIGH|MEDIUM|LOW}] {description} — {CWE ou pattern}
  Mitigation possible : {oui/non} — {si oui: comment}

**Scope inspecté** : {ce que l'agent a analysé}
```

### 4. Verdict consolidé — decision gate

Le lead consolide les 3 rapports selon la règle :

```
si tous les 3 agents reviennent CLEAN → APPROVE (auto-signe)
si findings uniquement non-critiques + mitigation documentée → CONDITIONAL (humain requis)
si finding critique (CRITICAL/HIGH sans mitigation) → REJECT (humain requis)
```

**Règle stricte** : un seul finding CRITICAL suffit pour REJECT, même si les 2 autres agents sont CLEAN.

### 5. Artefacts produits

```
docs/audits/dependencies/{package}-v{version}-{YYYY-MM-DD}/
  ├── AUDIT.md           — verdict consolidé, résumé des 3 agents, actions requises
  ├── sast-findings.md   — output sast-scanner (complet)
  ├── sentinel-findings.md — output security-sentinel (complet)
  ├── adversarial.md     — output adversarial-reviewer (complet)
  └── DECISION.md        — approve / conditional / reject + signataire + date
```

DECISION.md est le fichier de référence pour les audits futurs (bump check, refresh annuel).

### 6. Post-approve — co-update obligatoire

À chaque APPROVE (auto ou humain) :
- Mettre à jour l'inventaire des intégrations (si MCP/tool)
- Mettre à jour les endpoints/accès (si nouveau service)
- Mettre à jour les caps et patterns MCP (si nouveau MCP)

Ces co-updates garantissent que l'audit est traçable dans le contexte complet du projet.

### 7. Monitoring continu post-install

L'audit SCAG est point-in-time. Pour les CVE post-install :

- **Dependabot** : alertes automatiques sur le manifest
- **OSV-Scanner cron** : scan périodique (hebdomadaire recommandé)
- **Refresh SCAG** : déclenché sur signal externe (CVE critique, maintainer compromis, fork hostile) ou tous les 12 mois (`sast-scanner` seul en refresh minimal)

## Reuse guide (how to apply to any repo)

1. **Définir les triggers** — quels fichiers déclenchent la triade ? (manifests, config tool, submodules)

2. **Créer l'allowlist** — lister les publishers pré-approuvés avec justification. Ne pas l'ometttre : sans allowlist, la triade bloque les packages évidents et perd de la crédibilité.

3. **Câbler le sast-scanner** — `gitleaks` pour les secrets, `semgrep` avec un ruleset CWE/OWASP, `osv-scanner` ou équivalent pour les CVE connus.

4. **Câbler le security-sentinel** — prompt orienté sémantique : "Identifie les patterns d'authentification, boundaries de confiance, validation d'entrées dans ce package."

5. **Câbler l'adversarial-reviewer** — prompt offensif : "Construis 3 scénarios d'attaque concrets exploitant ce package dans notre contexte."

6. **Définir la decision gate** — seuil de sévérité pour APPROVE/CONDITIONAL/REJECT. Documenter : tous les 3 clean = auto-approve est un choix délibéré, pas une absence de règle.

7. **Créer l'arborescence d'artefacts** — chemin fixe, nommage reproductible (`{package}-v{version}-{date}`).

8. **Intégrer dans le workflow de dev** — hook, CI gate, ou règle path-scoped selon la maturité du projet.

## Extension points

- **4e agent** : `license-checker` pour vérifier la compatibilité de licence (GPL contamination, AGPL, etc.)
- **SBOM integration** : à chaque APPROVE, ajouter l'entrée au Software Bill of Materials
- **Scoring pondéré** : plutôt que CRITICAL = reject automatique, un score pondéré (CRITICAL×3 + HIGH×1 vs seuil) peut être plus nuancé pour certains domaines
- **Bypass documenté** : mécanisme `--emergency-skip` avec justification obligatoire + alerte équipe + re-audit dans 48h
- **Refresh différentiel** : pour un bump majeur, ne re-scanner que les fichiers modifiés vs la version précédente (si l'audit de la version précédente est disponible)

## Related FORGE patterns

- `skill-to-advisor-routing` — même philosophie de gate structuré avec verdict enum, mais pour les domaines métier (compliance, etc.) plutôt que la sécurité des dépendances
- `upstream-source-watcher` — monitoring continu des sources amont (complémentaire : SCAG couvre l'install, USW couvre la dérive dans le temps)
