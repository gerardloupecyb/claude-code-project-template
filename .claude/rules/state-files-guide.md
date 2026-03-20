# State Files Guide — séparation des fichiers d'état

Ces fichiers coexistent sans se chevaucher :

- **STATE.md** = le GPS technique. Où on est dans le roadmap GSD (phase, wave, task).
  Géré automatiquement par GSD. Ne PAS éditer manuellement.
  Ne contient PAS de décisions métier ni de contexte de session.

- **MEMORY.md** = le journal de bord. Contexte métier, décisions prises et pourquoi,
  prochaine étape humaine, blocages.
  Géré manuellement par Claude en début/fin de session.
  Ne contient PAS de position technique GSD ni de leçons (→ LESSONS.md).

- **LESSONS.md** = le cache chaud des leçons. Format quand/faire/parce que, cap 50.
  Géré par `/lesson`. Lu automatiquement à chaque session.
  Ne contient PAS d'état de session (→ MEMORY.md) ni de patterns détaillés (→ Supermemory/docs/solutions/).

En début de session, lire les trois : MEMORY.md pour le contexte, LESSONS.md pour les leçons, STATE.md pour la position.
