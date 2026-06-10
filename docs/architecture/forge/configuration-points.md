---
title: "FORGE — Configuration Points"
status: active
last_verified: 2026-04-12
owner: {{OWNER}}
phase: 24
slug: forge
---

# FORGE — Configuration Points

> Points de customisation qu'un nouveau projet doit adapter apres adoption du template FORGE.
> Organises par priorite : P0 (obligatoire au bootstrap), P1 (premiere session), P2 (quand le domaine est actif).

---

## P0 — Obligatoire au bootstrap (avant premiere session)

| Point | Fichier | Valeur {{PROJECT}} | Ce qu'il faut changer |
|---|---|---|---|
| Nom du projet | `CLAUDE.md` | "{{PROJECT}}" | Nom du nouveau projet |
| CARL domain | `.carl/{domain}` | `{{project}}tech` | Nouveau nom de domain + rules vides |
| CARL manifest | `.carl/manifest` | Pointe vers `{{project}}tech` | Pointer vers le nouveau domain |
| Git remote | `.git/config` | `{{owner}}{{project}}cyb/{{project}}-technologies` | Nouveau repo |
| {{RAG_BACKEND}} collections | `config/{{rag_backend}}-registry.json` | 4 collections (reference, knowledge, planning, governance-ops) | Memes collections, reset les paths |
| MEMORY.md | `memory/MEMORY.md` | Journal {{PROJECT}} | Vider, garder la structure |
| DECISIONS.md | `DECISIONS.md` | 25 decisions {{PROJECT}} | Vider |
| LESSONS.md | `LESSONS.md` | 50 lecons {{PROJECT}} | Vider |

## P1 — Premiere session (configurer les domaines actifs)

| Point | Fichier | Valeur {{PROJECT}} | Ce qu'il faut changer |
|---|---|---|---|
| Domaines proteges | `.claude/rules/skill-gate.md` | {{cloud_provider}}, {{WORKFLOW_ENGINE}}, {{crm_platform}} | Domaines du nouveau projet (ex: aws, terraform, rails) |
| Hook domain patterns | `.claude/hooks/pre-tool-use.sh` | Regex {{cloud_provider}}/{{WORKFLOW_ENGINE}}/{{crm_platform}} | Regex des nouveaux domaines |
| MCP mutations gate | `.claude/hooks/pre-mcp-gate.sh` | {{WORKFLOW_ENGINE}}-mcp, prod-{{crm_platform}}-mcp | MCP prod du nouveau projet |
| MCP inventory | `.claude/integrations.md` | 14 MCP servers | MCP du nouveau projet |
| MCP limits | `.claude/rules/tool-routing.md` | Limites par MCP {{PROJECT}} | Limites par MCP du projet |
| MCP allowlist | `.claude/allowlists/mcp-preapproved.json` | 9 MCP pre-approuves | MCP pre-approuves du projet |
| Protected files | `.claude/rules/protected-files.yaml` | Fichiers {{PROJECT}} | Fichiers du projet |
| Settings hooks | `.claude/settings.json` | PreToolUse/PostToolUse matchers | Adapter si domaines changent |

## P2 — Quand le domaine est actif (configurer au besoin)

| Point | Fichier | Valeur {{PROJECT}} | Ce qu'il faut changer |
|---|---|---|---|
| Domain skills | `.claude/skills/{domain}/` | {{cloud_provider}}-{{identity_platform}}-architect, {{WORKFLOW_ENGINE}}-*, {{crm_platform}}-* | Skills du domaine du projet |
| Model routing | `.claude/rules/router-rules.md` | Codex + Gemini + OpenRouter | Modeles et transports du projet |
| Dependabot ecosystems | `.github/dependabot.yml` | Python, GitHub Actions | Ecosystemes du projet |
| OSV-Scanner scope | `.github/workflows/osv-scan.yml` | Recursive scan root | Scope du projet |
| Patch SLA values | `docs/standards/patch-management-standard.md` | Critical 24h, High 7d, Medium 30d, Low 90d | SLA du projet (peut garder les memes) |
| Graphify scope | Post-commit hook + session-start | `scripts/` initial | Scope du projet |
| {{WORKFLOW_ENGINE}} dev/prod | `.carl/` RULE_15 | dev-{{WORKFLOW_ENGINE}} + prod-{{WORKFLOW_ENGINE}} | Instances du projet |
| Writer skills | `.claude/skills/` | {{project}}-{{scripting_lang}}-script-writer | Writer specifique au stack du projet |

---

## Defaults sensibles (valeurs par defaut du template)

Le template devrait fournir des defaults fonctionnels pour un projet vide :

| Point | Default template | Raison |
|---|---|---|
| Domaines skill-gate | Aucun domaine protege | Pas de gate par defaut — ajouter au besoin |
| MCP inventory | Aucun MCP | MCP sont project-specific |
| {{RAG_BACKEND}} | 4 collections vides | Structure prete, contenu vide |
| CARL rules | 3 rules fondamentales (flywheel consult, flywheel document, credentials safety) | Minimum viable |
| Hooks | Tous actifs avec patterns vides | Hooks fonctionnels, domain detection desactivee |
| Patch SLA | Critical 24h, High 7d, Medium 30d, Low 90d | Industrie standard |
| CLAUDE.md | Template avec pointeurs | 10 lignes, structure seule |

---

## Validation post-bootstrap

Script ou checklist a executer apres bootstrap pour verifier que tous les P0 sont configures :

```
[ ] CLAUDE.md pointe vers le bon projet
[ ] .carl/{domain} existe et contient au moins RULE_0
[ ] memory/MEMORY.md est vide mais structure presente
[ ] config/{{rag_backend}}-registry.json est reset
[ ] .gitignore inclut les patterns FORGE standard
[ ] session-start.sh s'execute sans erreur
[ ] pre-tool-use.sh s'execute sans erreur (aucun domaine bloque)
```
