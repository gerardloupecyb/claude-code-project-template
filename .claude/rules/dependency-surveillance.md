---
paths:
  - "docs/audits/cve-alerts/**/*"
  - "docs/audits/cve-scan-latest.md"
  - ".github/dependabot.yml"
  - ".github/workflows/osv-scan.yml"
  - "docs/standards/patch-management-standard.md"
  - "scripts/module-inventory.json"
  - "docs/architecture/templates/cve-triage-template.md"
---

# Dependency Surveillance Watch (DSW)

> Source canonique du monitoring continu des dépendances.
> Path-scoped : ne se charge que quand Claude touche un artefact CVE, la config Dependabot/OSV, ou le patch management standard.
> Complète `supply-chain-audit.md` (gate install-time).

## Principe

SCAG couvre l'install-time. DSW couvre le run-time — détection continue des CVE sur les dépendances déjà installées.
Sans DSW, les dépendances vieillissent silencieusement avec des vulnérabilités connues.

## Stack de surveillance (2 couches + 1 extension {{SCRIPTING_LANG}})

### Couche 1 — Dependabot (always-on, GitHub-native)

- Config : `.github/dependabot.yml`
- Scope : Python (`pyproject.toml`, `requirements*.txt`), GitHub Actions
- Fréquence : quotidienne (Dependabot default)
- Output : PRs automatiques avec description CVE + chemin de fix
- Auto-merge : **patch only** (x.y.Z) si CI green et dep déjà auditée par SCAG
- Minor/major : review humain obligatoire. Major → re-trigger SCAG.

### Couche 2 — OSV-Scanner (cron hebdomadaire, belt-and-suspenders)

- Config : `.github/workflows/osv-scan.yml`
- Fréquence : dimanche 02:00 UTC (cron)
- Source : OSV.dev (agrège GitHub Advisory DB + PyPI + NVD + plusieurs sources)
- Output : `docs/audits/cve-scan-latest.md` committé automatiquement
- Commande manuelle : `/cve-scan` avant commit risqué
- Pourquoi en plus de Dependabot : bases CVE différentes, délai de 24-72h entre sources, couverture stéréo

### Extension {{SCRIPTING_LANG}} — couverture modules PS Gallery

- Les modules {{SCRIPTING_LANG}} Gallery sont des packages NuGet
- `scripts/module-inventory.json` généré depuis les tenants via `Get-InstalledModule | Select Name, Version`
- OSV-Scanner peut consommer ce manifeste au format NuGet
- Complément : query MSRC Security Update Guide API pour Microsoft.Graph.*, ExchangeOnline, PnP
- Intégré dans le même cron `.github/workflows/osv-scan.yml`

## Flow CVE détectée

```
DSW détecte CVE-XXXX-YYYY sur {package} v{version}
   ↓
Fichier docs/audits/cve-alerts/{CVE-ID}.md créé (template: cve-triage-template.md)
   ↓
Triage automatique :
  - Sévérité (CVSS score)
  - Exploitability (attack vector, complexity)
  - Exposure chez {{PROJECT}} (le package est-il utilisé dans le chemin vulnérable ?)
   ↓
Décision :
  ├── Bump patch/minor sans breaking → PR automatique (Dependabot)
  ├── Bump majeur → re-trigger SCAG (nouvelle surface d'attaque)
  ├── Pas de fix upstream → DECISIONS.md, risque accepté, mitigation documentée
  └── Fix upstream mais breaking → DECISIONS.md, timeline de migration
```

## SLA par sévérité

Défini dans `docs/standards/patch-management-standard.md`. Résumé :

| Sévérité | CVSS | SLA |
|---|---|---|
| Critical | 9.0-10.0 | 24 heures |
| High | 7.0-8.9 | 7 jours |
| Medium | 4.0-6.9 | 30 jours |
| Low | 0.1-3.9 | 90 jours |

## Artefacts produits

```
docs/audits/cve-alerts/{CVE-ID}.md     (triage par CVE)
docs/audits/cve-scan-latest.md         (dernier scan OSV complet)
```

Template : `docs/architecture/templates/cve-triage-template.md`

## Queryable via {{RAG_BACKEND}}

Les fichiers `docs/audits/cve-alerts/*.md` sont indexés dans la collection `governance-ops` (kind: `cve-alert`) par le hook `post-knowledge-sync.sh`. Queryable via :

```
chroma_query_documents collection=governance-ops where={"kind": "cve-alert"}
```

## Ce qui ne va pas ici

- Gate d'audit à l'install → `.claude/rules/supply-chain-audit.md`
- Patch management complet → `docs/standards/patch-management-standard.md`
- Architecture supply chain → `docs/architecture/security/supply-chain-controls.md`
