# QA — Compte, carte Apparence

Périmètre : adaptation de la référence S / M / L dans l’application SwiftUI existante, le 23 septembre 2026.

## Références et comparaison

- Source : [reference.png](Docs/UX/ReadingPreferences/reference.png), 2680 × 1002 pixels. Il s’agit d’un recadrage agrandi d’une carte, sans largeur de viewport connue ; aucune mesure en points ne peut être déduite de son agrandissement.
- iPhone : [clair, M](Docs/UX/ReadingPreferences/iphone-clair.png), 1206 × 2622 pixels, viewport natif 402 × 874 points, densité 3×.
- États complémentaires iPhone : [sombre](Docs/UX/ReadingPreferences/iphone-sombre.png) et [accessibilité maximale](Docs/UX/ReadingPreferences/iphone-accessibilite.png), mêmes dimensions.
- iPad : [clair, M](Docs/UX/ReadingPreferences/ipad-clair.png) et [sombre, M](Docs/UX/ReadingPreferences/ipad-sombre.png), 1536 × 2048 pixels, viewport 768 × 1024 points, densité 2×.
- Le [texte maximal sur iPad](Docs/UX/ReadingPreferences/ipad-accessibilite.png) confirme également l’alignement final du thème en colonne et les trois segments entièrement visibles.
- Le composant source et les captures ont été ouverts ensemble pour comparer le groupe Apparence. Comparaison de l’ordre, des alignements et des proportions relatives ; pas de prétention à une superposition pixel par pixel entre le recadrage agrandi et les écrans natifs.
- État : Compte en démonstration, niveau M. La référence affiche Système ; les tests forcent Clair ou Sombre. Cette différence de valeur est intentionnelle.

## Surfaces vérifiées

- Typographie : police système Apple, texte courant et métadonnées hiérarchisés ; S / M / L lisibles, M identifié par la capsule et la graisse. Échelle native conservée, sans plafond d’accessibilité.
- Espacement : thème au-dessus, séparateur fin, trois segments égaux ; marges internes de 16 points, carte arrondie de 24 points et cibles d’au moins 44 points. La carte reste entièrement visible aux tailles courantes sur les deux appareils.
- Couleurs : blanc et gris neutres proches de la référence en clair ; déclinaison neutre sombre dans les tokens Nova / Indigo existants. Une bordure discrète distingue la carte du fond blanc de l’application.
- Images et icônes : aucune image décorative nécessaire dans la carte. Chevrons du menu natif, texte rendu nativement, aucune interface rasterisée.
- Contenu : Thème, Système / Clair / Sombre, S / M / L. La légende « Taille du texte · Standard » précise le sens des lettres. Les libellés d’accessibilité annoncent Compact / Standard / Grand.

## Historique des contrôles

1. Rendu clair iPhone et iPad, puis sombre iPad : aucun écart majeur. Les trois tailles ont un effet immédiat sur le compte et les fiches, et le choix est conservé après relance.
2. Raffinement P3 : le menu de thème était centré lorsqu’il passait en colonne à la taille d’accessibilité maximale. Le cadre utilise maintenant un alignement à gauche, vérifié sur la nouvelle capture iPhone d’accessibilité. La carte, ses lettres et le menu restent lisibles et accessibles après défilement.
3. Le premier contrôle sombre iPhone a été interrompu par un changement de sélection et un retour vers le fil non attendus par le test. La cause n’est pas établie ; le même contrôle réussit dans un simulateur de test isolé, sans modification du comportement de sélection.

## Validation

- Migration : tests Swift réussis pour les deux anciens choix et une installation sans réglage.
- iPhone : variation S / M / L, effet sur les fiches et persistance réussis (`ReadingSizesPhone`, 54,1 s).
- iPad : mêmes vérifications, mode sombre et priorité à la taille système maximale réussis (`ReadingSizesPad`, 47,8 s et 29,1 s).
- iPhone final : sombre et accessibilité maximale réussis dans `ReadingSizesPhoneFinal` (36,3 s), captures ouvertes et vérifiées.
- iPad final : même parcours après l’ajustement d’alignement, réussi dans `ReadingSizesPadFinal` (30,8 s).
- Aucun écart visuel P0/P1/P2 restant sur la carte. Aucun audit automatique global de l’application ni test manuel VoiceOver complet n’est revendiqué.

final result: passed
