# Fil dense, inspiré des interfaces sociales

Direction du 23 septembre 2026, à la demande de remplacer la présentation éditoriale par une interface plus dense et moderne, proche de X.

- Une seule colonne de publications sur iPhone et iPad : avatar de 44 points, personne, fonction, texte, puis média/date et type/durée. La date reste alignée à droite.
- Typographie système sans empattements : `headline` pour les personnes, `body` pour le texte, `subheadline` pour les fonctions et `footnote` pour les métadonnées. Toutes ces tailles suivent Dynamic Type et le réglage de confort de lecture.
- Le fil présente jusqu’à cinq lignes de texte et une ligne de fonction aux tailles courantes. La fiche conserve le contenu complet. Aux tailles d’accessibilité, le texte du fil n’est pas limité et utilise toute la largeur sous la personne.
- En-tête compact et filtres de type persistants pendant le défilement. Les filtres cessent d’être épinglés aux tailles d’accessibilité pour conserver une zone de lecture suffisante.
- Navigation native en bas sur iPhone ; destinations dans une colonne latérale sur iPad. Aux tailles d’accessibilité, les destinations iPad passent dans une rangée défilante pour libérer la largeur de lecture ; la rubrique active est automatiquement amenée entièrement à l’écran.
- Palette shadcn Indigo : fond blanc ou noir, surfaces neutres, séparateurs fins et actions indigo. Détails, lecteur, suivis, filtres, connexion et compte utilisent les mêmes composants.

Le modèle reste celui d’une application de consultation : la ligne ouvre la fiche et le lecteur existants. Aucun compteur ni bouton de réaction sociale n’est ajouté.

Référence typographique : [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/typography).

## Palette shadcn Indigo

Source actuelle choisie par l’utilisateur : [preset shadcn/ui `b37ZhrNVw`](https://ui.shadcn.com/create?preset=b37ZhrNVw), style **Nova**, base **Neutral**, thème **Indigo**, rayon **Large**. Les variables sont relevées dans **Get Code → Theme** et archivées dans [shadcn-indigo.json](shadcn-indigo.json). La palette remplace Minimal Neutral, dont les [tokens d’origine](minimal-neutral.json) restent conservés comme historique.

L’adaptation native garde les polices système, SF Symbols, Dynamic Type et la structure dense. Les champs et la sélection de navigation partagent un rayon de 14 points, correspondant au rayon `0.875rem` du preset. Les commandes principales conservent leur forme de capsule et leurs surfaces tactiles.

| Usage | Clair | Sombre |
| --- | --- | --- |
| Fond | `#FFFFFF` | `#0A0A0A` |
| Texte principal | `#0A0A0A` | `#FAFAFA` |
| Bouton principal | `#432DD7` | `#372AAC` |
| Texte sur le bouton | `#EEF2FF` | `#EEF2FF` |
| Action sans fond / accent natif | `#432DD7` | `#A3B3FF` |
| Métadonnées | `#737373` | `#A1A1A1` |
| Surface / sélection | `#F5F5F5` | `#262626` |
| Navigation iPad | `#FAFAFA` | `#171717` |
| Séparateur | `#E5E5E5` | blanc à 10 % |
| Bordure de champ | `#E5E5E5` | blanc à 15 % |
| Action destructive | `#E7000B` | `#FF6467` |

Les libellés informatifs de type (Intervention, Citation, Publication X) utilisent le texte principal, afin de conserver leur contraste près de la barre native et de ne pas les confondre avec des actions. Le primaire sombre original est destiné à un bouton rempli. Pour les liens, les icônes et la navigation, `Brand.tint` emploie l’indigo clair `chart-1` du même preset ; cela donne 7,53:1 sur les surfaces grisées sombres. Les boutons principaux atteignent 7,24:1 en clair et 8,99:1 en sombre. Les métadonnées dépassent 4,5:1. Les petits textes secondaires sur surfaces grisées conservent le gris renforcé `#686868` / `#B3B3B3`. Les valeurs OKLCH sont converties en sRGB ; l’AccentColor du catalogue suit la teinte des actions sans fond.

## Captures et vérifications

[Fil iPhone clair](iphone-fil.png) · [Fil iPhone sombre](iphone-fil-sombre.png) · [Fil iPad clair](ipad-fil.png) · [Fil iPad sombre](ipad-fil-sombre.png) · [Compte iPad](ipad-compte.png) · [Texte maximal sur iPad](ipad-accessibilite.png). Ces captures utilisent exclusivement des données fictives de démonstration.

Compilation avec le SDK iOS 27, vérification sur les simulateurs iPhone 17 Pro et iPad mini (5e génération), sous iOS/iPadOS 26.4.

### Validation du preset Indigo

La compilation et quatre parcours ciblés passent : connexion, filtres et audit du fil sur iPhone (`IndigoPhoneContrast`, 37,5 s) ; sombre et grands caractères sur iPhone (`IndigoPhoneVerify`, 52,5 s) ; filtres en sombre et texte maximal, puis conservation de la sélection entre rubriques sur iPad (`IndigoPad`, 116,3 s et 16,7 s).

Le contrôle de contraste iPhone a identifié le libellé de type près de la barre inférieure. Son passage au premier plan principal corrige cette alerte ; l’audit final passe. Le parcours sombre/grands caractères a rencontré un échec intermittent sur la présence du lecteur lors du premier lancement, puis a réussi au second. Les captures du fil ont été renouvelées après la correction du contraste. L’audit automatique complet iPad n’a pas été relancé pour cette palette ; les deux alertes historiques décrites ci-dessous ne sont donc pas déclarées résolues.

### Historique : validation de la structure du fil

Parcours contrôlés : lecture et grandes tailles de texte sur iPhone, persistance du confort de lecture, publications X sans lecteur audio, création et gestion des suivis, lecture d’une séquence et podcast, conservation du filtre entre les rubriques, filtres en mode sombre et avec le texte maximal sur iPad.

Les tests d’interface repèrent désormais la colonne de navigation iPad et les filtres épinglés pour délimiter la zone de lecture. La zone tactile des publications inclut explicitement toute la ligne, y compris les espaces autour du texte.

Historique de la refonte du fil, avant les changements de palette : sept parcours distincts ont réussi :

- iPhone : sombre/grands caractères et confort de lecture (`SocialFeedPhone`, deux cas réussis) ; publication X et filtres associés (`SocialFeedPhoneFollowup`) ; connexion, filtres et audit de contraste/texte/zones tactiles (`SocialFeedContrast`).
- iPad : suivis/séquence/podcast et conservation de la sélection entre rubriques (`SocialFeedPad`) ; filtres et navigation en sombre/texte maximal (`SocialFeedPadNavigationAX`, avec vérification que la rubrique active reste entièrement visible).

Le premier contrôle X a révélé une zone de clic incomplète sur les lignes courtes, corrigée et revérifiée. Le contrôle de contraste a ensuite identifié le fondu inférieur devant la barre native ; ce fondu a été retiré du fil et l’audit complet passe. Les comptes rendus `.xcresult` sont disponibles dans `build/`, les journaux sous `/tmp/infometrie-social-*.log`.


### Historique : validation de Minimal Neutral

La compilation et les parcours sombre/grands caractères passent sur iPhone (`MinimalNeutralPhoneDark`) ; filtres, compte, suivis et texte maximal passent sur iPad (`MinimalNeutralPad`, test `testFiltersDarkAppearanceAndMaximumText`). L’audit du fil clair passe sur iPhone, y compris après les derniers ajustements de pictogrammes et de défilement (`MinimalNeutralPhoneFinal`, test `testLoginFormAndEmptyFilters`, 35,8 s).

Le contrôle visuel iPad a révélé du contenu remontant derrière la barre d’état pendant le défilement : le fil est désormais limité à sa zone d’affichage. Le pictogramme X utilise une taille adaptée à son cadre et les pictogrammes médias utilisent le premier plan principal, plus contrasté. Voir [le fil après défilement](ipad-defilement.png).

Limite du contrôle automatique iPad : `MinimalNeutralPadIcons` conserve une alerte de contraste et une alerte de texte tronqué. XCTest ne fournit aucun élément pour ces deux alertes (`issue.element == nil`), ce qui empêche leur localisation précise ; elles ne sont pas ignorées par les tests et l’audit ne doit pas être présenté comme entièrement validé. Le rendu des captures, les interactions et les contrastes calculés des couleurs ont été vérifiés. Les anciens comptes rendus de la refonte ci-dessus précèdent cette modification de palette.
