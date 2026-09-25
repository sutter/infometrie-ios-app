# Direction Stoic — surfaces neutres et arrondies

Direction actuelle et source de vérité du design, appliquée le 24 septembre 2026. Elle remplace la palette Nova / Indigo du [fil dense](../SocialFeed/README.md), dont la structure reste en place.

Référence : [l’application Stoic sur Mobbin](https://mobbin.com/apps/stoic-ios-621f0be7-8046-45cd-b667-97add5f9c3c7/e20c833d-975b-401c-8601-74d135883e25/screens) (compte Mobbin requis). Il n’existe pas de maquette : le design se fait directement dans le code, et [`Design.swift`](../../../Infometrie/Views/Design.swift) en porte les valeurs.

## Principes

- Surfaces neutres, faible contraste entre le fond et les cartes, coins arrondis.
- La couleur est réservée aux logos des médias et aux actions destructives. Liens, icônes et navigation utilisent une encre neutre.
- La hiérarchie du fil dense est conservée : personne, fonction, texte, puis média et date, type et durée.
- La fiche d’un passage reprend exactement la ligne de métadonnées des cartes (média, type, date, durée sur une ligne). La date s’écrit partout « 25/09 14:39 ».
- Typographie système, Dynamic Type sans plafond, réglage S / M / L, cibles tactiles d’au moins 44 points.
- Le fil défile sous la barre d’onglets flottante, et le dernier passage reste accessible.
- Le mot courant du verbatim est mis en évidence en encre inversée (bouton principal et son texte).
- X est représenté partout (types du fil, cartes, fiche) par son logo seul, un symbole personnalisé (`x.logo`) dont les traits sont épaissis pour rester lisibles à petite taille, posé sur une tuile en encre inversée comme les logos de médias des cartes : tuile noire en clair, claire en sombre. La tuile garde le même contraste que l’onglet soit sélectionné ou non ; le soulignement marque la sélection.

## Palette

| Usage | Clair | Sombre | Jeton |
| --- | --- | --- | --- |
| Fond | `#F1F2F3` | `#08090A` | `background` |
| Carte | `#FFFFFF` | `#151719` | `card` |
| Texte principal | `#111214` | `#F5F5F4` | `ink` |
| Bouton principal | `#151618` | `#F1F1EF` | `primary` |
| Texte sur le bouton | `#FFFFFF` | `#111214` | `primaryForeground` |
| Liens, icônes, navigation | `#292B2E` | `#E6E6E4` | `tint` |
| Métadonnées | `#696B70` | `#A0A2A6` | `secondary` |
| Petit texte sur surface grisée | `#686868` | `#B3B3B3` | `secondaryOnSurface` |
| Surface | `#E7E8EA` | `#1D1F22` | `surface` |
| Sélection | `#E7E8EA` | `#292B2E` | `selection` |
| Navigation iPad | `#F1F2F3` | `#0D0E10` | `sidebar` |
| Séparateur | `#DCDDDF` | blanc à 9 % | `rule` |
| Bordure de champ | `#DCDDDF` | blanc à 8 % | `inputBorder` |
| Action destructive | `#E7000B` | `#FF6467` | `destructive` |

`AccentColor`, dans le catalogue d’assets, reprend les valeurs de `tint` par cohérence. Sous iOS 26.4, les alertes et les menus système ne l’utilisent pas : leur rendu est identique au pixel près avec l’ancien indigo, en clair comme en sombre (vérifié le 25 septembre 2026).

Mesures communes (`AppLayout`) : rayon des contrôles de 14 points, largeur maximale de 1 100 points, largeur de lecture de 760 points, marge large de 24 points.
