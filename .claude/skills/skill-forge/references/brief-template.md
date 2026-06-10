# Brief Template — Skill Forge

Utilisé quand le brief est incomplet ou quand `/skill-forge --brief` est invoqué.
Poser uniquement les questions sans réponse dans le brief fourni.

---

## Questions à poser (une seule fois, groupées)

```
Pour créer ce skill, j'ai besoin de quelques précisions :

1. **Nom** : Comment appeler ce skill ? (kebab-case, ex: mon-skill)
2. **Objectif** : En une phrase, que fait ce skill quand on l'invoque ?
3. **Triggers** : Quels mots ou phrases doivent déclencher ce skill automatiquement ?
   (en plus de /nom-skill explicite)
4. **Modes** : Ce skill a-t-il plusieurs modes ou variantes ? (ex: --verbose, start/end, par type de fichier)
5. **Inputs** : Quelles infos doit-il recevoir ? (argument, fichiers présents, état du projet)
6. **Output** : Que produit-il ? (fichier écrit, rapport dans la console, action sur des fichiers)
7. **Hors-scope** : Quelles actions il ne doit JAMAIS faire ? (important pour la section "does NOT do")
```

---

## Brief minimal suffisant

Un brief est suffisant si on peut répondre à toutes ces questions :

| Question | Requis | Peut inférer |
|----------|--------|--------------|
| Nom | Toujours | Non |
| Objectif | Toujours | Non |
| Triggers principaux | Toujours | 1 trigger inféré du nom |
| Modes | Si multiples | Oui — défaut = 1 mode |
| Inputs | Si non-trivial | Oui — défaut = contexte courant |
| Output format | Toujours | Non |
| Hors-scope | Toujours | Non |

---

## Exemple de brief complet

```
Nom: deployment-check
Objectif: Vérifier qu'un environnement est prêt avant un déploiement
Triggers: deployment check, check deploy, avant de déployer, /deployment-check
Modes: --staging, --prod (différentes listes de checks)
Inputs: Nom de l'environnement cible (arg obligatoire)
Output: Tableau de checks avec PASS/FAIL + verdict GO/NO-GO
Hors-scope:
  - Ne pas modifier des fichiers
  - Ne pas lancer le déploiement lui-même
  - Ne pas checker des environnements non-{{PROJECT}}
```

---

## Template de tests/cases.md à générer

Après le drafting, générer automatiquement ces cas de base :

```markdown
# Test Cases — {nom}

## Case C-01 — Invocation standard

**Trigger:** `/{nom}`
**Contexte:** Projet {{PROJECT}}, tous les fichiers habituels présents
**Input utilisateur:** `/{nom}`
**Mode:** Défaut

---

## Case C-02 — Mode alternatif (si applicable)

**Trigger:** `/{nom} --{mode}`
**Contexte:** [adapter selon le mode]
**Input utilisateur:** `/{nom} --{mode}`
**Mode:** {mode}

---

## Case C-03 — Input invalide / hors-scope

**Trigger:** `/{nom}` avec une demande hors-scope
**Contexte:** Utilisateur demande quelque chose que le skill ne doit pas faire
**Input utilisateur:** `/{nom} [action hors-scope]`
**Mode:** Défaut
**Attendu:** Le skill refuse poliment et explique son hors-scope
```

## Template de tests/assertions.md à générer

```markdown
# Assertions — {nom}

## Assertions — Case C-01

**MUST contain:**
- [ ] Le format de sortie défini dans Output section du SKILL.md
- [ ] Au moins un résultat concret (pas de réponse vide)

**MUST NOT contain:**
- [ ] Hallucination de fichiers non existants
- [ ] Actions décrites dans "What this skill does NOT do"

**MUST read:**
- [ ] `references/common.md` (si routing table inclut always)

---

## Assertions — Case C-02

[Adapter selon le mode et les outputs attendus]

---

## Assertions — Case C-03

**MUST contain:**
- [ ] Mention explicite du hors-scope violé
- [ ] Redirection vers le bon skill ou la bonne action

**MUST NOT contain:**
- [ ] Tentative d'exécuter l'action hors-scope
```
