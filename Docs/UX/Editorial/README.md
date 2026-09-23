# Direction éditoriale « Revue »

La deuxième proposition a été choisie le 23 septembre 2026 : une composition de magazine, un fond blanc cassé, une encre bleu nuit et des accents bordeaux.

Le premier résultat du fil occupe toute la largeur. Les suivants sont présentés par paires sur iPad, dans l’ordre chronologique de gauche à droite. Chaque passage conserve l’ordre personnalité et rôle → titre → source, date, type et durée. Les colonnes deviennent une liste unique sur iPhone, dans les fenêtres étroites et aux plus grandes tailles de texte.

Les trois destinations gardent leurs piles de navigation. L’iPad utilise l’en-tête éditorial et l’iPhone sa barre d’onglets native. Les catégories soulignées utilisent les filtres existants et exposent leur état sélectionné à l’accessibilité.

## Déclinaison sur les autres écrans

Le thème s’applique aussi aux suivis actifs et archivés, au compte, à la connexion, à la limite d’appareils, aux filtres et sélecteurs, à l’enregistrement d’un suivi, aux fiches de passage, au verbatim et à l’écoute continue.

- `EditorialPageHeading` porte les grands titres serif et le repère bordeaux ; `EditorialSection` structure les réglages et formulaires avec des filets fins.
- Les listes utilisent le fond papier et des séparateurs. Les boutons principaux sont des capsules pleines encre/papier, les secondaires des capsules à contour fin ; ils gardent une hauteur tactile minimale de 52 pt.
- `PassageHeading` conserve la même hiérarchie dans une fiche et dans l’écoute continue : identité, titre, provenance. Le verbatim utilise un serif de lecture et un surlignage bordeaux pour le mot actif.
- Les contrôles système restent natifs : recherche, interrupteur, menu de thème, slider, boutons de retour, confirmations et clavier. La couleur, les titres et les surfaces qui les entourent suivent le thème.
- Les messages d’erreur et les écrans vides reprennent les mêmes couleurs, typographies et séparateurs.

## Captures

- [Vue d’ensemble iPad et référence](pages-ipad.png), [vue d’ensemble iPhone](pages-iphone.png)
- [Compte](ipad-compte.png), [suivis](ipad-suivis.png), [filtres](ipad-filtres.png), [personnalités](ipad-personnalites.png), [enregistrement](ipad-enregistrer.png)
- [Séquence](ipad-sequence.png), [écoute continue](ipad-podcast.png), [connexion](iphone-connexion.png), [erreur de connexion](iphone-connexion-erreur.png), [appareils](iphone-appareils.png)
- [Sélection au texte maximal sur iPad](ipad-personnalites-accessibles.png), [sur iPhone](iphone-personnalites-accessibles.png), [lecteur iPad agrandi](ipad-lecteur-accessible.png)
- [Maquette choisie](reference-revue.png)
- [Comparaison finale](comparison-final.png) et [détail des passages](comparison-detail.png)
- [iPad clair](ipad-light.png), [sombre](ipad-dark.png), [texte maximal](ipad-large-text.png)
- [iPhone clair](iphone-light.png), [sombre](iphone-dark.png), [texte maximal](iphone-large-text.png), [lecteur agrandi](iphone-large-player.png)

Les captures utilisent exclusivement des données de démonstration. Le format de référence est plus haut que celui de l’iPad mini ; la comparaison normalise la largeur sans déformer les images.

## Validation

Extension à toutes les pages : six parcours iPad et sept parcours iPhone distincts ont une exécution réussie. Les séries initiales `EditorialAllPagesTablet.xcresult` et `EditorialAllPagesPhone.xcresult` couvrent les suivis, la connexion, le quota, les fiches et la lecture. Les parcours aux grandes tailles ont été repris après adaptation du pilote aux feuilles iPad et aux lignes paresseuses : `EditorialAllPagesTabletAccessible.xcresult` (**2/2**) et `EditorialAllPagesPhoneFinal.xcresult` (**3/3**), sans échec ni avertissement. La dernière série vérifie aussi les erreurs de connexion et l’audit du fil exposé. Les captures de connexion ont été actualisées après correction des champs indicatifs. La version finale est installée et ouverte sur l’iPad mini.

Validation initiale du fil : Trois parcours iPad et trois parcours iPhone réussis dans `build/EditorialTabletVerified.xcresult` et `build/EditorialPhoneFinal.xcresult`, sans échec ni avertissement. Le contrôle couvre navigation / retour, filtres, podcast, lecture, mode sombre et texte maximal ; l’audit automatisé du fil contrôle contraste, texte tronqué et cibles tactiles dans la zone entièrement exposée.

[Rapport détaillé et historique des corrections](../../../design-qa.md). Exécution sur iOS/iPadOS 26.4, compilation avec SDK iOS 27.
