---
forge_pattern: "skill-to-advisor-routing"
category: "governance"
reusability: "high"
maturity: "implemented"
authored: "2026-04-12"
implementation_phase: "24.2 (DCA wiring)"
---

# FORGE Pattern: Skill-to-Advisor Routing

## Problem

Un système multi-skill produit des livrables (architectures, documents, code) qui touchent des domaines spécialisés — conformité légale, sécurité, coûts, accessibilité — sans mécanisme structuré pour consulter l'expert du domaine. Le résultat : des livrables non-conformes produits de bonne foi, ou des blocks arbitraires sans verdict ancré.

Le pattern `skill-to-advisor-routing` résout ce problème en câblant une section canonique dans chaque skill consommateur qui déclare explicitement quand, comment et avec quel payload consulter le skill advisor spécialisé, et comment intégrer le verdict dans le livrable.

## When to use this pattern

- Un ou plusieurs skills spécialisés (conformité, sécurité, coûts) doivent être consultés par de nombreux skills consommateurs
- Le verdict de l'advisor doit être intégré dans le livrable du consommateur, pas retourné séparément
- Les triggers et exclusions varient par domaine consommateur (ex: {{cloud_provider}}-{{identity_platform}}-architect a des triggers différents de {{crm_platform}}-architect pour le même advisor)
- Vous voulez un pattern grep-able : `grep -r "## Consultation {advisor}"` doit lister tous les consommateurs

## When NOT to use this pattern

- L'advisor est consulté par un seul consommateur — câblage direct suffisant
- Le verdict de l'advisor ne modifie jamais le livrable du consommateur — information-only, pas de gate
- L'advisor nécessite une interaction humaine obligatoire — le pattern assume une décision machinale

## Generic architecture

### 1. Advisor skill — structure canonique

L'advisor est un skill autonome avec :

- **Profil clair** : ce qu'il fait ET ce qu'il ne fait pas (évite la confusion avec les skills adjacents)
- **Base de connaissances** : pointeurs vers les sources (fichiers, {{RAG_BACKEND}} collection, APIs) — jamais de contenu dupliqué
- **Processus d'analyse ordonné** : étapes numérotées que l'advisor suit systématiquement
- **Format de sortie strict** : verdict enum (ex: CONFORME / À RISQUE / NON-CONFORME) + justification ancrée dans une source + actions concrètes
- **Règle du verdict obligatoire** : l'advisor tranche toujours — il n'émet jamais de "besoin de plus d'info" sans verdict préliminaire. Si le contexte est incomplet, il applique l'hypothèse défavorable et la documente.

### 2. Section canonique dans chaque skill consommateur

Chaque consommateur porte une section `## Consultation {advisor-name}` avec 4 sous-sections :

```markdown
## Consultation {advisor-name}

{Description en 1-2 phrases de pourquoi ce domaine est consulté depuis ce skill.}

**Quand consulter (obligatoire) :**
- {Trigger spécifique au domaine de ce consommateur}
- {Trigger spécifique}

**Ne pas consulter :**
- {Exclusion — cas où ce consommateur ne touche pas au domaine de l'advisor}

**Pattern de consultation :**
```
1. Produire le livrable ou la recommandation
2. Avant validation, invoquer {advisor} avec payload :
   { "context": "{domain-context-identifier}",
     "scope": "<description>",
     {champs spécifiques au domaine du consommateur} }
3. Intégrer le verdict dans le livrable :
   - VERDICT_A → action A
   - VERDICT_B → action B
   - VERDICT_C → action C
```

**Sources canoniques :**
- `{référence 1}` — {quand lire}
- `{référence 2}` — {quand lire}
```

Le champ `"context"` dans le payload identifie le domaine consommateur : l'advisor peut ainsi adapter sa réponse (ex: `{{cloud_provider}}-{{identity_platform}}-design` vs `{{crm_platform}}-integration` auront des angles différents pour le même verdict).

### 3. Payload minimal standard

```json
{
  "context": "{consumer-domain-identifier}",
  "scope": "{description of what is being designed/built}",
  "data_categories": ["{category}"],
  "data_flows": ["{source} -> {destination}"]
}
```

Chaque consommateur étend ce payload avec ses champs spécifiques (ex: `services`, `jurisdictions`, `workflow_steps`). Le payload est un contrat : l'advisor peut exiger des champs additionnels mais doit toujours produire un verdict même si des champs optionnels manquent.

### 4. Intégration du verdict

| Verdict | Action du consommateur |
|---------|------------------------|
| VERDICT_BLOCK (ex: NON-CONFORME) | Bloquer le livrable. Documenter le verdict. Proposer les corrections. Re-consulter après redesign. |
| VERDICT_CONDITIONAL (ex: À RISQUE) | Inclure les mitigations dans le livrable. Citer le verdict et les actions requises. |
| VERDICT_PASS (ex: CONFORME) | Citer la justification dans le livrable. Procéder. |

### 5. Grounding de l'advisor

L'advisor doit ancrer chaque verdict dans une source vérifiable :

- **Fichiers de référence** : lire le fichier source directement si la collection est indisponible
- **Vector store** : query avec filtre `kind` pour éviter les faux positifs sémantiques
- **Règle anti-invention** : ne jamais citer un article ou un standard sans avoir vérifié le libellé dans la source canonique

```
query(
  collection: "{knowledge-collection}",
  query_texts: ["{concept}"],
  where: { "kind": "{source-type}" },
  n_results: 5
)
```

## Reuse guide (how to apply to any repo)

1. **Identifier le domaine advisor** — compliance, security, cost, accessibility, API contract. Un domaine = un advisor skill.

2. **Définir le format de verdict** — 2-3 valeurs enum couvrant le spectre (block/conditional/pass). Plus de 3 valeurs crée de l'ambiguïté.

3. **Écrire l'advisor skill** — profil, base de connaissances (pointeurs), processus d'analyse, format de sortie strict, règle du verdict obligatoire.

4. **Identifier les consommateurs** — tous les skills qui produisent des livrables touchant le domaine de l'advisor.

5. **Définir triggers et exclusions par consommateur** — les triggers sont toujours domain-specific : un skill {{CLOUD_PROVIDER}} a des triggers {{CLOUD_PROVIDER}}, un skill {{CRM_PLATFORM}} a des triggers {{CRM_PLATFORM}}, même pour le même advisor.

6. **Câbler la section canonique** — même heading `## Consultation {advisor}` dans chaque consommateur. Grep-able par design.

7. **Standardiser le payload** — champ `context` obligatoire, champs additionnels par consommateur. Documenter le schéma dans l'advisor.

8. **Documenter la propagation** — le skill advisor documente la liste de ses consommateurs dans sa section `When to Load` ou équivalent.

## Extension points

- **Multiple advisors** : un consommateur peut consulter plusieurs advisors (ex: compliance + security). Chaque advisor a sa section canonique distincte.
- **Advisor chain** : un advisor peut lui-même consulter un autre advisor (ex: compliance-advisor consulte legal-precedent-advisor). Limiter à 2 niveaux pour éviter les boucles.
- **Verdict caching** : si le même scope + payload a déjà reçu un verdict dans la session, le réutiliser sans re-consulter (idempotence).
- **Rollup** : un skill orchestrateur agrège plusieurs verdicts d'advisors différents pour produire un verdict global (ex: `pre-flight` = compliance + security + architecture).

## Consultation data-compliance-advisor

{1-2 phrases contexte domaine}

**Quand consulter (obligatoire) :**
- {trigger 1 spécifique au domaine}

**Ne pas consulter :**
- {exclusion 1}

**Pattern de consultation :**
```
1. Rédiger le design ou la recommandation
2. Avant validation, invoquer data-compliance-advisor avec payload :
   { "context": "{domain-identifier}",
     "scope": "<description>",
     "jurisdictions": ["QC", "CA"],
     "data_categories": [<catégories>],
     "data_residency": "canada",
     {champs additionnels} }
3. Intégrer le verdict :
   - NON-CONFORME → bloquer + proposer corrections
   - À RISQUE → intégrer les mitigations
   - CONFORME → citer la justification
```

**Sources canoniques :**
- `docs/references/frameworks/{{compliance_framework_primary}}.md`
- `docs/references/frameworks/{{compliance_framework_health}}.md`
- `docs/references/frameworks/{{compliance_framework_federal}}.md`
- `data-compliance-advisor/references/integration-patterns.md`
```

### Références

- Advisor skill : `.claude/skills/data-compliance-advisor/SKILL.md`
- Patterns d'invocation détaillés : `.claude/skills/data-compliance-advisor/references/integration-patterns.md`
- Sources légales : `docs/references/frameworks/`

## Related FORGE patterns

- `upstream-source-watcher` — maintient à jour les sources que l'advisor consulte ({{compliance_framework_primary}}, {{compliance_framework_health}}, {{compliance_framework_federal}})
- `artifact-staleness-watcher` — même philosophie de "frontmatter as first-class metadata" appliquée aux artefacts
- `supply-chain-audit-triad` — pattern advisor parallèle pour les dépendances externes (3 agents simultanés)
