# Filtres du fil — continuité avec les cartes et la fiche

Itération du 22 septembre 2026. Le parcours reprend les titres à empattements, les cartes arrondies et les actions bleues du fil et de la fiche de séquence, pour un public de 45 à 80 ans.

## Choix

- Deux groupes : **Qui suivre ?** pour les personnalités et les partis ; **Quels passages ?** pour les interventions et les citations. Le texte explique chaque type de passage.
- Chaque rangée est entièrement tactile. Une coche et un fond teinté indiquent les choix actifs ; la couleur n’est pas le seul repère.
- Le choix **Citations** reprend l’accent rouge du fil et de la fiche ; **Interventions** conserve le bleu. [Voir les citations sélectionnées](citations-rouges.png), capture contrôlée dans `build/PassageColors.xcresult`.
- Les listes conservent la recherche et la sélection multiple. « Toutes les personnalités » / « Tous les partis » enlève la restriction ; le nombre de choix et **Terminé** restent visibles en bas.
- **Afficher les résultats** reste fixé en bas de la feuille. Les filtres ne sont appliqués qu’à la validation ; **Annuler** conserve ceux du fil. La remise à zéro peut donc être annulée.
- Lorsque personnalités et partis sont sélectionnés ensemble, un texte explique leur intersection.
- L’enregistrement d’un suivi propose un nom et un récapitulatif des critères. Annuler cette étape ramène aux filtres en cours d’édition.
- Dans le fil, **Votre sélection** présente les personnalités et partis appliqués et **Tout afficher** permet de revenir au fil complet. Le sélecteur **Tous · Interventions · Citations** indique directement le type ; il applique immédiatement ce seul critère sans ouvrir la feuille, en conservant les autres restrictions. Les deux commandes restent synchronisées. [Voir le sélecteur du fil](../Feed/README.md#choix-du-type-directement-dans-le-fil).
- Police sémantique, hauteurs adaptables, thèmes clair/sombre et actions principales d’au moins 52 points. La navigation reste séparée du contenu défilant.

Le client API, les règles de filtrage et le moteur de lecture ne changent pas. Le nombre de résultats n’est pas prédit dans la feuille : les résultats sont chargés après validation.

## Référence

[Avant](avant.png), issu de la première refonte UX, avec données fictives. [Style du fil](../Feed/README.md) · [Fiche de séquence](../Sequence/README.md).

## Écrans

[Filtres avec une sélection](selection.png) · [Personnalités](personnalites.png) · [Enregistrer un suivi](enregistrer-suivi.png) · [Personnalités et parti combinés](filtres-combines.png) · [Retour au fil filtré](fil-filtre.png).

Les captures utilisent les données fictives de démonstration. Elles ont été inspectées pour contrôler les marges, la hiérarchie, les choix actifs et la séparation entre contenu et commandes fixes.

[Mode sombre](filtres-sombres.png) · [Texte maximal](grands-caracteres.png) · [Sélection au texte maximal](selection-grands-caracteres.png) · [Types de passages au texte maximal](types-grands-caracteres.png).

## Validation

- Compilation avec le SDK iOS 27 réussie.
- Trois parcours réussis dans `build/FiltersRedesign.xcresult` : recherche, choix multiples conservés pendant la recherche, intersection personnalité/parti et remise à zéro annulable ; enregistrement, persistance et annulation d’un suivi puis lecture/podcast ; types de passages et annulation, avec contrôle de contraste du fil existant.
- Le quatrième parcours passe dans `build/FiltersFinal.xcresult` (`TEST SUCCEEDED`, un test, zéro échec) : sélection, défilement et application des filtres en mode sombre puis en taille Dynamic Type maximale. Les commandes fixes sont accessibles et mesurent au moins 52 points.
- Les essais intermédiaires en texte maximal ont révélé des limites du pilote XCTest : geste démarrant sur le récapitulatif fixe et exigence impossible d’exposer entièrement une ligne plus haute que la zone visible. Le pilote utilise maintenant le haut du récapitulatif comme limite et peut toucher le centre visible d’une grande ligne. Le test vérifie effectivement la sélection par son compteur avant de valider.
- Inspection des captures sur iPhone 17 Pro, runtime iOS 26.4. Application normale relancée après les tests. Le contrôle ne constitue pas un audit complet d’accessibilité ni un test auprès du public cible.

Logs : `/tmp/infometrie-filters-build.log`, `/tmp/infometrie-filters-ui.log`, `/tmp/infometrie-filters-final.log`.
