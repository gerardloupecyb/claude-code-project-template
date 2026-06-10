---
forge_pattern: "dual-mode-skill"
category: "orchestration"
reusability: "high"
maturity: "implemented"
authored: "2026-04-12"
implementation_phase: "24.1 (prepare-phase dual-mode)"
---

# FORGE Pattern: Dual-Mode Skill

## Problem

Un skill d'orchestration multi-étapes peut être invoqué dans deux contextes radicalement différents : avec un humain disponible pour valider les checkpoints (feature complexe, phase sensible), ou dans un pipeline autonome où aucune interruption n'est possible (CI, session nocturne, enchaînement automatique de phases). Un skill conçu uniquement pour l'interactif bloque les pipelines ; un skill purement autonome prive l'humain de ses points de contrôle.

Le pattern `dual-mode-skill` résout ce problème en définissant un flag `--autonomous` qui transforme le comportement du skill sans dupliquer sa logique : même séquence d'étapes, mais les checkpoints humains deviennent des agents automatiques et la sortie passe de step-by-step à un rapport consolidé.

## When to use this pattern

- Le skill orchestre plusieurs sous-skills ou agents en séquence avec des étapes optionnelles
- Certaines étapes nécessitent normalement une décision humaine (skip/proceed) mais peuvent être automatisées avec des heuristiques raisonnables
- Le skill est appelé à la fois dans des workflows manuels (session interactive) et dans des pipelines autonomes (chaîne de phases, CI, scheduler)
- La sortie en mode autonome doit être consommable par machine (rapport structuré vs conversation)

## When NOT to use this pattern

- Skill avec une seule étape — pas besoin de deux modes
- Toutes les étapes nécessitent un jugement humain irremplaçable (ex: review subjectif de design)
- Le skill est toujours appelé dans le même contexte (toujours interactif ou toujours autonome)

## Generic architecture

### 1. Flag d'activation

```
/{skill-name} {args}           → interactive mode (default)
/{skill-name} {args} --autonomous → autonomous mode
```

Le flag est positionnel ou nommé. Pas de valeur — présence/absence suffit.

### 2. Étapes optionnelles vs obligatoires

Classifier chaque étape du skill selon son statut en mode interactif :

| Type | Mode interactif | Mode autonome |
|---|---|---|
| **Obligatoire** | Exécution automatique | Idem — pas de changement |
| **Optionnel (humain décide)** | Question → [Oui/Skip] | Agent auto-run — pas de question |
| **Optionnel (humain valide)** | Question → [Continuer/Arrêter] | Toujours continuer (seuil configurable) |
| **Parallèle (partiel)** | Certaines étapes en parallèle | Groupe parallèle étendu |

En mode autonome, les étapes optionnelles s'exécutent systématiquement — la politique par défaut est "go" sauf finding bloquant.

### 3. Gestion des checkpoints

**Mode interactif** — 1 question, 2 choix :

```
Étape {N} optionnelle. Exécuter ? [Oui (recommandé) / Skip]
```

Maximum 4 checkpoints par skill pour ne pas sur-interrompre l'utilisateur. Si une étape optionnelle est refusée une fois dans la session, ne pas la reproposer.

**Mode autonome** — agent qui décide :

```
Agent({step-name}-auto, sonnet):
  Tu es en mode autonome. Exécute {step} pour la phase {N}.
  Si tu trouves un blocking issue → émet le dans le rapport consolidé (n'interromps pas).
  Sinon → procède normalement et retourne un résumé 150 mots.
```

L'agent retourne toujours — il ne demande jamais de confirmation humaine.

### 4. Groupes parallèles

Le mode autonome peut étendre les groupes parallèles puisqu'il n'attend pas de confirmation humaine entre eux.

**Exemple de progression :**

| Étapes | Interactif | Autonome |
|---|---|---|
| 3+4 | Parallèle | Parallèle |
| 5 (optionnel) | Après 3+4 + prompt | Dans le groupe 3+4+5 (parallèle) |
| 1.5 (optionnel) | Après 1 + prompt | Après 1, avant 2 (automatique) |

### 5. Format de sortie

**Interactif** : narration step-by-step avec verdicts inline. L'utilisateur voit l'avancement en temps réel.

**Autonome** : rapport consolidé unique après complétion de toutes les étapes.

```markdown
## {Skill Name} {args}: Consolidated Report

### {Step A} ({timestamp})
{Résumé 100-200 mots des findings. Blocking issues en premier.}

### {Step B} ({timestamp})
{Résumé.}

### Verdict final
{GO | CONDITIONAL GO | NO-GO} — {justification en 1-2 phrases}

### Recommandation
{Prochaine action pour l'utilisateur}
```

Si un step autonome retourne un blocking issue : l'inclure dans le rapport consolidé avec `⚠ BLOCKING:` mais ne pas arrêter le pipeline (sauf si le skill définit explicitement des étapes stop-on-error).

### 6. Règles de comportement partagées

Ces règles s'appliquent dans les deux modes :

- **Erreur dans une étape obligatoire** : arrêter la chaîne, diagnostiquer pour l'utilisateur/rapport
- **Ne jamais lancer l'exécution** : le skill prépare, valide, rapporte — il ne déclenche pas l'exécution finale (c'est la décision de l'utilisateur ou du scheduler)
- **Suspendre les transitions automatiques** : pendant que le skill est actif, désactiver les transitions post-planning automatiques pour éviter les doubles exécutions

### 7. Implémentation — squelette

```
/{skill} {args} [--autonomous]:

1. Parser les flags (--autonomous présent ?)
2. Si autonome: définir auto_mode = True, question_count = 0
3. Pour chaque étape:
   a. Si obligatoire → exécuter
   b. Si optionnel ET non-autonome → prompt utilisateur (max 1 fois)
   c. Si optionnel ET autonome → lancer comme agent
4. Si autonome → agréger les résultats des agents, produire rapport consolidé
5. Sinon → résultats inline
```

## Reuse guide (how to apply to any repo)

1. **Lister les étapes du skill** — séparer obligatoires des optionnelles.

2. **Classifier les optionnelles** — lesquelles ont une heuristique "go par défaut" raisonnable ? Celles qui nécessitent un jugement irremplaçable ne peuvent pas être autonomisées.

3. **Écrire le prompt agent autonome pour chaque optionnelle** — inclure le contexte complet (le subagent n'a pas accès à la session parente), le critère de "blocking issue", et le format de retour 150 mots.

4. **Définir les groupes parallèles étendus** — quelles étapes peuvent tourner simultanément en mode autonome ?

5. **Concevoir le rapport consolidé** — structure fixe, markdown, consommable par script si besoin.

6. **Documenter la politique "go par défaut"** — qu'est-ce qui constitue un blocking issue en mode autonome ? Documenter explicitement pour éviter que l'agent ne sur-bloque.

7. **Ajouter la règle "ne jamais lancer l'exécution"** — le pattern dual-mode est pour la préparation et la validation, pas pour l'exécution finale.

## Extension points

- **Mode `--dry-run`** : exécuter toutes les étapes mais n'écrire aucun fichier — pour tester le pipeline sans side-effects
- **Mode `--skip {step-id}`** : skip explicite d'une étape spécifique en autonome (ex: `--skip ceo-review`)
- **Timeout autonome** : si un agent autonome dépasse N secondes → marquer l'étape comme skipped avec warning, continuer
- **Rapport JSON** : en mode autonome, option `--output json` pour consommation machine directe (CI pipeline)
- **Retry policy** : en mode autonome, réessayer les étapes échouées N fois avant de marquer FAILED dans le rapport

## Prepare Phase {N}: Consolidated Report

### Product Clarity (Step 0.5)
{Résumé office-hours, ou "Skipped — infra/tooling phase"}

### CEO Lens (Step 1.5)
{Résumé plan-ceo-review findings}

### Document Review (Step 4)
{Résumé 7-persona review findings}

### Deepen Plan (Step 5)
{Résumé ce:deepen-plan output, ou "No substantial changes"}

### Pre-Flight Verdict
{GO / CONDITIONAL GO / NO-GO} — {résumé findings}

### Recommendation
{Prochaine action}
```

### Références {{PROJECT}}

- Skill : `.claude/skills/prepare-phase/SKILL.md`
- Workflow GSD : `~/.claude/get-shit-done/workflows/` (workflows consommés par les étapes)

## Related FORGE patterns

- `skill-to-advisor-routing` — les étapes optionnelles d'un dual-mode skill invoquent souvent des advisors (ex: CEO lens, compliance check)
- `artifact-staleness-watcher` — le mode autonome génère des artefacts (rapports, plans) dont la fraîcheur peut être trackée
- `upstream-source-watcher` — même philosophie de "mode non-bloquant" pour les checks de fond
