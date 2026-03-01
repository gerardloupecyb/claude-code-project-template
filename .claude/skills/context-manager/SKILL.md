---
name: context-manager
description: >
  Règles de gestion du contexte, de la mémoire et du chain of thought pour
  Claude Code. Charger automatiquement sur tout projet qui utilise MEMORY.md,
  Supermemory, ou qui implique des sessions longues. Se déclenche aussi quand
  l'utilisateur mentionne "contexte", "mémoire", "reprendre le projet",
  "session", ou "MEMORY.md".
---

# Context Manager

Règles pour maintenir la qualité des réponses sur des sessions longues,
gérer la mémoire entre sessions, et structurer le raisonnement sur des
tâches complexes.

---

## Règles critiques — s'appliquent toujours

### Démarrage de session

TOUJOURS lire dans cet ordre avant de coder ou planifier :

1. memory/MEMORY.md          → état courant, décisions actives
2. docs/solutions/{domaine}/ → patterns connus sur le domaine du jour
3. Supermemory query          → leçons cross-projet si domaine connu

Si MEMORY.md n'existe pas → le créer depuis le template avant de continuer.
Ne jamais supposer le contexte. Toujours le lire.

### Fin de session

Mettre à jour MEMORY.md avant de fermer :

- Ce qui a été fait (3-5 lignes max)
- Décisions prises + raison courte
- Une seule prochaine étape, claire et actionnable
- Blocages ou questions ouvertes

Commiter MEMORY.md dans le même commit que le code produit.

---

## Gestion des sessions longues

### Détecter la dégradation du contexte

Signaux d'alerte :

- Claude répète des questions déjà répondues plus tôt dans la session
- Réponses moins précises ou qui ignorent des contraintes établies
- Contexte à ~60-70% de capacité utilisée
- Incohérences avec des décisions prises en début de session

Action quand signal détecté :
Annoncer : "Contexte à [X]% — checkpoint recommandé avant de continuer."

### Protocole checkpoint

1. Résumer l'état en moins de 200 mots dans MEMORY.md
2. Lister les décisions prises depuis le début de session
3. Identifier la prochaine tâche (une seule, actionnable)
4. Proposer d'ouvrir une nouvelle session avec MEMORY.md en contexte initial

Règle absolue : ne jamais continuer une session dégradée.
La qualité se dégrade exponentiellement passé un certain seuil.
Une coupure propre avec MEMORY.md à jour produit de meilleurs résultats.

---

## Chain of thought — externaliser avant d'exécuter

### Quand l'appliquer

Obligatoire pour :

- Décisions d'architecture ou de structure de données
- Logique métier complexe (règles conditionnelles multiples)
- Debug difficile (plus d'une hypothèse possible)
- Choix entre plusieurs approches techniques

Optionnel pour :

- Tâches CRUD simples et bien définies
- Code boilerplate standard
- Modifications mineures sans impact architectural

### Format chain of thought

```
Problème : [ce qu'on résout exactement, pas ce qu'on va faire]
Contraintes : [limites connues — perf, API, sécurité, budget, etc.]
Options :
  A) [option] → avantage : [X] / inconvénient : [Y]
  B) [option] → avantage : [X] / inconvénient : [Y]
Choix : [option] parce que [raison courte et précise]
Risques : [ce qui pourrait mal tourner et comment on le détecte]
```

Où mettre ce bloc :

- Dans le PLAN.md GSD si c'est une tâche planifiée
- En commentaire en tête du fichier si c'est de l'architecture
- Dans MEMORY.md sous "Décisions actives" si c'est un choix durable

---

## Supermemory — protocole de sauvegarde

### Sauvegarder si et seulement si

- Pattern applicable à d'autres projets futurs (cross-projet)
- Décision d'architecture structurante qu'on voudra retrouver
- Leçon apprise après une erreur coûteuse en temps ou en qualité
- Convention de travail personnelle à retenir

### Ne pas sauvegarder

- Détails spécifiques à ce projet         → MEMORY.md ou docs/solutions/
- Code ou implémentation                  → Git
- Choses triviales, documentation standard

### Format obligatoire

```
[tag:{domaine}] Titre court et précis
Contexte : projet/situation où découvert
Problème : ce qui se passait avant ce pattern
Solution : ce qui fonctionne
Règle : "Toujours X quand Y." — une phrase actionnable
Réf : chemin fichier ou URL si applicable
```

### Tags standards

- `[skill:{domaine}]`         → règle technique réutilisable
- `[decision:architecture]`   → choix structurant cross-projets
- `[decision:stack]`          → choix de librairie ou outil
- `[lesson:error]`            → erreur à ne pas répéter
- `[convention:workflow]`     → façon de travailler à retenir
- `[context:preference]`      → préférence personnelle de travail

---

## Hiérarchie des couches mémoire

Utiliser la bonne couche pour la bonne information :

| Information | Où la mettre |
|-------------|-------------|
| État courant du projet, où on en est | memory/MEMORY.md |
| Décisions actives qui influencent le code | memory/MEMORY.md → Décisions actives |
| Pattern résolu sur CE projet | docs/solutions/{domaine}/ |
| Pattern réutilisable sur plusieurs projets | docs/solutions/ + domaine CARL |
| Leçon cross-projet, préférence personnelle | Supermemory |
| Code et implémentation | Git |
| Credentials et secrets | .env (jamais dans mémoire) |

Ne jamais mélanger les couches. Un pattern dans MEMORY.md qui dure
plus d'une semaine doit migrer vers docs/solutions/.

---

## Anti-patterns

- Commencer à coder sans lire MEMORY.md
- Continuer une session dont le contexte est dégradé
- Sauvegarder dans Supermemory sans tag structuré
- Mettre un pattern dans Supermemory s'il n'est pas cross-projet
- Dupliquer un pattern dans docs/solutions/ au lieu de le mettre à jour
- Stocker credentials ou données clients dans MEMORY.md, docs/, ou Supermemory
- Faire du chain of thought en tête implicitement sans l'externaliser
- Créer un domaine CARL avec moins de 3 règles distinctes

---

## Références

- memory/MEMORY.md                    → template état courant projet
- docs/solutions/                     → patterns durables
- .carl/{domaine}                     → domaine CARL actif
- CLAUDE.md du projet                 → règles flywheel complètes
