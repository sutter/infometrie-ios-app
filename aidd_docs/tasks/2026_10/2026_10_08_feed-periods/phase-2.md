---
status: pending
---

# Instruction: État du journal par période et serveur de test

## Architecture projection

> Tree of the final files. ✅ create · ✏️ modify · ❌ delete

```txt
.
├── Infometrie/Services/
│   └── AppModel.swift               ✏️ période, historique paginé, comptes par jour, jour sélectionné
├── Infometrie/InfometrieApp.swift   ✏️ la boucle de 30 s ne rafraîchit que Live
└── Infometrie/Fixtures/
    ├── FixtureContent.swift         ✏️ passages fictifs datés des jours passés, comptes par jour
    └── UITestServer.swift           ✏️ routes /history et /days, séquences de l’historique
```

## User Journey

```mermaid
flowchart TD
  A[Choisir 7 j] --> B[Charger days et la première page d'history en parallèle]
  B --> C[Liste de la période et barres]
  C --> D[Sélectionner un jour] --> E[history from = to = ce jour]
  E --> F[Désélectionner] --> C
  C --> G[Fin de liste] --> H[Page suivante before_id]
  A2[Changer un type, une personnalité, un parti] --> B
  A3[Revenir à Live] --> I[Fil Live et curseur intacts]
```

## Test Scope

```mermaid
---
title: Test scope
---
journey
  section Setup
    Lancer en Debug avec --uitesting --signed-in => serveur de test avec historique fictif: 5: system
  section Happy path
    Choisir 7 j => le serveur reçoit days=7 et history du J-7 à J-1: 5: system
    Sélectionner un jour => le serveur reçoit history from = to = ce jour: 5: system
    Atteindre la fin de la première page => le serveur reçoit before_id du dernier passage: 5: system
    Revenir à Live => le fil Live reprend avec son curseur: 5: system
  section Edge case - réponse périmée
    Changer de période pendant un chargement => ancienne réponse ignorée: 1: system
  section Edge case - 503
    Historique indisponible => erreur affichée, Live toujours accessible: 1: system
  section Teardown
    Déconnexion => période, jour, historique et comptes réinitialisés: 5: system
```

## Tasks to do

### `1)` État par période dans AppModel

> L’historique vit à côté du fil Live, sans jamais toucher son curseur.

1. Ajouter `period`, `selectedDay`, `historyItems`, `historyHasMore`, `dayCounts`, et un `requestID` propre à l’historique.
2. `visibleItems` lit `items` en Live et `historyItems` sinon, toujours à travers `filters.accepts`.
3. `selectPeriod(_:)` et `selectDay(_:)` rechargent ; un changement de filtres recharge la période courante.
4. Charger `/days` et la première page de `/history` en parallèle ; `loadMoreHistory()` ajoute la page suivante sans doublon d’`id`.
5. Une réponse d’une ancienne requête ne remplace jamais la sélection courante.
6. Erreurs : 401 / 403 terminent la session, 503 et le reste remplissent `feedError`.
7. `resetContent()` remet la période à Live et vide l’historique.

### `2)` Rafraîchissement

> Le polling ne concerne que Live.

1. La boucle de 30 s de `RootView` ne fait rien hors Live.
2. Le tirer pour rafraîchir recharge la période courante (comptes et première page).
3. Au retour au premier plan après minuit, une période 7 j / 30 j recalcule sa fenêtre.

### `3)` Serveur de test

> Les UI tests couvrent les périodes sans réseau.

1. `FixtureContent` : des passages fictifs datés de J-1 à J-30 (plus d’une page pour J-7 à J-1 avec `limit` réduit si besoin), `seq` 0, et les comptes par jour cohérents.
2. `UITestServer` : `/rest/v1/history` (filtres `from`, `to`, `kinds`, `before_id`, `limit`, 422 sans `kinds`) et `/rest/v1/days`.
3. Les passages de l’historique s’ouvrent (détail, média, timings) comme ceux du fil.
4. Rester sous `#if DEBUG`.

## Test acceptance criteria

| Task | Acceptance criteria |
| ---- | ------------------- |
| 1 | En 7 j, la liste montre les passages des 7 jours complets ; un jour sélectionné ne montre que ce jour ; revenir à Live retrouve le fil sans rechargement depuis zéro. |
| 1 | Changer de période vite plusieurs fois laisse la liste de la dernière période choisie. |
| 2 | En 7 j, aucune requête `/feed` ni `/history` ne part toutes les 30 secondes. |
| 3 | Le serveur de test répond aux deux routes et un passage de l’historique s’ouvre et se lit. |
