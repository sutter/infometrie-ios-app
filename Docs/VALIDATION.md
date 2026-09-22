# Validation du portage

## Filtres du fil — 22 septembre 2026

Présentation harmonisée avec le fil et la fiche : critères regroupés, sélection par coches et surfaces teintées, choix et validation persistants, récapitulatif avant l’enregistrement d’un suivi et carte des critères actifs dans le fil. Voir [les captures et les choix](UX/Filters/README.md).

- Compilation SDK iOS 27 réussie ; aucun changement du client API, des règles de filtrage ou de la lecture.
- **Quatre parcours distincts validés** : recherche/sélection multiple/intersection/remise à zéro, suivis/persistance/lecture et types de passages/annulation dans `build/FiltersRedesign.xcresult` ; sombre et texte maximal dans `build/FiltersFinal.xcresult` (1 test, zéro échec, `TEST SUCCEEDED`).
- Les contrôles en texte maximal ont nécessité une correction du pilote : défilement au-dessus de tout le récapitulatif fixe et toucher du centre visible d’une ligne plus haute que la zone de liste. La sélection est vérifiée par son compteur avant confirmation.
- Captures inspectées dans `Docs/UX/Filters/`, uniquement avec données fictives. Exécution sur iPhone 17 Pro / iOS 26.4 ; application normale relancée.

Logs : `/tmp/infometrie-filters-build.log`, `/tmp/infometrie-filters-ui.log`, `/tmp/infometrie-filters-final.log`.

## Fiche de séquence — 22 septembre 2026

Continuité visuelle avec le fil : titre éditorial, source/heure et identité partagées, verbatim avec bandeau de synchronisation, résumé et contexte dépliables, durée dans l’action initiale et sauts de 10 secondes mieux délimités. Voir [les choix et les captures](UX/Sequence/README.md).

- Compilation SDK iOS 27 réussie (`/tmp/infometrie-sequence-build.log`).
- **Cinq parcours distincts validés** : synchronisation précise de la fiche et du podcast dans `build/SequenceRedesign.xcresult` ; mode sombre/texte maximal, parcours complet et synchronisation estimée dans `build/SequenceVerified.xcresult` (3 tests, zéro échec).
- Les deux échecs initiaux venaient du pilote touchant des boutons recouverts par le lecteur fixe. Le défilement du pilote expose désormais entièrement les commandes de contenu concernées avant de les toucher. Aucun changement de la logique de synchronisation.
- Inspection visuelle de la présentation avant/après, du thème sombre et des grandes tailles. Exécution sur iPhone 17 Pro / iOS 26.4.

Le contrôle final des sections dépliées passe dans `build/SequenceFinal.xcresult` (1 test, zéro échec), avec contenu du résumé et rôle vérifiés. Captures retenues dans `Docs/UX/Sequence/`. Application normale relancée après les tests.

Logs : `/tmp/infometrie-sequence-ui.log`, `/tmp/infometrie-sequence-verified.log`, `/tmp/infometrie-sequence-final.log`.

## Nouvelle présentation du fil — 22 septembre 2026

Refonte ciblée des cartes : titres éditoriaux, source et heure séparées, personne sans avatar d’initiales, bandeau « Lire et écouter » et durées en minutes/secondes. L’en-tête rapproche les premiers résultats. Voir [les captures et les choix](UX/Feed/README.md).

- Compilation SDK iOS 27 réussie (`/tmp/infometrie-feed-build.log`).
- Trois parcours ciblés réussis, zéro échec, dans `build/FeedRedesign.xcresult` : lecture/filtres/suivis/podcast ; sombre et texte maximal ; filtres et audit de contraste/texte tronqué/cibles tactiles sur le fil.
- Contrôle visuel complémentaire de la carte au texte maximal et de son action après défilement : `build/FeedLargeText.xcresult`, un test réussi.
- Captures inspectées dans `Docs/UX/Feed/`. Le périmètre de l’audit de contraste reste celui décrit ci-dessous, limité aux cartes entièrement visibles puis exposées par défilement.
- Application relancée dans le simulateur iPhone 17 Pro, iOS 26.4. Aucun changement du client API ou du moteur de lecture dans cette itération.

Logs UI : `/tmp/infometrie-feed-ui.log`, `/tmp/infometrie-feed-large-text.log`.

## Refonte UX — 22 septembre 2026

Parcours principal confirmé : lire le fil, puis écouter un passage. Trois onglets stables, filtres en feuille, texte prioritaire, commandes de lecture persistantes et texte confortable activé par défaut. Voir [l’audit, les choix et les captures avant/après](UX/README.md).

- Compilation Swift 6 / SDK iOS 27 réussie ; exécution sur iPhone 17 Pro, iOS 26.4.
- **34 tests du cœur réussis**, sans modification du contrat API ni du moteur de synchronisation.
- **10 parcours UI distincts validés** au fil des vérifications : les trois parcours de connexion et les deux parcours du podcast dans `build/UXIteration2.xcresult` ; le parcours complet des suivis et la synchronisation précise dans `build/UXFinal.xcresult` ; grands caractères, filtres/audit du fil et synchronisation estimée dans `build/UXAccessibilityFinal.xcresult` (3 tests, 0 échec, `TEST SUCCEEDED`).
- L’audit automatisé porte sur le contraste, les zones tactiles et le texte tronqué du fil, avec contrôle des cartes entièrement exposées, puis défilement et nouveau contrôle. Les cartes partiellement recouvertes par la navigation native sont hors périmètre du contraste à cet instant et consignées en pièce jointe. Aucun résultat de certification globale n’est revendiqué.
- Les premières itérations ont relevé le contraste trop faible des textes secondaires et deux limites du pilote XCTest (geste sur la barre fixe, puis lien déclaré accessible alors que son centre était recouvert). Le contraste a été renforcé et les gestes du pilote adaptés à la zone de lecture. Le clic sur un mot au texte maximal est désormais vérifié effectivement.
- Le dernier contrôle de la séparation entre l’en-tête et le fil défilant passe dans `build/UXVerified.xcresult` (1 test, 0 échec).
- Captures retenues dans `Docs/UX/After/`, issues des parcours réussis correspondants. L’application normale a été relancée dans le simulateur après les tests.

Logs : `/tmp/infometrie-ux-core.log`, `/tmp/infometrie-ux-tests-2.log`, `/tmp/infometrie-ux-final.log`, `/tmp/infometrie-ux-accessibility-final.log`, `/tmp/infometrie-ux-verified.log`.

## Correction de connexion — 22 septembre 2026

La réponse réelle HTTP 409 contient `error: true`, `max_devices: 2` et deux appareils. L’ancien modèle attendait `error` comme texte : tout le décodage échouait, puis le repli affichait « 0 appareils » et une liste vide. Le modèle décode maintenant uniquement le quota et les appareils, sans valeur inventée en cas de réponse malformée.

Le test de régression a reproduit le défaut avant correction (quota zéro, appareil absent), puis passe après correction. Les **34 tests du cœur passent**, dont le cas de quota malformé. Les identifiants réels ne sont présents dans aucun fichier du projet ; le diagnostic distant HTTP 409 n’a remplacé aucun appareil.

Les nouveaux tests UI passent par le vrai bouton, le client HTTP et le vrai trousseau sous un service unique par test. Le transport local Debug vérifie la route, le JSON de connexion et le Bearer du fil. Il couvre la réponse 201, le quota avec confirmation, les erreurs 401/403 et réseau, ainsi que la nouvelle tentative. Les fixtures n’utilisent pas le mode démonstration et ne remplacent pas la session réelle.

Les **trois parcours de connexion sont validés** : quota et erreurs/réessai dans `build/LoginFixedQA.xcresult`, puis connexion → fil authentifié → restauration → déconnexion → absence de session au relancement dans `build/LoginPersistenceQA.xcresult` (`TEST SUCCEEDED`). Le premier passage de ce dernier test avait échoué sur un sélecteur XCTest ambigu entre le bouton du compte et celui de confirmation ; le sélecteur est maintenant limité à la boîte de confirmation.

Le premier essai a également révélé que `CODE_SIGNING_ALLOWED=NO` interdit l’écriture Keychain sur le simulateur. Les commandes documentées utilisent désormais la signature locale (`CODE_SIGN_IDENTITY=-`). Aucun repli vers un stockage de jeton moins protégé n’a été ajouté.

Logs : `/tmp/infometrie-login-quota-before.log`, `/tmp/infometrie-login-core.log`, `/tmp/infometrie-login-fixed-ui.log`, `/tmp/infometrie-login-persistence-ui.log`.

Capture contrôlée : [compte connecté via la fixture API](Screenshots/12-compte-connecte-api.png). L’application signée a ensuite été relancée sans argument de test ; le formulaire de connexion réel est affiché. Le contrôle manuel Computer Use n’a pas pu démarrer (configuration de l’outil inachevée sur le Mac) ; la vérification visuelle finale utilise une capture `simctl`, et les interactions sont couvertes par XCTest.

### Session réelle

Le contrôle complémentaire du 22 septembre a constaté qu’une session du compte fourni était déjà active dans le simulateur. L’écran Compte affichait bien l’identité attendue, hors démonstration. Après fermeture et relance, le fil et le compte sont restés accessibles : **test réel réussi** dans `build/LiveAccountVerified.xcresult`, journal `/tmp/infometrie-live-account-verified.log`. Aucun transfert d’appareil supplémentaire n’a été exécuté.

Le pilote temporaire a été retiré du projet après contrôle. Les identifiants lui ont été transmis en mémoire via un tube local privé ; aucun mot de passe ni jeton n’a été ajouté aux sources ou à la documentation.

## Validation initiale

Vérifications réalisées le 21 septembre 2026.

| Vérification | Résultat |
| --- | --- |
| Xcode | 27.0, build 27A266a |
| SDK de compilation | iOS Simulator 27.0 |
| Langage | Swift 6, vérification stricte de concurrence |
| Compilation finale | `BUILD SUCCEEDED`, arm64 et x86_64 pour le simulateur |
| Tests du cœur | 33 tests Swift Testing réussis, 0 échec |
| Tests de parcours | 5 tests XCTest UI réussis, 0 échec, environ 133 secondes |
| Intégration Swagger — synchronisation | 4 parcours ciblés réussis : deux en mode précis, deux en repli estimé |
| Recontrôle visuel après ajustements | Test ciblé réussi, contraste sombre et carte adaptée aux grandes tailles de texte |
| Exécution UI | iPhone 17 Pro, simulateur iOS 26.4 |
| Serveur réel sans identifiants | HTTPS joignable, HTTP 401 attendu |

## Parcours vérifiés

1. Connexion : formulaire accessible, connexion désactivée sans mot de passe, entrée en démonstration, état vide lorsque les deux types de passage sont désactivés.
2. Recherche et lecture : sélection d’une personnalité, sauvegarde, persistance après arrêt/relancement, archivage, restauration, suppression confirmée, ouverture d’une séquence, lecture et pause HLS, podcast, passage suivant, fermeture, sortie de démonstration.
3. Apparence : lancement en thème sombre et avec la taille de texte d’accessibilité maximale, captures des écrans.
4. Verbatim : clic démarrant le média, clic en pause, correspondance mot/position, glissement du curseur en pause, progression du texte pendant la lecture, activation/désactivation du suivi.
5. Podcast : clic sur le texte en pause, passage suivant, nouvelle correspondance mot/position dans la séquence courante.

La fixture audio de démonstration est un vrai flux HLS VOD : manifeste et sept segments MPEG-TS avec audio AAC. Les requêtes AVPlayer passent par le relais HTTP local puis un URLProtocol de fixture, qui refuse les requêtes sans le Bearer attendu. L’apparition de la commande Pause est vérifiée pour la séquence et le podcast. Cette vérification couvre le transport local et le décodage HLS ; elle ne remplace pas une session sur le serveur Yacast.

## Tests du cœur

- Décodage du contrat APK, champs optionnels, champs supplémentaires.
- Intersection personnalités/partis et sélection des types.
- Fusion incrémentale, remplacement des doublons, expiration des éléments de plus de 24 heures.
- Encodage URL des noms, des critères et du curseur.
- Corps de connexion et remplacement d’appareil.
- Sérialisation des recherches et isolation entre comptes/démonstration.
- Réécriture des playlists, segments, variantes, clés et initialisations.
- Rejet des URL de média hors origine.
- Marges de lecture et bornes du surlignage du verbatim.
- Aller-retour mot → position média → mot, avec marges de zéro/dix secondes et début de parole décalé.
- Horloge HLS dont la fenêtre réelle diffère de la marge demandée.
- Accents, apostrophes, emoji, espaces insécables et paragraphes ; conservation des cibles avec les grandes tailles de texte.
- Refus des cibles sans timing exploitable, avant la parole ou après sa fin.
- Différenciation entre mauvais identifiants et session révoquée.
- Quota d’appareils et réponse serveur invalide.

## Synchronisation interactive du verbatim

Le texte et le lecteur partagent désormais une même conversion entre secondes du média et date de diffusion. Le clic sur un mot repositionne AVPlayer, y compris lorsque le clic déclenche le chargement initial. La pause est conservée. Le curseur prévisualise la position dans le texte pendant le glissement, puis effectue le seek au relâchement. Les callbacks d’une ancienne séquence ou d’un seek remplacé sont ignorés.

Le défilement automatique suit les passages ; un défilement manuel suspend le suivi et le bouton de suivi le réactive. Les passages sont raccourcis avec les tailles de texte d’accessibilité. Les mêmes interactions sont disponibles dans le podcast.

Le Swagger fourni après le portage ajoute `/rest/v1/sequences/{id}/words`, maintenant intégré. Les horodatages sont relatifs à `origin` et remplacent l’estimation lorsque le texte correspond. Les silences ne sont plus surlignés dans ce mode. Le repli estimé reste disponible si les timings sont absents ou invalides. Les tests avec l’audio instrumental valident les positions et les interactions, pas la qualité de reconnaissance vocale distante. Voir [le contrat API](API/README.md).

La validation du cœur inclut désormais le succès de connexion HTTP 201, tous les appels mobiles avec Bearer, les réponses 404/502 des timings, la révocation 401/403, la borne de marge HLS à 60 secondes, les durées non uniformes, les silences, les contractions françaises et le refus des timings incompatibles avec le texte.

Les tests ciblés du simulateur placent un mot à 12 secondes au lieu des 7,9 secondes de l’estimation, vérifient le clic, les sauts du lecteur vers/depuis un silence et le changement de séquence dans le podcast. Le repli estimé reste testé séparément. Deux tests du cœur couvrent également l’arrivée tardive des repères précis et une correction tardive de l’horloge HLS : celle-ci ne doit pas être comptée comme du temps de lecture supplémentaire.

## Artefacts locaux

- Dernière validation des cinq parcours : `build/TranscriptVerified.xcresult` (ouvrable dans Xcode).
- Intégration Swagger : `build/SwaggerPreciseQA.xcresult` (2 parcours précis) et `build/SwaggerIntegrationQA.xcresult` (2 parcours estimés).
- Validations du portage initial : `build/VisualQA.xcresult` et `build/UITests-Passing.xcresult`.
- Application compilée : `build/Build/Products/Debug-iphonesimulator/Infometrie.app`.
- Captures sélectionnées : `Docs/Screenshots/`.
- Logs de la synchronisation : `/tmp/infometrie-transcript-core.log`, `/tmp/infometrie-transcript-verified.log`.
- Logs du branchement Swagger : `/tmp/infometrie-swagger-core.log`, `/tmp/infometrie-swagger-final-build.log`, `/tmp/infometrie-swagger-precise-ui.log`, `/tmp/infometrie-swagger-ui.log`.

La compilation finale dans le sandbox a utilisé `OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'` pour permettre l’exécution des macros du compilateur à l’intérieur de l’environnement déjà restreint. Ce paramètre n’est pas inscrit dans le projet et n’est pas nécessaire dans Xcode. Les tests du simulateur ont été exécutés avec l’accès système requis par CoreSimulator. Les messages système de collecte AppIntents/diagnostic du simulateur ne sont pas des erreurs de compilation de l’application.

## À vérifier avec l’environnement réel

- Connexion avec un compte HLS Test, Keychain sur iPhone signé, expiration/révocation réelle et remplacement d’un appareil.
- Flux privés audio et vidéo, fenêtres temporelles du serveur, interruptions réseau et droits d’accès réels.
- Rendu et comportement sur iOS 27 : le SDK est utilisé, mais aucun runtime iOS 27 n’était installé localement.
- Exécution sur iPad physique et éventuelle diffusion App Store/TestFlight après configuration de l’équipe et de la signature.

Aucune publication, modification de compte distant ni requête de connexion avec identifiants inventés n’a été effectuée.
