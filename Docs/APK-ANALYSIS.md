# Contrat reconstitué depuis l’APK

Source : `infometrie-0.4.0-hls-test.apk`, package `fr.yacast.iactus`, version `0.4.0`.
SHA-256 : `24dc416337fa192d84f7f0af05b0145040e05f94dc8d8b59c0c29cdd3ec1daa4`.

Analyse locale des tables DEX et décompilation de 151 classes applicatives avec Androguard 4.1.4. Les annotations Retrofit de `IActusApi` ont été lues pour vérifier les verbes, chemins et paramètres. Le code décompilé reste dans `/tmp/infometrie-apk`, hors du projet livré. Aucun service tiers n’a reçu l’APK.

## API

Base relevée dans `BuildConfig` et `Repository` : `https://hls-test.yacast.fr`.

| Méthode | Route | Contrat |
| --- | --- | --- |
| POST | `/rest/v1/auth/login` | JSON : `email`, `password`, `device_uid`, `device_name`, `device_model`, `replace_device_id` optionnel |
| GET | `/rest/v1/feed` | `since_seq`, `persons` et `parties` séparés par virgules, `limit=50` |
| GET | `/rest/v1/persons` | Tableau de personnalités : `name`, `party`, `role` |
| GET | `/rest/v1/parties` | Tableau de partis : `code`, `name` |
| GET | `/rest/v1/sequences/{id}` | Séquence et texte complet |
| GET | `/rest/v1/hls/{id}/index.m3u8` | `margin=10` en séquence, `margin=0` en podcast |

Les appels authentifiés utilisent `Authorization: Bearer …`. Connexion : 401 = identifiants invalides, 403 = abonnement inactif, 409 = limite d’appareils (`max_devices`, `devices`). Hors connexion, 401/403 terminent la session.

Réponse de connexion : `token`, `expires` (entier), `device_id`, `email`, `fullname`, `organisation`. Un appareil contient `id`, `name`, `model`, `registered_at`, `last_seen`.

Le fil contient `items` et `last_seq`. Un élément comporte `id`, `seq`, `at`, `kind`, `media`, `channel`, `show`, `person`, `role`, `party`, `title`, `cited_by`, `duration_sec`, `has_media`, `video`. Les champs optionnels reprennent les valeurs par défaut du sérialiseur Kotlin. `kind=citation` distingue les citations.

Une séquence reprend les champs du fil sans `seq`, puis ajoute `resume`, `verbatim`, `playlist`, `play_from`, `speech_start`, `speech_duration_sec`. Les dates sont ISO 8601 avec décalage UTC, éventuellement fractionnaires.

## Comportements observés

- Connexion et restauration de session, remplacement explicite d’un appareil en cas de quota.
- Fil des dernières 24 heures, actualisation périodique toutes les 30 secondes, mise à jour incrémentale par `since_seq`.
- Les types sont filtrés localement ; les personnes et partis sont envoyés à l’API. Les deux listes s’intersectent.
- Recherches enregistrées localement par email : création, utilisation, archive, restauration, suppression.
- Lecture audio/vidéo HLS. Séquence : marge de 10 secondes, démarrage sur le passage, correction par temps absolu quand disponible. Podcast : passages avec média classés chronologiquement, marge nulle, précédent/suivant.
- Le surlignage du verbatim est une estimation uniforme à partir de `speech_start` et `speech_duration_sec`, sur quatre mots. Il ne s’agit pas de timestamps par mot.
- Lecture interrompue quand l’application passe en arrière-plan.
- Consultation seule : aucune fonction d’export, copie ou partage de séquence.
- L’abonnement et les appareils se gèrent sur le portail web. Aucune adresse de portail distincte vérifiée dans le binaire : aucun lien inventé.
- Les alertes directes et le résumé quotidien sont annoncés « Bientôt disponible » dans l’APK. Le portage ne présente pas de réglages inopérants pour ces fonctions.

## Adaptation Apple

SwiftUI et contrôles système Liquid Glass, navigation et onglets natifs, Dynamic Type, français, thèmes clair/sombre. Compilation avec Xcode 27 / SDK iOS 27. Déploiement minimum iOS 26 pour permettre l’exécution sur les simulateurs présents et conserver la compatibilité avec Liquid Glass.

Le lecteur AVPlayer utilise un relais HTTP lié exclusivement à `127.0.0.1`, avec route aléatoire par session. URLSession authentifie les manifestes, variantes, clés et segments. Les liens de manifeste sont réécrits ; les ranges et les dates HLS sont conservés. Les URL et redirections hors de l’origine du serveur sont refusées afin de ne pas transmettre le jeton à une autre origine. Si le serveur utilise ultérieurement un CDN distinct, ses règles d’autorisation devront être définies explicitement. Aucun média n’est écrit sur disque. La lecture externe/AirPlay est désactivée car les URL de boucle locale ne sont pas accessibles à un récepteur distant.

Les jetons et l’identifiant d’appareil sont stockés dans Keychain. Le mot de passe n’est pas persisté. Le mode démonstration utilise uniquement des personnalités, médias et textes fictifs, une composition instrumentale locale et un espace de recherches séparé.

## Vérification du serveur

Une requête sans identifiants à `/rest/v1/feed` a reçu HTTP 401 le 21 septembre 2026. Cela confirme l’accessibilité HTTPS et l’authentification requise, pas la compatibilité de bout en bout d’un compte ou d’un flux protégé. Aucun identifiant n’a été fourni et aucun compte n’a été connecté automatiquement.
