# Métadonnées du fil — 23 septembre 2026

## Présentation retenue

Retour à la présentation éditoriale précédente, selon la dernière préférence exprimée : pictogrammes et tailles d’origine, média à gauche et date/heure complète à droite ; type à gauche et durée avec casque à droite sur la deuxième ligne. Le seul ajustement par rapport à cette présentation concerne l’alignement de la date.

La première ligne peut désormais occuper la largeur disponible : `fixedSize` s’applique au média et à la date individuellement, et laisse le `Spacer` aligner cette dernière à droite. Le repli vertical pour les grandes tailles et le format large iPad sont conservés.

Compilation réussie et version installée sur les deux simulateurs. Alignement des deux lignes vérifié visuellement sur l’iPhone 17 Pro avec les données de la session habituelle ; application laissée ouverte. Aucune nouvelle suite de tests pour cette correction de disposition. Journal : `/tmp/infometrie-feed-date-alignment-build.log`.

## Proposition précédente — remplacée

Les captures et résultats ci-dessous documentent la proposition compacte, remplacée par le retour à l’ancienne présentation décrit ci-dessus.

Le pied de chaque passage reprend la hiérarchie éditoriale « Revue », avec moins de pictogrammes et un regroupement du type et de la durée.

- Le média est en sans-serif semi-gras, avec une seule icône TV/radio discrète. L’heure s’aligne à droite.
- « Intervention · 24 s » ou « Citation · 18 s » occupe une ligne secondaire compacte. Le type conserve l’accent bordeaux ; la durée utilise la couleur secondaire. Les icônes de type et de casque sont supprimées.
- Aujourd’hui, seule l’heure est affichée. La veille utilise « Hier » ; les dates antérieures conservent jour/mois et heure. VoiceOver dispose de la date complète, du type de média et du libellé de durée.
- Le passage principal sur iPad réunit les métadonnées sur une ligne lorsque la largeur le permet. Les colonnes et l’iPhone utilisent deux lignes ; les noms longs et grandes tailles passent sur plusieurs lignes sans limite imposée.
- Le séparateur est une forme décorative masquée à VoiceOver. La durée reste absente si le passage n’a pas de média ou de durée positive. Toute l’entrée ouvre toujours la fiche.

Modification ciblée dans `Infometrie/Views/FeedCard.swift`, sans changement de services, filtres ou lecteur.

## Contrôle

- [Avant / après iPhone](comparison-iphone.png), à largeur identique de 402 px, mêmes passages fictifs ; les heures diffèrent car elles sont calculées au lancement.
- [iPhone clair](iphone-light.png), [fil défilé](iphone-scrolled.png), [sombre](iphone-dark.png), [texte maximal](iphone-large-text.png) et [iPad mini](ipad-light.png) inspectés.
- `build/FeedMetadataPhoneFinal.xcresult` : **2 tests réussis, zéro échec et avertissement**. Parcours existants des filtres/annulation avec audit du fil exposé (contraste, texte tronqué, cibles tactiles), puis sombre/texte maximal avec ouverture du passage, lecture et clic dans le verbatim.
- La première exécution signalait le contraste du caractère « · » isolé. Le séparateur est désormais dessiné comme une décoration ; le même audit passe, sans modification des assertions ni des exclusions.
- iPhone 17 Pro et iPad mini 5, iOS/iPadOS 26.4, SDK 27. Contrôle visuel iPad ; parcours automatisés ciblés iPhone. « Hier » également observé lors de la relance de l’application normale sur iPhone ; les captures conservées utilisent uniquement les données fictives du jour. Les dates antérieures sont prévues dans le code mais ne figurent pas dans ces captures.
