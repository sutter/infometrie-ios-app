# Le fil — une lecture plus éditoriale

## En-tête compact — présentation actuelle

Revue ciblée du 22 septembre 2026, à partir d’une nouvelle capture du simulateur en démonstration. Objectif : consacrer davantage du premier écran à la lecture, avec des commandes repérables pour le public de 45 à 80 ans.

1. **Ouverture du fil, avant** — les cartes sont lisibles et les types explicites, mais le logo, le grand titre, les deux boutons et le sélecteur encadré accumulent les niveaux avant la première carte. [Capture de départ](entete-avant.png).
2. **Ouverture du fil, après** — titre « Le fil » dans la barre de navigation et « Filtrer » à droite, accessible après défilement. Le sélecteur devient une rangée de libellés avec soulignement du choix actif. « Tout écouter », accompagné du pictogramme de lecture, rejoint le nombre de résultats et la période « 24 h ». La typographie et les dimensions des cartes sont conservées. Deux cartes complètes sont visibles à la taille standard testée, contre une auparavant. [Capture finale](entete-compact-clair.png).

Les commandes du contenu gardent une cible d’au moins 48 points ; le bouton de navigation en garde 44. Le texte du contenu n’est pas plafonné : les choix et la ligne de résultats se réorganisent lorsque la taille ou la largeur l’exige. L’actualisation automatique et le geste natif de rafraîchissement restent disponibles.

[Citations](entete-compact-citations.png) · [Sombre](entete-compact-sombre.png) · [Grands caractères](entete-compact-grands-caracteres.png).

Quatre parcours distincts validés : choix du type, retour de fiche et écoute filtrée ; intersection personnalités/partis, résultat vide et remise à zéro dans `build/FeedCompactHeader.xcresult` ; sombre et texte maximal dans `build/FeedCompactHeaderFinal.xcresult` ; filtres/annulation et audit du fil dans `build/FeedCompactHeaderVerified.xcresult` (`TEST SUCCEEDED`, un test, zéro échec). Compilation SDK iOS 27, captures actuelles sur iPhone 17 Pro / iOS 26.4, données fictives. Les captures avant et après ont été inspectées ensemble. Application normale relancée.

L’audit a fait remplacer l’adaptation automatique du bouton de barre, qui masquait « Filtrer » et réduisait sa taille, par un libellé explicite de 44 points. Le pilote accepte l’arrondi numérique de cette mesure et la nouvelle position des choix près de la barre. Le libellé abrégé « 24 h » garde une aide VoiceOver complète sans que le texte annoncé soit interprété comme du texte visible tronqué. Les contrôles automatisés portent sur les éléments exposés ; ils ne constituent pas une certification d’accessibilité ni une observation auprès du public cible.

## Choix du type directement dans le fil

Le sélecteur **Tous · Interventions · Citations**, placé en haut du contenu, applique le choix immédiatement. Interventions en bleu, citations en rouge ; le soulignement identifie le choix actif, également annoncé comme sélectionné à VoiceOver.

- « Tous » affiche les deux types sans effacer les personnalités et partis choisis.
- Le panneau de filtres et le sélecteur utilisent les mêmes critères. L’annulation du panneau conserve la sélection appliquée ; revenir d’une fiche conserve le type choisi.
- « Tout écouter » prépare sa liste à partir des passages visibles. Une sélection sans résultat laisse le sélecteur accessible et désactive cette action.
- « Votre sélection » est réservé aux personnalités et partis : le type n’est pas répété dans une carte supplémentaire.
- Les cibles mesurent au moins 48 points de haut. Les choix passent en colonne avec les tailles d’accessibilité, ou lorsque la largeur ne permet plus de conserver les libellés entiers.

Première version du sélecteur, avant compaction de l’en-tête :

[Tous les passages](fil-types-tous.png) · [Citations](fil-types-citations.png) · [Interventions en sombre](fil-types-sombre.png) · [Texte maximal](fil-types-grands-caracteres.png).

Quatre parcours distincts validés : filtrage direct, synchronisation panneau/fil, retour de fiche et écoute de la sélection ; conservation des personnalités et partis, résultat vide et retour à « Tous » dans `build/FeedQuickKinds.xcresult` ; sombre/texte maximal et filtres/audit du fil dans `build/FeedQuickKindsVerified.xcresult` (`TEST SUCCEEDED`, deux tests, zéro échec). L’audit a conduit à renforcer le contraste du compteur avec `Color.primary` explicite, pour éviter l’héritage du style secondaire de sa ligne. Captures inspectées sur iPhone 17 Pro / iOS 26.4, SDK iOS 27 ; application normale relancée. Le périmètre du contrôle de contraste reste celui des éléments exposés, hors recouvrement des barres natives.

## Cartes allégées — présentation actuelle

À la demande de l’utilisateur, le bandeau « Lire et écouter » est retiré. Toute la carte continue d’ouvrir la fiche de séquence.

- En haut : média à gauche, date courte et heure à droite (`22/09 · 10:45`). La fiche de séquence partage cet affichage ; VoiceOver reçoit la date complète.
- Au centre : titre, puis personnalité et affiliation.
- En bas : **Citation** ou **Intervention**, avec un pictogramme distinct ; durée d’écoute à droite, accompagnée d’un casque. Le type n’est plus répété dans l’affiliation du fil.
- Code couleur : **citations en rouge**, **interventions en bleu**. La couleur porte sur le libellé du type, le pictogramme du média et le filet de la personnalité. Les mêmes accents sont repris dans la fiche et les choix de filtres, avec une nuance plus claire en mode sombre. Les libellés et les pictogrammes restent présents.
- Les deux lignes de métadonnées passent en colonne aux tailles d’accessibilité. La durée reste masquée lorsqu’aucun média ou aucune durée positive n’est disponible.

[Cartes claires](cartes-allegees-clair.png) · [Cartes sombres](cartes-allegees-sombre.png) · [Type et durée au texte maximal](metadonnees-grands-caracteres.png).

Compilation SDK iOS 27 et deux parcours existants réussis dans `build/FeedMetadata.xcresult` (zéro échec) : navigation carte → fiche → lecture en sombre et en très grands caractères ; filtres et audit du fil sur les cartes entièrement visibles. Captures inspectées, données fictives, iPhone 17 Pro / iOS 26.4. Application normale relancée. Journal : `/tmp/infometrie-feed-metadata.log`.

Les captures claires et sombres ont été actualisées avec le code rouge/bleu. Deux parcours passent dans `build/PassageColors.xcresult`, avec ouverture d’une citation en clair et en sombre et contrôle du contraste du fil selon le périmètre existant. Journal : `/tmp/infometrie-passage-colors.log`.

Les sections suivantes conservent l’historique de la première présentation, avec son bandeau d’action.

## Première présentation

Itération du 22 septembre 2026, après validation de la navigation générale. Le parcours reste **lire le fil, puis écouter un passage**, pour un public de 45 à 80 ans.

## Choix de présentation

- Le sujet prend la forme d’un titre de presse : police système à empattements, graisse affirmée et interligne plus aéré. Le corps et les commandes restent en police système sans empattements.
- Source à gauche et heure à droite : deux repères stables pour parcourir les cartes. Le pictogramme distingue radio et télévision.
- La personne et son affiliation disposent de toute la largeur du texte ; un filet discret remplace l’avatar d’initiales. Aucune photographie inventée.
- Le bandeau légèrement bleuté distingue **Lire et écouter** des informations du passage. Toute la carte conserve la même destination ; la durée s’exprime en secondes et minutes, et n’est affichée que si elle est connue. Les passages sans média portent **Lire le passage**.
- La période et le nombre de résultats partagent une ligne pour rapprocher les cartes du haut de l’écran.
- Les textes restent complets et suivent Dynamic Type. Avec les tailles d’accessibilité, source/heure et action/durée passent en colonne. Contraste, mode sombre et boutons de 52 points sont conservés.

Cette proposition est implémentée dans l’application SwiftUI existante. Elle ne modifie ni les données, ni l’authentification, ni la synchronisation du lecteur.

## Référence

[Avant cette itération](avant.png) — capture de la version précédente, issue de la refonte UX validée. Données fictives de démonstration.

## Captures de l’implémentation

[Fil clair](fil-clair.png) · [Fil sombre](fil-sombre.png) · [Après défilement](fil-defile.png) · [En-tête en très grands caractères](grands-caracteres.png).

Ces captures viennent de `build/FeedRedesign.xcresult`, sur iPhone 17 Pro / iOS 26.4. Elles montrent exclusivement le jeu de démonstration fictif.

Le contrôle complémentaire `build/FeedLargeText.xcresult` passe également (1 test, zéro échec) et montre la [carte avec la taille maximale](carte-grands-caracteres.png), puis son [bandeau d’action après défilement](action-grands-caracteres.png). Les textes reviennent à la ligne et les métadonnées restent accessibles.

## Validation

- Compilation avec le SDK iOS 27 : `BUILD SUCCEEDED`.
- Les trois parcours ciblés passent dans `build/FeedRedesign.xcresult` : thème sombre et très grands caractères ; fil → filtres → suivis → passage → podcast ; formulaire/filtres et audit du fil (`TEST SUCCEEDED`, zéro échec).
- Le contrôle automatisé du fil vérifie contraste, texte tronqué et zones tactiles. Le contraste est contrôlé sur les cartes entièrement visibles, puis après défilement, selon le périmètre documenté dans [la validation précédente](../README.md#validation).

L’application normale a été relancée dans le simulateur après les tests.

Les tests techniques et l’inspection visuelle ne remplacent pas une observation avec les utilisateurs concernés.
