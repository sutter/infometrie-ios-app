---
objective: "« Mes suivis » montre environ sept suivis par écran d’iPhone 13 mini, chacun sur une ligne compacte qui ouvre le journal d’un toucher, et les suivis archivés vivent sur leur propre page."
status: pending
---

# Plan: Réagencement de « Mes suivis »

## Overview

| Field      | Value |
| ---------- | ----- |
| **Goal**   | Remplacer les fiches hautes de « Mes suivis » (1,5 suivi par écran) par l’option A de la planche 05 : une ligne compacte par suivi, nom en tête, total et barres sur 7 jours à droite, « ⋯ » pour les actions ; « Créer un suivi » en haut à droite ; archivés sur une page à part. |
| **Source** | Demande utilisateur du 12 octobre 2026 : « je trouve que c’est vraiment mal agencé, j’ai du mal à retrouver mes choses ». Arbitrages du même jour sur la planche `~/Documents/InfoMétrie – planches design/05 – mes suivis, options.png` : option A, ordre par dernière utilisation conservé. |

## Phases

| #   | Phase                                  | File                         |
| --- | -------------------------------------- | ---------------------------- |
| 1   | Ligne compacte des suivis actifs        | [`phase-1.md`](./phase-1.md) |
| 2   | Suivis archivés sur leur propre page    | [`phase-2.md`](./phase-2.md) |

## Resources

| Source | Verified |
| ------ | -------- |
| https://hls-test.yacast.fr/swagger/specs.yaml (0.13.0, 12 octobre 2026) | Aucune route de suivis, de recherches enregistrées ni de préférences : les suivis restent sur l’appareil (`SearchStore`, `UserDefaults` par compte). Seul le numéro de version diffère de `Docs/API/openapi.yaml` (0.12.0). |

## Decisions

| Decision | Why |
| -------- | --- |
| Option A de la planche 05 : nom, critères, types restreints à gauche ; total et 7 barres à droite ; « ⋯ » ; toucher la ligne ouvre le journal | Choix utilisateur. Environ 7 suivis par écran contre 1,5 aujourd’hui, le nom redevient l’élément le plus fort, la tendance par type reste visible. |
| L’ordre reste celui de la dernière utilisation, et le sous-titre le dit (« les derniers utilisés en premier ») | Choix utilisateur, contre la recommandation d’un ordre A à Z : un suivi change de place à chaque usage. L’annoncer rend le mouvement compréhensible. |
| Les archivés quittent les puces Actifs / Archivés pour une ligne « Suivis archivés » en bas, qui pousse une page | Les puces coûtaient environ 70 pt en tête de page pour un usage rare ; la page principale ne montre plus que les suivis actifs. |
| « Créer un suivi » passe dans la barre de navigation (iPhone) ou à droite du titre (iPad) ; il reste un bouton plein dans l’état vide | Même place que « Rechercher » sur le journal ; la tête de page tombe d’environ 360 pt à 120 pt avant le premier suivi. |
