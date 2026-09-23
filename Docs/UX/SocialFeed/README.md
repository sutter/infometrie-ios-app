# Fil dense, inspiré des interfaces sociales

Direction du 23 septembre 2026, à la demande de remplacer la présentation éditoriale par une interface plus dense et moderne, proche de X.

- Une seule colonne de publications sur iPhone et iPad : avatar de 44 points, personne, fonction, texte, puis média/date et type/durée. La date reste alignée à droite.
- Typographie système sans empattements : `headline` pour les personnes, `body` pour le texte, `subheadline` pour les fonctions et `footnote` pour les métadonnées. Toutes ces tailles suivent Dynamic Type et le réglage de confort de lecture.
- Le fil présente jusqu’à cinq lignes de texte et une ligne de fonction aux tailles courantes. La fiche conserve le contenu complet. Aux tailles d’accessibilité, le texte du fil n’est pas limité et utilise toute la largeur sous la personne.
- En-tête compact et filtres de type persistants pendant le défilement. Les filtres cessent d’être épinglés aux tailles d’accessibilité pour conserver une zone de lecture suffisante.
- Navigation native en bas sur iPhone ; destinations dans une colonne latérale sur iPad. Aux tailles d’accessibilité, les destinations iPad passent dans une rangée défilante pour libérer la largeur de lecture ; la rubrique active est automatiquement amenée entièrement à l’écran.
- Palette Minimal Neutral : fond blanc ou anthracite, textes neutres, séparateurs fins et actions noires ou claires selon l’apparence. Détails, lecteur, suivis, filtres, connexion et compte utilisent les mêmes composants.

Le modèle reste celui d’une application de consultation : la ligne ouvre la fiche et le lecteur existants. Aucun compteur ni bouton de réaction sociale n’est ajouté.

Référence typographique : [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/typography).

## Palette Minimal Neutral

Source choisie par l’utilisateur : [Minimal Neutral, par Luis Llanes](https://tweakcn.com/themes/cmho4nr9l000h04l1gu419ckw). Les valeurs OKLCH originales sont archivées dans [minimal-neutral.json](minimal-neutral.json) et converties en sRGB dans `Brand`. Seules les couleurs sont reprises : typographie système, Dynamic Type et structure dense sont conservés.

| Usage | Clair | Sombre |
| --- | --- | --- |
| Fond | `#FFFFFF` | `#171717` |
| Texte principal | `#0A0A0A` | `#FAFAFA` |
| Action principale | `#171717` | `#E5E5E5` |
| Texte sur l’action | `#FAFAFA` | `#171717` |
| Métadonnées | `#737373` | `#A1A1A1` |
| Surface discrète | `#EEEEEE` | `#262626` |
| Sélection | `#EEEEEE` | `#404040` |
| Navigation iPad | `#FAFAFA` | `#262626` |
| Action destructive | `#E7000B` | `#FF6467` |

Les sélections iPad utilisent les couleurs `accent` du thème. Les petits textes sur surfaces grisées utilisent un gris légèrement renforcé (`#686868` / `#B3B3B3`) : le gris secondaire original manque de contraste sur ces fonds. Les contrastes calculés sont de 4,74:1 minimum pour les métadonnées sur le fond principal et de 4,80:1 minimum sur les surfaces grisées. Les boutons principaux dépassent 14:1 dans les deux apparences. L’AccentColor du catalogue d’assets reprend également les couleurs primaires du thème.

## Captures et vérifications

[Fil iPhone clair](iphone-fil.png) · [Fil iPhone sombre](iphone-fil-sombre.png) · [Fil iPad](ipad-fil.png) · [Compte iPad](ipad-compte.png) · [Texte maximal sur iPad](ipad-accessibilite.png). Ces captures utilisent exclusivement des données fictives de démonstration.

Compilation avec le SDK iOS 27, vérification sur les simulateurs iPhone 17 Pro et iPad mini (5e génération), sous iOS/iPadOS 26.4.

Parcours contrôlés : lecture et grandes tailles de texte sur iPhone, persistance du confort de lecture, publications X sans lecteur audio, création et gestion des suivis, lecture d’une séquence et podcast, conservation du filtre entre les rubriques, filtres en mode sombre et avec le texte maximal sur iPad.

Les tests d’interface repèrent désormais la colonne de navigation iPad et les filtres épinglés pour délimiter la zone de lecture. La zone tactile des publications inclut explicitement toute la ligne, y compris les espaces autour du texte.

Sept parcours distincts ont réussi :

- iPhone : sombre/grands caractères et confort de lecture (`SocialFeedPhone`, deux cas réussis) ; publication X et filtres associés (`SocialFeedPhoneFollowup`) ; connexion, filtres et audit de contraste/texte/zones tactiles (`SocialFeedContrast`).
- iPad : suivis/séquence/podcast et conservation de la sélection entre rubriques (`SocialFeedPad`) ; filtres et navigation en sombre/texte maximal (`SocialFeedPadNavigationAX`, avec vérification que la rubrique active reste entièrement visible).

Le premier contrôle X a révélé une zone de clic incomplète sur les lignes courtes, corrigée et revérifiée. Le contrôle de contraste a ensuite identifié le fondu inférieur devant la barre native ; ce fondu a été retiré du fil et l’audit complet passe. Les comptes rendus `.xcresult` sont disponibles dans `build/`, les journaux sous `/tmp/infometrie-social-*.log`.


### Vérification de la palette

La compilation et les parcours sombre/grands caractères passent sur iPhone (`MinimalNeutralPhoneDark`) ; filtres, compte, suivis et texte maximal passent sur iPad (`MinimalNeutralPad`, test `testFiltersDarkAppearanceAndMaximumText`). L’audit du fil clair passe sur iPhone, y compris après les derniers ajustements de pictogrammes et de défilement (`MinimalNeutralPhoneFinal`, test `testLoginFormAndEmptyFilters`, 35,8 s).

Le contrôle visuel iPad a révélé du contenu remontant derrière la barre d’état pendant le défilement : le fil est désormais limité à sa zone d’affichage. Le pictogramme X utilise une taille adaptée à son cadre et les pictogrammes médias utilisent le premier plan principal, plus contrasté. Voir [le fil après défilement](ipad-defilement.png).

Limite du contrôle automatique iPad : `MinimalNeutralPadIcons` conserve une alerte de contraste et une alerte de texte tronqué. XCTest ne fournit aucun élément pour ces deux alertes (`issue.element == nil`), ce qui empêche leur localisation précise ; elles ne sont pas ignorées par les tests et l’audit ne doit pas être présenté comme entièrement validé. Le rendu des captures, les interactions et les contrastes calculés des couleurs ont été vérifiés. Les anciens comptes rendus de la refonte ci-dessus précèdent cette modification de palette.
