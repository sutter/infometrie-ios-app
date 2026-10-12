---
objective: "Un passage se met en favori d’un toucher et se retrouve dans un onglet « Favoris », gardé sur l’appareil par compte, même après sa sortie de l’historique du serveur."
status: implemented
---

# Plan: Favoris

## Overview

| Field      | Value |
| ---------- | ----- |
| **Goal**   | Mettre un passage (intervention, citation, publication X) en favori depuis sa page ou le journal, et retrouver les favoris dans un quatrième onglet « Favoris » ★ ; stockage sur l’appareil, par compte, sans appel à l’API. |
| **Source** | Demande utilisateur du 12 octobre 2026 : « une gestion de bookmarks/favorites. Ils sont stockés dans le téléphone et non via l’API du projet. » Arbitrages du même jour : passages seuls, quatrième onglet « Favoris » avec une étoile, un favori sorti de l’historique reste dans la liste, marqué « Plus disponible ». |

## Phases

| #   | Phase                                   | File                         |
| --- | --------------------------------------- | ---------------------------- |
| 1   | Mettre un passage en favori              | [`phase-1.md`](./phase-1.md) |
| 2   | L’onglet « Favoris »                     | [`phase-2.md`](./phase-2.md) |

## Decisions

| Decision | Why |
| -------- | --- |
| Les favoris vivent dans `UserDefaults`, par compte, comme `SeenStore` et `SearchStore`, et survivent à la déconnexion | Demande explicite : rien côté API. Même clé par compte que les passages vus, donc un second compte sur l’appareil ne voit pas les favoris du premier. Pas de synchronisation entre appareils. |
| Un favori garde une copie du `FeedItem` (titre, personne, parti, date, chaîne, type) et sa date d’ajout | La liste s’affiche sans appel réseau, et un passage sorti de l’historique garde de quoi être reconnu. Le détail (texte, média) n’est jamais stocké : l’app reste en lecture seule et sans hors-ligne. |
| Symbole `star` / `star.fill`, libellés « Favoris », « Ajouter aux favoris », « Retirer des favoris » | `bookmark` porte déjà les suivis (onglet, « Suivre », « Suivi enregistré ») : un second signet confondrait les deux notions. |
| « Plus disponible » se déduit de la date du passage, avant `FeedPeriod.oldestDay` (60 jours mesurés le 2026-10-09), sans appel réseau ; la ligne reste ouvrable | Aucun appel pour décider. Si le serveur garde plus longtemps, la page s’ouvre quand même ; s’il garde moins, la page affiche déjà « Le contenu demandé n’est plus disponible. » |
| Ordre : les derniers ajoutés en premier | Ce qu’on vient de garder est ce qu’on cherche ; la date de diffusion reste lisible sur chaque ligne. |
