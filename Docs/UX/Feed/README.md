# Le fil — une lecture plus éditoriale

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
