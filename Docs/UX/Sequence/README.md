# Fiche de séquence — continuité avec le fil

Itération du 22 septembre 2026. Le style du fil validé est étendu à la fiche, pour le parcours **lire, puis écouter un passage**.

Le code couleur du fil est désormais partagé par la fiche : rouge pour les citations, bleu pour les interventions, sur le pictogramme du média, le filet de la personnalité et le libellé du type dans les informations du passage. Les nuances s’adaptent au thème clair/sombre.

[Citation en clair](citation-claire.png) · [Citation en sombre](citation-sombre.png). Captures fictives vérifiées dans `build/PassageColors.xcresult`.

## Choix

- Même ligne source/heure et même identité avec filet discret que dans les cartes du fil. Ces deux éléments partagent désormais leurs composants SwiftUI.
- Titre en police système à empattements, plus grand que celui des cartes. Le texte courant et les commandes restent en police système sans empattements et suivent Dynamic Type.
- Le verbatim occupe une surface de lecture blanche en mode clair, sombre en mode sombre, avec un en-tête plus discret. Les indications de synchronisation et le suivi de l’écoute sont réunis dans un bandeau légèrement teinté.
- L’instruction « Touchez un mot pour rejoindre ce passage » reste juste lorsque la lecture est en pause. L’estimation reste indiquée explicitement lorsqu’il n’existe pas de repères précis.
- Résumé et informations de diffusion restent dépliables, avec icônes natives, titres complets et zones tactiles généreuses.
- La durée apparaît dans le bouton d’écoute initial ; pendant la lecture, les temps restent au-dessus des commandes. Les sauts de 10 secondes ont une surface teintée pour mieux repérer leurs limites.
- Navigation protégée par un fond net pendant le défilement ; lecteur fixe et indépendant du défilement du texte.

Le composant de verbatim et les commandes étant partagés, leur présentation bénéficie aussi au mode « Tout écouter ». Aucun changement de client API, d’authentification, de calcul des horodatages ou de logique AVPlayer.

## Références

[Avant](avant.png) · [Avant, en lecture](avant-lecture.png) · [Style du fil validé](../Feed/fil-clair.png).

Les références sont les captures de la version précédente, avec le jeu de démonstration fictif.

## Après refonte

[Fiche](sequence.png) · [Pendant l’écoute](lecture.png) · [Résumé ouvert](resume.png) · [Informations de diffusion](contexte.png).

Les captures finales sont prises après l’ouverture complète des sections et inspection dans le même simulateur que les références. La comparaison vérifie la hiérarchie des titres, les marges, les sections dépliées et les commandes. Le parcours final passe dans `build/SequenceFinal.xcresult` (1 test, zéro échec). L’application normale a été relancée après les tests.

## Validation

- Compilation SDK iOS 27 réussie, sans changement de modèle de données ni de moteur de lecture.
- Deux parcours précis réussis dans `build/SequenceRedesign.xcresult` : mot placé à 12 secondes par la fixture API, silences sans surlignage, sauts de 10 secondes et changement de séquence dans le podcast.
- Trois parcours réussis dans `build/SequenceVerified.xcresult` (`TEST SUCCEEDED`, zéro échec) : sombre et taille d’accessibilité maximale ; fil → suivis → fiche → résumé/contexte → lecture → podcast ; texte ↔ curseur en pause et suivi automatique désactivable/réactivable.
- Deux premières interactions du pilote XCTest visaient des commandes encore recouvertes par le lecteur fixe. Le pilote attend désormais que les boutons de résumé, de contexte et de suivi soient entièrement dans la zone de lecture. Les tests contrôlent aussi que l’ouverture des sections ne démarre pas l’écoute.

[Lecture sombre](lecture-sombre.png) · [Texte maximal](grands-caracteres.png) · [Déplacement en pause](synchronisation-pause.png) · [Repères précis](synchronisation-precise.png).

Contrôle sur iPhone 17 Pro, runtime iOS 26.4, compilation SDK iOS 27. Toutes les captures documentées utilisent des données fictives. Il s’agit de tests techniques et d’une inspection visuelle ; aucun audit complet d’accessibilité ni test auprès du public cible n’est revendiqué.
