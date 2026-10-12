---
objective: "Une recherche se garde d’un toucher, depuis le journal où l’on voit ses résultats, et « Créer un suivi » enregistre vraiment un suivi."
status: in-progress
---

# Plan: Créer un suivi sans l’oublier

## Overview

| Field      | Value |
| ---------- | ----- |
| **Goal**   | Proposer « Suivre « <critères> » ? » dans le journal sous une recherche pas encore suivie, et faire de « Créer un suivi » une feuille « Nouveau suivi » qui enregistre puis affiche ; noms automatiques, « Renommer » à la place de la feuille de nommage. |
| **Source** | Demande utilisateur du 12 octobre 2026 : « c’est très compliqué de se créer un nouveau suivi. On est incité à voir le résultat, mais on oublie souvent de sauvegarder ». Arbitrages du même jour sur `~/Documents/InfoMétrie – planches design/06 – créer un suivi, options.png` : option A, option B sans case à cocher, nom automatique. |

## Phases

| #   | Phase                              | File                         |
| --- | ---------------------------------- | ---------------------------- |
| 1   | Suivre depuis le journal            | [`phase-1.md`](./phase-1.md) |
| 2   | « Créer un suivi » enregistre       | [`phase-2.md`](./phase-2.md) |

## Decisions

| Decision | Why |
| -------- | --- |
| Le nom d’un suivi est automatique : ses personnes et partis, plus ses types quand il en exclut (« Groupe B · Citations »), « Tout le panel » sans critère ; « Renommer » le change ensuite | Choix utilisateur. Le nom obligatoire, dans une seconde feuille, était l’étape qui faisait abandonner. |
| Dans le journal, une recherche compte comme suivie quand un suivi actif a les mêmes personnes et partis, quels que soient les types ; « Créer un suivi » ne refuse que les critères identiques, types compris | Les cases de types du journal sont un filtre de lecture : décocher X sur un suivi ouvert ne doit pas reproposer de le suivre. « Créer un suivi » est une demande explicite : « Camille Martin · Interventions » doit pouvoir exister à côté de « Camille Martin ». |
| « Suivre » sur des critères d’un suivi archivé le restaure au lieu d’en créer un second | Pas de doublon, et le nom choisi autrefois est conservé. |
| Enregistrer laisse sur les résultats du journal, avec « Suivi enregistré » et « Renommer » | L’utilisateur venait voir des résultats ; l’envoyer dans Mes suivis lui retirait ce qu’il cherchait. |
| La ligne « Enregistrer ce suivi » de la recherche et la feuille « Enregistrer un suivi » disparaissent | Le journal et « Nouveau suivi » couvrent les deux entrées ; garder un troisième chemin, caché sous le pli, entretiendrait la confusion. |
