# Refonte UX — lire le fil, puis écouter un passage

Public : 45 à 80 ans. Objectif confirmé : parcourir le fil, choisir un passage, lire son texte puis écouter l’extrait souhaité. La refonte conserve l’application native, le branchement API et le moteur de synchronisation.

Une seconde itération centrée sur **Le fil et ses cartes** est maintenant implémentée : [voir la direction éditoriale, les captures et les vérifications](Feed/README.md). Les images ci-dessous conservent la référence de la première refonte.

Le même style est maintenant décliné dans la **fiche de séquence** : [choix, captures et validation du lecteur synchronisé](Sequence/README.md).

## Audit de départ

Captures prises le 22 septembre 2026 dans le simulateur iPhone 17 Pro, pendant les parcours XCTest de cette intervention (`build/UXBaseline.xcresult`, trois tests réussis). Données de démonstration fictives.

| Étape | Observation sur la capture | Conséquence et correction |
|---|---|---|
| [1. Connexion](Before/00-connexion.png) | Introduction et encart promotionnel avant le formulaire. | Les champs et le bouton sont rapprochés du haut ; le mot de passe peut être affiché avec une cible plus grande. |
| [2. Fil](Before/01-fil.png) | Le podcast occupe l’essentiel du premier écran ; la recherche est une loupe détachée sans texte. | Fil prioritaire, actions nommées « Filtrer » et « Tout écouter », trois onglets stables. |
| [3. Filtres](Before/02-filtres.png) | Introduction longue, critères dispersés et deux interrupteurs permettant de désactiver tout le contenu. | Critères regroupés dans une feuille, choix exclusif Tous / Interventions / Citations, action de validation fixe. |
| [4. Suivis](Before/02-recherches.png) | « Voir le fil » et le menu sont petits ; les onglets peuvent se réduire à des icônes. | Actions agrandies, menu « Options », navigation stable et intitulé « Mes suivis ». |
| [5. Passage](Before/03-sequence-avant-lecture.png) | Titre, illustration du lecteur et résumé repoussent le verbatim sous le premier écran. | Texte avant résumé ; résumé et métadonnées dépliables ; commande d’écoute fixée en bas. |
| [6. Écoute](Before/04-podcast.png) | Les commandes se trouvent dans le contenu défilant et sont uniquement iconographiques. | Bouton « Écouter / Pause », curseur et sauts de 10 secondes persistants. |
| [7. Très grand texte](Before/06-texte-accessible.png) | L’encart podcast remplit presque tout l’écran avant même le premier résultat. | Suppression de cet encart ; rangées qui passent en colonne et boutons à hauteur adaptable. |

Points conservés : composants natifs, palette bleue, thèmes clair et sombre, texte sélectionnable par mot pour rejoindre un instant, indications honnêtes de synchronisation précise ou estimée, confirmation des actions destructives.

## Choix appliqués

- Les cartes expliquent leur action : **Lire et écouter**. Toute la carte est interactive.
- Trois destinations : **Le fil**, **Mes suivis**, **Compte**. Filtrer est une action du fil, pas une quatrième destination.
- Un filtre actif reste visible, avec **Tout afficher** pour revenir au fil complet. Annuler conserve les critères précédemment appliqués.
- Sur un passage, **le texte est visible avant le résumé**. L’écoute démarre depuis le bouton principal ou un mot du texte. Le lecteur reste accessible quand on fait défiler la page.
- En pause, toucher un mot ou déplacer le curseur conserve la pause ; le mot et le temps restent synchronisés. Le suivi automatique peut être repris après un défilement manuel.
- En-tête du fil protégé par un fond net pendant le défilement ; estompage inférieur retiré.
- Texte sémantique Dynamic Type, mode **Texte plus grand** activé par défaut, respect des tailles d’accessibilité supérieures. Pas de plafond imposé à la taille des caractères.
- Boutons principaux de 52 points minimum, sauts de 10 secondes de 56 points ; hauteur flexible et surfaces opaques. Labels secondaires renforcés, suppression des majuscules espacées et des décorations audio.
- Les références techniques et l’état mot par mot ne monopolisent pas l’écran. La position dans le texte reste exposée à l’accessibilité.

Ces choix s’appuient sur les recommandations [Apple pour les contrôles et la lisibilité](https://developer.apple.com/design/tips/), [Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/typography) et [l’accessibilité des usages à un âge avancé](https://www.w3.org/WAI/older-users/). L’âge ne définit pas à lui seul les capacités ou les préférences de chaque personne.

## Écrans après refonte

| Parcours | Avant | Après |
|---|---|---|
| Lire le fil | [Fil initial](Before/01-fil.png) | [Nouveau fil](After/01-fil.png) |
| Ouvrir un passage | [Ancien écran](Before/03-sequence-avant-lecture.png) | [Texte en premier](After/03-sequence-avant-lecture.png) |
| Écouter | [Lecteur initial](Before/03-sequence.png) | [Commandes persistantes](After/03-sequence.png) |
| Filtrer | [Ancienne recherche](Before/02-filtres.png) | [Filtres regroupés](After/02-filtres.png) |
| Retrouver un suivi | [Anciennes recherches](Before/02-recherches.png) | [Mes suivis](After/02-recherches.png) |

[Connexion simplifiée](After/00-connexion.png) · [Thème sombre](After/05-fil-sombre.png) · [Très grands caractères](After/06-lecture-texte-accessible.png) · [Réglage du confort de lecture](After/12-compte-connecte-api.png) · [Synchronisation précise](After/10-verbatim-horodatages-api.png).

Les captures montrent exclusivement des données fictives. Celles du compte et du quota proviennent du transport de test, pas du compte personnel.

## Validation

- Compilation du simulateur réussie avec Swift 6 et SDK iOS 27.
- 34 tests du cœur réussis : contrat API, persistance, HLS et horodatages.
- `build/UXIteration2.xcresult` : parcours de connexion, quota, erreurs/réessai, restauration Keychain et synchronisation du podcast réussis.
- `build/UXFinal.xcresult` : fil → filtres → sauvegarde/annulation → persistance → archivage/restauration/suppression → passage/podcast réussi ; synchronisation estimée et précise réussie.
- `build/UXAccessibilityFinal.xcresult` : parcours avec la taille d’accessibilité maximale et audit du fil réussis ; clic sur un mot, filtres, annulation, cibles tactiles et contraste des cartes entièrement visibles contrôlés.

Le dernier contrôle ciblé du fil et de son en-tête passe dans `build/UXVerified.xcresult` (1 test, 0 échec). [Voir le fil après défilement](After/14-fil-contraste.png).

Le contrôle de contraste porte sur les cartes entièrement visibles, puis est relancé après défilement pour exposer la carte suivante. Les signalements dans une carte partiellement masquée par les barres natives sont consignés en pièce jointe, hors du périmètre de ce contrôle. Les tests vérifient également les zones tactiles et le texte tronqué sur le fil. Cela ne constitue pas un audit automatisé complet de tous les écrans.

L’itération a corrigé le contraste des textes secondaires. Les gestes XCTest ont aussi été adaptés à la barre de lecture persistante : ils défilent dans la zone de contenu et amènent le mot entièrement au-dessus du lecteur avant de le toucher. La vérification ne se contente pas de l’existence d’un bouton hors écran.

Les captures du compte, du quota et du podcast synchronisé proviennent des parcours réussis de `UXIteration2`. Les autres captures proviennent des parcours correspondants réussis de `UXFinal`, de `UXAccessibilityFinal` et de `UXVerified` pour la connexion et le fil défilé.

Il s’agit d’une inspection et de tests techniques, pas d’une étude d’usage auprès de personnes de 45 à 80 ans ni d’une certification d’accessibilité. Une observation avec des utilisateurs reste nécessaire pour mesurer compréhension, autonomie et confort réel. Le runtime disponible est iOS 26.4, avec compilation SDK iOS 27.
