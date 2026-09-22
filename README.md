# InfoMétrie pour iOS

Portage natif en **Swift 6 / SwiftUI**, reconstitué depuis `infometrie-0.4.0-hls-test.apk`, puis aligné sur le Swagger officiel. Interface française avec navigation, onglets et contrôles Liquid Glass natifs. Projet Xcode autonome, sans dépendance applicative tierce.

## Lancer l’application

1. Ouvrir **[Infometrie.xcodeproj](Infometrie.xcodeproj)** dans Xcode 27.
2. Choisir le schéma **Infometrie**, puis un simulateur iPhone ou iPad sous iOS 26 ou ultérieur.
3. Lancer avec **⌘R**.
4. Choisir **Découvrir l’interface** pour la démonstration, ou saisir les identifiants du serveur de test InfoMétrie.

Le SDK utilisé est iOS 27 ; le minimum de déploiement est iOS 26. Les composants natifs adoptent le rendu du système d’exécution. Sur iPhone physique, sélectionner son équipe Apple dans **Signing & Capabilities** et, si nécessaire, un bundle identifier appartenant à cette équipe. Aucune signature de distribution ni publication n’a été effectuée.

[Voir les captures de l’application](Docs/Screenshots/README.md).

## Fonctions reprises

- Connexion, restauration sécurisée de session, limite d’appareils avec remplacement confirmé, déconnexion et révocation.
- Fil des dernières 24 heures, rafraîchissement manuel et périodique, interventions et citations.
- Recherche par personnalités et partis, filtres cumulés, sélecteurs avec recherche textuelle.
- Recherches enregistrées par compte sur l’appareil, archivage, restauration et suppression.
- Séquences : contexte, résumé, verbatim cliquable, lecture audio/vidéo HLS, position de lecture et sauts de 10 secondes.
- Podcast chronologique des résultats avec média, file de lecture, précédent/suivant et enchaînement automatique.
- Thèmes système, clair et sombre ; mise en page iPhone/iPad et taille de texte système.

Les contenus sont proposés en consultation seule. Les alertes et le résumé quotidien, déjà annoncés comme à venir dans l’APK, ne sont pas présentés comme fonctionnels.

## API et médias

Le serveur configuré est **`https://hls-test.yacast.fr`**. Le client utilise les routes mobiles du [Swagger officiel](https://hls-test.yacast.fr/swagger/), version `0.5.0-20260921185015`. Voir le [contrat API et les choix d’intégration](Docs/API/README.md), ainsi que l’[analyse initiale de l’APK](Docs/APK-ANALYSIS.md).

Le jeton reste dans Keychain. Les mots de passe ne sont pas persistés. Les recherches sont séparées par compte. Le lecteur HLS passe par un relais lié à `127.0.0.1` : il authentifie les playlists et segments avec URLSession et les sert à AVPlayer. Il ne stocke aucun média sur disque et refuse les ressources et redirections hors de l’origine du serveur. AirPlay est désactivé pour ce lecteur local ; la lecture s’arrête en arrière-plan, comme dans l’APK.

La démonstration est indépendante de l’API réelle : personnalités et contenus fictifs, audio instrumental local. Elle exerce le même relais HLS avec un transport local exigeant un en-tête Bearer de démonstration, sans requête vers Internet.

## Verbatim et lecteur

Toucher un mot déplace le lecteur au passage correspondant, ou démarre la séquence à ce passage si elle n’est pas encore chargée. En pause, le déplacement conserve la pause. La lecture, le curseur et les sauts de dix secondes actualisent le mot surligné dans les séquences et les podcasts. Le suivi automatique défile par passages ; faire défiler le texte manuellement suspend ce suivi, que le bouton **Reprendre le suivi** réactive.

**La synchronisation utilise maintenant les horodatages par mot** de `GET /rest/v1/sequences/{id}/words`. Les millisecondes sont comptées depuis `origin`, puis rapprochées de l’horloge HLS réelle pour positionner le lecteur. Les silences ne sont pas surlignés. Les repères se chargent en parallèle de la lecture et l’interface indique **Synchronisation par mot** lorsqu’ils correspondent au verbatim.

Si les timings manquent, si le service STT est indisponible ou si les données ne correspondent pas au texte, l’application indique **Calage estimé** et propose de réessayer. Les HTTP 404/502 de cet endpoint ne bloquent pas le média. La démonstration ordinaire reste estimée ; les fixtures instrumentales vérifient les interactions et les positions, pas la qualité d’alignement vocal du serveur.

## Vérifier

Tests métier, contrat HTTP, stockage et manifestes :

```sh
swift test
```

Compilation du simulateur :

```sh
xcodebuild -project Infometrie.xcodeproj -scheme Infometrie \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- build
```

Tests UI (adapter le nom ou utiliser l’identifiant d’un simulateur installé) :

```sh
xcodebuild -project Infometrie.xcodeproj -scheme Infometrie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' \
  -derivedDataPath build CODE_SIGN_IDENTITY=- test
```

Conserver la signature locale du simulateur : `CODE_SIGNING_ALLOWED=NO` empêche les écritures dans le trousseau et bloque la connexion. `CODE_SIGN_IDENTITY=-` utilise la signature locale sans certificat de distribution.

Le schéma inclut `InfometrieUITests`. Le mode Debug `--uitesting` ignore la session réelle ; `--demo` ouvre directement la démonstration. Les recherches de démonstration seules sont réinitialisées avec `--uitesting --reset-demo`. Les tests de connexion utilisent un transport HTTP local, le vrai formulaire et un service Keychain propre à chaque test ; ils vérifient également la restauration après relancement. Leur activation exige `--uitesting` et `INFOMETRIE_LOGIN_TEST_ID` (UUID), uniquement en Debug.

## Organisation

- `Infometrie/Core` : modèles Codable, client API, filtres, stockage des recherches, traitement des playlists et timing du verbatim. Testable sur macOS avec Swift Package Manager.
- `Infometrie/Services` : état observable, Keychain, lecteur AVPlayer, relais HLS et fixtures hors ligne.
- `Infometrie/Views` : écrans SwiftUI et composants visuels.
- `Tests/InfometrieCoreTests` et `InfometrieUITests` : tests unitaires et parcours natifs.
- `Docs` : relevé de l’APK, résultats de validation et captures.
- `scripts/create_project.py` : génération reproductible du projet Xcode, sans XcodeGen. Il n’est pas nécessaire de l’exécuter pour ouvrir le projet livré.

## Limites de validation

Les contrôles de disponibilité du serveur répondent HTTP 200 ; les routes privées répondent HTTP 401 sans authentification. Un compte fourni a permis de vérifier la réponse réelle de quota HTTP 409 et de corriger le décodage de sa liste d’appareils. Un transfert requiert le choix et la confirmation de l’appareil à déconnecter. Les médias privés et timings STT réels restent à vérifier. Le Swagger confirme les routes, documente la connexion et les horodatages ; les schémas de réponse non détaillés restent ceux reconstitués depuis l’APK et testés avec des fixtures.

Xcode 27 et le SDK iOS 27 sont présents. Les tests du simulateur utilisent iOS 26.4, disponible localement ; le rendu et l’exécution sur un appareil sous iOS 27 restent à contrôler. Voir [Docs/VALIDATION.md](Docs/VALIDATION.md) pour les résultats exacts.

La restauration d’une session réelle du compte fourni a également été vérifiée après fermeture et relance du simulateur. Le compte était déjà connecté lors de ce contrôle ; aucun remplacement supplémentaire d’appareil n’a été effectué.
