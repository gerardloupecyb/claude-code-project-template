# Flywheel — instructions post /ce:compound

## Étape 1 — Classifier le pattern appris

**Ponctuel**
: Spécifique à ce projet, peu probable ailleurs
: Action : docs/solutions/ seulement

**Réutilisable**
: S'applique sur plusieurs projets du même domaine
: Action : docs/solutions/ + domaine CARL

**Cross-projet**
: Change ta façon de travailler en général
: Action : docs/solutions/ + domaine CARL + Supermemory

---

## Étape 2 — Documenter dans docs/solutions/

Toujours, quelle que soit la classification.
Créer `docs/solutions/{domaine}/{pattern}.md` :

```markdown
# [Titre du pattern]
## Contexte
## Problème
## Solution (+ code si applicable)
## Anti-patterns
## Règle distillée — "Toujours X quand Y."
## Classification : ponctuel / réutilisable / cross-projet
## Référence — session source : [date]
```

Domaines disponibles : {{SOLUTION_DOMAINS}}

---

## Étape 3 — Si réutilisable ou cross-projet : domaine CARL (AUTOMATISÉ)

Après avoir documenté dans docs/solutions/, Claude DOIT proposer l'ajout CARL :

1. Identifier le numéro de la prochaine règle disponible dans `.carl/{{CARL_DOMAIN}}`
2. Formuler la règle distillée (1-2 lignes, actionnable, format `{DOMAIN_UPPER}_RULE_{N}=...`)
3. Présenter la règle à l'utilisateur pour validation
4. Si validé, ajouter dans `.carl/{{CARL_DOMAIN}}`
5. Si le pattern concerne un sous-domaine distinct avec 3+ règles : proposer un nouveau domaine

Ne PAS attendre que l'utilisateur pense à demander l'ajout CARL.
La proposition est automatique dès que la classification est "réutilisable" ou "cross-projet".

---

## Étape 4 — Si cross-projet : Supermemory (AUTOMATISÉ)

Après l'étape CARL, si classification = cross-projet, Claude DOIT proposer la sauvegarde Supermemory :

1. Formuler l'entrée au format de la Règle #5 (tag + contexte + problème + solution + règle)
2. Présenter à l'utilisateur pour validation
3. Si validé, sauvegarder via MCP supermemory

Ne PAS attendre que l'utilisateur pense à demander la sauvegarde Supermemory.
La proposition est automatique dès que la classification est "cross-projet".

---

## Étape 5 — Commit

Inclure dans le même commit :

- Code produit
- `memory/MEMORY.md` mis à jour
- `docs/solutions/{domaine}/{pattern}.md` si nouveau
- `.carl/{{CARL_DOMAIN}}` si enrichi

Message : `feat: [ce qui a été construit] / docs: pattern {nom} → {domaine}`
