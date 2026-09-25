# Apparence et taille de lecture

La [référence fournie](reference.png) réunit le thème et un sélecteur S / M / L dans une seule carte. Le compte reprend cette organisation, avec la [palette Stoic](../Stoic/README.md) de l’application.

- Le menu Thème propose Système, Clair et Sombre.
- Les trois segments de même largeur proposent Compact, Standard et Grand. Leur surface tactile mesure au moins 44 points ; VoiceOver annonce leur sens complet et la sélection.
- Le réglage s’applique immédiatement au compte, au fil, aux fiches et aux autres écrans. Il est conservé après fermeture de l’application.
- Les tailles suivent l’échelle native Apple, relativement à la taille de texte du système : S un cran en dessous, M la taille système, L un cran au-dessus. À la taille système par défaut, cela donne `.medium`, `.large` et `.xLarge` (corps de texte de 16, 17 et 19 points). M est le choix initial.
- Correction du 25 septembre 2026 : les tailles étaient absolues et la taille système l’emportait dès qu’elle dépassait la taille par défaut. Sur un iPhone réglé en XL, S, M et L donnaient alors le même résultat. Une taille d’accessibilité système n’est toujours jamais réduite, et une taille standard ne bascule jamais dans les tailles d’accessibilité.
- Seules les tailles d’accessibilité système restent prioritaires : S ou M ne réduit pas le texte, et L l’agrandit d’un cran au plus.
- L’ancien choix explicite « Texte plus grand » est migré vers L ; le choix désactivé vers M. La migration ne remplace jamais un choix S / M / L déjà enregistré.

Le sélecteur emploie des boutons SwiftUI avec état sélectionné et libellés accessibles. La hauteur accompagne Dynamic Type, sans plafond. Le menu de thème passe sur une deuxième ligne aux tailles d’accessibilité.

Références Apple : [typographie](https://developer.apple.com/design/human-interface-guidelines/typography), [contrôles segmentés](https://developer.apple.com/design/human-interface-guidelines/segmented-controls), [Dynamic Type](https://developer.apple.com/documentation/swiftui/environmentvalues/dynamictypesize).

## Captures et validation

[iPhone clair](iphone-clair.png) · [iPhone sombre](iphone-sombre.png) · [iPhone, texte maximal](iphone-accessibilite.png) · [iPad clair](ipad-clair.png) · [iPad sombre](ipad-sombre.png) · [iPad, texte maximal](ipad-accessibilite.png).

Tests de migration réussis pour les anciennes valeurs activée/désactivée et une installation sans préférence. Les parcours S / M / L vérifient l’effet immédiat sur le compte et une fiche, les cibles tactiles, la sélection exclusive et la persistance après relance : `ReadingSizesPhone` (54,1 s) et `ReadingSizesPad` (47,8 s). Les parcours sombre / accessibilité maximale passent sur iPad (29,1 s) et sur iPhone isolé (`ReadingSizesPhoneFinal`, 36,3 s). Le premier essai sombre iPhone avait rencontré un changement de sélection et un retour au fil inattendus ; le contrôle isolé ne les reproduit pas.

Après le dernier ajustement d’alignement, le contrôle sombre / accessibilité iPad a de nouveau réussi (`ReadingSizesPadFinal`, 30,8 s).

Comparaison visuelle et limites : [design-qa.md](../../../design-qa.md). Compilation SDK iOS 27, simulateurs iPhone 17 Pro et iPad mini (5e génération) sous iOS/iPadOS 26.4. Données exclusivement fictives dans les captures.
