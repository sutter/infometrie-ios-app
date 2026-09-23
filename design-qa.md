# Refonte éditoriale — version 2 « Revue »

Date : 23 septembre 2026.

## Résultat

Le fil reprend la composition de la deuxième image choisie : premier passage sur toute la largeur, puis deux colonnes, fond papier, encre bleu nuit, accents bordeaux et filets fins.

## Affinage des métadonnées du fil

**Choix final :** retour aux métadonnées de l’ancienne version, avec une seule correction d’alignement. La date et l’heure complètes occupent la droite de la première ligne, comme la durée sur la deuxième. Les icônes, tailles, couleurs et replis adaptatifs d’origine sont restaurés. Les captures et tests de la proposition compacte ci-dessous constituent l’historique de cette itération.

À la demande suivante, le pied des passages a été compacté : média semi-gras et heure sur la même ligne, type et durée rapprochés dessous, une seule icône discrète. Le passage principal iPad utilise une ligne si elle tient ; les noms longs et grandes tailles déclenchent un repli vertical. Les dates du jour sont réduites à l’heure, « Hier » distingue la veille et la date complète reste accessible à VoiceOver.

La [comparaison iPhone avant/après](Docs/UX/FeedMetadata/comparison-iphone.png) utilise le même viewport et les mêmes données fictives. Les vues claire, sombre, défilée et au texte maximal, ainsi que la grille iPad, ont été inspectées. Le point textuel initial déclenchait une alerte de contraste ; sa représentation décorative corrige ce contrôle. `build/FeedMetadataPhoneFinal.xcresult` : **2 tests réussis, zéro échec et avertissement**, sans changer les assertions du pilote. [Preuves et portée](Docs/UX/FeedMetadata/README.md).

## Extension du thème aux autres pages

La première vérification portait principalement sur le fil. Le périmètre inclut désormais toutes les vues de l’application : suivis actifs/archivés et état vide, compte, connexion et erreur, quota d’appareils, filtres, choix des personnalités et partis, enregistrement d’un suivi, séquence et ses volets, verbatim, écoute continue et file de lecture. Les confirmations et contrôles système restent natifs.

Les surfaces blanches arrondies des écrans secondaires ont été remplacées par le papier et des filets. Les titres de page, de section et de passage utilisent le serif commun ; les commandes et métadonnées restent en sans-serif. Les actions principales utilisent la même capsule encre/papier que le fil, y compris en sombre. Les champs gardent un fond discret et une ligne de base ; l’adresse exemple utilise du texte littéral pour éviter sa transformation automatique en lien bleu.

`Docs/UX/Editorial/pages-ipad.png` réunit la référence choisie et sept écrans secondaires. `pages-iphone.png` réunit huit vues compactes. Ces planches ont été inspectées ensemble pour comparer couleurs, typographie, alignements, séparateurs, commandes et hiérarchie. Les écrans secondaires sont une déclinaison de la direction choisie, pas des maquettes supplémentaires fournies par l’utilisateur.

Les captures individuelles `ipad-compte.png`, `ipad-suivis.png`, `ipad-filtres.png`, `ipad-personnalites.png`, `ipad-enregistrer.png`, `ipad-sequence.png`, `ipad-podcast.png` et leurs équivalents iPhone servent au contrôle détaillé. Les captures des filtres, du compte et du lecteur au texte maximal sont conservées séparément. Les coupures au bord des zones défilantes sont attendues : les commandes persistantes restent accessibles, le contenu complet reste défilable et aucune limite de lignes ne supprime du texte.

## Cible et preuves visuelles

- Source choisie : `Docs/UX/Editorial/reference-revue.png`, deuxième image affichée dans la conversation. La préférence initiale pour la version 1 a été corrigée avant l’implémentation.
- Source : 1048 × 1501 px, maquette conçue pour une tablette 834 × 1194 pt.
- Implémentation finale : `Docs/UX/Editorial/ipad-light.png`, issue de `build/EditorialTabletVerified.xcresult`.
- Comparaison commune : `Docs/UX/Editorial/comparison-final.png`. Source et application sont réunies dans la même image, chacune à 768 px de large, sans déformation. La capture native est ramenée de 2× à 1× et les 64 px de barre système sont retirés. La maquette conserve sa hauteur naturelle ; le viewport du mini est plus court.
- Comparaison ciblée des identités, titres, métadonnées et colonnes : `Docs/UX/Editorial/comparison-detail.png`, extraite de la comparaison commune et inspectée après la dernière correction.
- iPad mini 5 : 768 × 1024 pt / 1536 × 2048 px, densité 2×, iPadOS 26.4. iPhone 17 Pro : 402 × 874 pt / 1206 × 2622 px, densité 3×, iOS 26.4. SDK de compilation iOS 27. Application SwiftUI native, sans viewport CSS ni navigateur.
- État comparé : Le fil, Tous, cinq passages fictifs, thème clair, même ordre chronologique. Les heures sont calculées au lancement et diffèrent de la maquette.
- États complémentaires inspectés : `ipad-dark.png`, `ipad-large-text.png`, `ipad-navigation-return.png`, `iphone-light.png`, `iphone-dark.png`, `iphone-large-text.png`, `iphone-large-player.png`, dans `Docs/UX/Editorial`.

## Surfaces de fidélité contrôlées

- **Typographie.** Serif système pour le logotype, le titre du fil, la date et les titres de passage ; sans-serif système pour les commandes et les identités. Échelles de base tablette 112 / 52 / 35 pt pour le titre du fil, le passage de tête et les colonnes, avec Dynamic Type. Les contenus longs restent multilignes, sans ellipses imposées. La chasse du serif natif et le viewport plus étroit font passer le troisième titre sur trois lignes sur le mini ; son contenu et sa provenance restent lisibles. Cette adaptation est acceptée.
- **Espacement et structure.** Marges tablette de 36 pt, gouttière de 40 pt entre colonnes, filets de 0,5 pt, pas de cartes ni d’ombres dans le fil. Navigation et catégories distinctes, avec soulignement visible. Grille remplacée par une colonne sous 650 pt et au-delà de Dynamic Type xxLarge. La barre d’onglets native est conservée sur iPhone.
- **Couleurs et états.** Papier blanc cassé, encre bleu nuit et bordeaux. Variantes sombres explicites ; sélection signalée aussi par le soulignement et le trait d’accessibilité. L’audit de contraste du fil passe dans le périmètre des éléments entièrement exposés. Les suivis, le compte, les formulaires et les lecteurs reprennent aussi les surfaces et les titres éditoriaux, au-delà du seul fond papier.
- **Images et icônes.** Aucun asset photographique ou illustré dans cette maquette. Initiales et logotype sont du texte natif ; icônes vectorielles SF Symbols. Pas d’image étirée ni de texte rasterisé. Les initiales décoratives sont plafonnées à 64 pt pour laisser la place au nom lorsque le texte augmente.
- **Copie et contenu.** Ordre personnalité → passage → provenance conservé. Libellés existants et contenus fictifs préservés. Le premier résultat chronologique est mis en avant, sans classement éditorial ajouté. Le bouton Filtrer reste accompagné de son texte sur iPhone. Dates issues des données et date courante du système.

## Historique des corrections

1. **P1 — Retour de fiche sur iPad.** `safeAreaInset` plaçait l’en-tête sur la barre native : bouton Précédent à y=32…76, en-tête à y=0…88. Deux tests échouaient dans `build/EditorialTablet.xcresult`. Correction : en-tête dans une pile au-dessus du `TabView`, sans recouvrement. Les parcours de retour passent ensuite.
2. **P2 — Titres tablette trop petits.** La comparaison `comparison-initial.png` montrait une hiérarchie trop timide. Correction : échelles des titres renforcées ; résultat contrôlé dans la comparaison finale et son détail.
3. **P2 — Libellé Filtrer masqué sur iPhone.** Le style automatique réduisait le bouton à une icône. Correction : `labelStyle(.titleAndIcon)`. Le texte est présent dans `iphone-light.png` et au texte maximal.
4. **P2 — Initiales encombrantes au texte maximal.** Correction : taille décorative limitée à 64 pt, noms et contenus toujours agrandis. `iphone-large-text.png` montre l’identité sans avatar démesuré ; la fiche et le lecteur restent accessibles.
5. **P1 — Navigation en double après déplacement de l’en-tête.** `comparison-navigation-iteration.png` montrait encore la barre native. Correction : visibilité définie dans chaque destination du `TabView`. Assertion dédiée à l’absence de deuxième barre sur iPad, parcours réussi et absence du doublon dans `comparison-final.png`.
6. **Provenance du passage de tête.** La durée est alignée à droite grâce à une ligne qui utilise la largeur disponible. En colonne étroite, les métadonnées passent sur plusieurs lignes sans être tronquées.

7. **P2 — Thème incomplet sur les pages secondaires.** Harmonisation des dix fichiers de vues et de l’état de chargement racine. Composants communs pour les titres de page/section, les messages vides, les champs et les actions. Présentation partagée de l’identité et du passage entre séquence et écoute continue.
8. **Pilote de tests aux tailles maximales.** Les gestes fixes pouvaient dépasser une feuille iPad de 540 pt ou laisser le premier passage hors écran. Une requête d’identifiant échouait aussi avant la création d’une ligne paresseuse de `List`. Le pilote calcule maintenant la zone depuis la barre et le pied de la feuille, vérifie l’existence avant de lire l’identifiant et ajuste le sens/distance du défilement. Les assertions de sélection, d’accès au lecteur et de position du son restent inchangées.

## Vérification de toutes les pages

- Première série iPad, `build/EditorialAllPagesTablet.xcresult` : 6 parcours ; 4 réussis (suivis complets / archivage / restauration / suppression, fiches et podcast, navigation, connexion avec restauration et déconnexion, remplacement d’appareil fictif). Deux parcours aux grandes tailles ont échoué dans le pilote, puis ont été corrigés comme décrit ci-dessus.
- Reprise iPad, `build/EditorialAllPagesTabletAccessible.xcresult` : **2 tests réussis, 0 échec, 0 avertissement**. Filtres, sélection et compte en sombre/texte maximal ; fiche et clic sur un mot au texte maximal avec transport toujours accessible.
- Première série iPhone, `build/EditorialAllPagesPhone.xcresult` : 6 parcours ; 5 réussis (cycle des suivis, connexion/quota, filtres et audit du fil, thème sombre/grands caractères, clic dans le verbatim et déplacement du curseur). Le parcours des filtres maximaux a échoué sur la ligne non encore créée ; il fait partie de la reprise finale.

- Reprise finale iPhone, `build/EditorialAllPagesPhoneFinal.xcresult` : **3 tests réussis, 0 échec, 0 avertissement**. Suivis/compte/filtres et sélection en sombre/texte maximal ; formulaire et erreurs de connexion (identifiants invalides, abonnement inactif, réseau, nouvelle tentative) ; filtres et audit du fil exposé. Les champs de connexion et la notice d’erreur ont été inspectés sur les captures finales.
- Les six parcours iPad et sept parcours iPhone distincts exécutés pour cette extension ont tous une exécution réussie. Les deux bundles de reprise sont sans échec. Aucun changement du client API, de la persistance des suivis ou du moteur de lecture.
- Dernière version installée et relancée en démonstration claire sur l’iPad mini ; présence à l’écran vérifiée dans Device Hub. `git diff --check` passe. Aucun problème P0/P1/P2 restant dans le périmètre visuel contrôlé.

## Vérification initiale du fil

- `build/EditorialTabletVerified.xcresult` : **3 tests, 0 échec, 0 avertissement**. Navigation entre les trois destinations, conservation du type sélectionné, fiche / retour, synchronisation avec le panneau de filtres, podcast limité à la sélection, thème sombre et texte maximal.
- `build/EditorialPhoneFinal.xcresult` : **3 tests, 0 échec, 0 avertissement**. Navigation, thème sombre, texte maximal, fiche / lecture / clic dans le verbatim, filtres et audit de contraste / texte tronqué / cibles tactiles sur les passages entièrement visibles.
- Première série iPhone complémentaire : `build/EditorialPhone.xcresult`, **3 tests réussis**, couvrant aussi le podcast filtré et les trois types au texte maximal.
- La dernière compilation a été installée et ouverte dans les deux simulateurs. La barre native de l’iPhone et l’en-tête unique de l’iPad ont été inspectés.
- `git diff --check` passe. Aucun changement du client API, du filtrage métier ou du moteur audio. La configuration de signature déjà modifiée dans le projet n’a pas été touchée.

## Limites et finitions

- Validation sur simulateurs iOS/iPadOS 26.4 avec SDK 27 ; pas de revendication de validation sur un runtime iOS 27 ni sur un appareil physique.
- L’audit automatisé d’accessibilité porte sur le fil exposé, pas sur une certification globale de l’application. Les grandes tailles, les thèmes et la lecture ont aussi été contrôlés visuellement et par parcours.
- P3 facultatif : affiner la chasse des titres de colonne pour rapprocher certaines coupures de ligne de la maquette. Le serif système et la lisibilité native ont été privilégiés ; aucune correction supplémentaire n’est nécessaire pour livrer cette version.

## Checklist

- [x] Référence sélectionnée sans ambiguïté et intégrée en SwiftUI.
- [x] Captures comparées ensemble, en vue complète et en détail.
- [x] P1/P2 corrigés puis contrôlés à nouveau.
- [x] Navigation, filtres et lecture vérifiés sur iPad et iPhone.
- [x] Thèmes et grandes tailles contrôlés.
- [x] Suivis, compte, formulaires, sélecteurs et lecteurs harmonisés et contrôlés sur captures.
- [x] Échecs du pilote corrigés puis parcours concernés rejoués avec succès.
- [x] Application laissée ouverte dans le simulateur iPad mini.

final result: passed
