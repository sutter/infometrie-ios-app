---
objective: "Le journal fonctionne en Live, 7 j et 30 j ; en 7 j et 30 j, un graphique par jour sélectionne le jour affiché dans la liste."
status: implemented
---

# Plan: Périodes du journal et graphique par jour

## Overview

| Field      | Value |
| ---------- | ----- |
| **Goal**   | Brancher 7 j et 30 j sur `/rest/v1/history` et `/rest/v1/days` (Swagger 0.11.0), avec un graphique en barres empilées par type qui sélectionne un jour, et retirer le choix Liste / Graphique. |
| **Source** | Demande utilisateur du 8 octobre 2026 (texte et capture d’un histogramme interventions / citations par jour), arbitrages du même jour : toucher une barre sélectionne le jour, fenêtres en jours complets jusqu’à hier, choix Liste / Graphique retiré. |

## Phases

| #   | Phase                                   | File                         |
| --- | --------------------------------------- | ---------------------------- |
| 1   | Contrat historique dans Core            | [`phase-1.md`](./phase-1.md) |
| 2   | État du journal par période et serveur de test | [`phase-2.md`](./phase-2.md) |
| 3   | Sélecteur de période, graphique et liste | [`phase-3.md`](./phase-3.md) |

## Resources

| Source | Verified |
| ------ | -------- |
| https://hls-test.yacast.fr/swagger/specs.yaml (0.11.0, copie `Docs/API/openapi.yaml`) | `/history` : `from` / `to` en jour de Paris `YYYY-MM-DD` (`to` inclus), 31 jours maximum, pagination `before_id`, `limit` 1–200, `kinds` / `persons` / `parties`, réponse `items` + `has_more`, `seq` toujours 0. `/days` : `days` 1–31, jours complets de Paris (aujourd’hui exclu), du plus ancien au plus récent, compte de chaque type. 503 = historique indisponible. |
| SDK iOS 27, `Charts.swiftinterface` | `chartGesture(_:)` et `ChartProxy.value(atX:as:)` existent : un tap peut sélectionner une barre ; `chartXSelection(value:)` pour le glisser. |

## Decisions

| Decision | Why |
| -------- | --- |
| 7 j et 30 j = les 7 ou 30 derniers jours complets de Paris, jusqu’à hier ; aujourd’hui reste dans Live | Choix utilisateur : la liste et les barres de `/days`, qui exclut aujourd’hui, concordent. 30 jours tient dans la limite serveur de 31. |
| La période n’entre pas dans `SearchFilters` ni dans les suivis | Un suivi décrit qui et quoi, pas quand ; un suivi enregistré reste valable quel que soit le jour. Appliquer un suivi garde la période courante. |
| Le flux Live et l’historique gardent des états séparés ; l’historique ne touche jamais `lastSeq` | Le Swagger impose `seq = 0` sur `/history` : le mélanger au curseur Live casserait le rafraîchissement incrémental. |
| Le graphique empile seulement les types cochés, aux couleurs de marque (interventions vermillon, citations bleu canard, X noir chaud) | `/days` compte chaque type séparément et laisse l’app empiler ; la capture du client est en marine et rouge, que `design.md` exclut (neutralité politique). |
| Sélection d’un jour aussi par des boutons précédent / suivant de 44 pt | À 30 barres sur un iPhone 13 mini, une barre fait environ 9 pt : trop petit pour un public de 45 à 80 ans et pour VoiceOver. |
| Le choix Liste / Graphique est retiré | Choix utilisateur : le graphique vit dans 7 j / 30 j ; aucune route ne ventile encore par personnalité ou par parti. |
