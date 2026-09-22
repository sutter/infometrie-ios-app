# Contrat API utilisé par l’application iOS

Source officielle : [Swagger HLS Test](https://hls-test.yacast.fr/swagger/), [spécification YAML](https://hls-test.yacast.fr/swagger/specs.yaml), récupérée le 21 septembre 2026.

Copie locale : [openapi.yaml](openapi.yaml). Version annoncée : `0.5.0-20260921185015`. SHA-256 : `2294b73ae97901869bb368c9c3d86d5b7f2abfd307df62ad798fa1d98374e373`.

## Routes branchées

| Route | Utilisation iOS |
| --- | --- |
| `POST /rest/v1/auth/login` | Connexion JSON, succès HTTP 201, identifiant stable de l’installation, remplacement d’appareil après confirmation |
| `GET /rest/v1/feed` | Fil, filtres `persons`/`parties` séparés par virgules, limite 50, curseur `last_seq` renvoyé comme `since_seq` au prochain rafraîchissement |
| `GET /rest/v1/persons` | Sélecteur de personnalités |
| `GET /rest/v1/parties` | Sélecteur de partis |
| `GET /rest/v1/sequences/{id}` | Résumé, verbatim, métadonnées du passage et playlist |
| `GET /rest/v1/sequences/{id}/words` | Horodatages des mots pour les séquences et podcasts |
| `GET /rest/v1/hls/{id}/{file}` | Playlist et segments via le relais AVPlayer authentifié ; marge 10 secondes en séquence, zéro en podcast, bornée à 0–60 |

Les routes privées utilisent le JWT client dans `Authorization: Bearer …`. La route `/auth`, réservée à l’administration Yacast, n’est pas utilisée. Le Swagger ne précise pas l’unité de `expires` : la validité reste vérifiée par le serveur.

### Connexion : réponse réelle de quota

Vérifié le 22 septembre 2026 avec le compte fourni : HTTP 409 renvoie `error: true` (booléen), `reason: "device quota reached"`, `max_devices` (entier) et `devices` (liste d’appareils). Le Swagger ne détaille pas ce corps. Le modèle iOS décode uniquement les champs utiles au remplacement et ignore `error` : l’ancien type `String` faisait échouer tout le décodage, puis affichait à tort zéro appareil et une liste vide. Une réponse incomplète produit désormais une erreur explicite, sans inventer de quota. Aucun remplacement n’est envoyé avant confirmation.

La spécification a été relue le 22 septembre : même version et même empreinte SHA-256.

## Horodatages du verbatim

`start_ms` et `end_ms` sont des millisecondes relatives à `origin` (décrit comme `play_from`), et non à `speech_start`. Les dates absolues des mots sont converties en positions AVPlayer avec l’horloge HLS `EXT-X-PROGRAM-DATE-TIME`. L’origine réelle de la fenêtre prime sur la marge demandée au serveur.

L’application charge ces données sans bloquer l’affichage ni le média. Elle mutualise la requête entre la page et le lecteur, conserve les résultats en mémoire pendant la session, et annule les requêtes à la déconnexion. Un clic effectué avant l’arrivée des timings est recalé à leur réception, sauf si l’utilisateur a ensuite déplacé le curseur. La pause et la progression déjà effectuée sont conservées.

Le texte affiché reste le verbatim de la séquence. L’association tolère casse, accents composés, ponctuation et contractions françaises réparties sur plusieurs tokens STT. Les répétitions sont associées dans leur ordre. Les intervalles vides, inversés, chevauchants, incomplets ou ne correspondant pas au texte ne sont pas présentés comme précis. Pendant un silence entre deux mots, aucun mot n’est surligné.

Repli explicite vers l’estimation lorsque les timings sont indisponibles : HTTP 404 (séquence/source STT absente), HTTP 502 (STT sans réponse), erreur réseau, données invalides ou incompatibles avec le texte. Le média reste disponible et un bouton permet de réessayer la synchronisation. Les HTTP 401/403 continuent de terminer la session, même sur cet endpoint optionnel.

## Vérification et limites

- Contrat HTTP testé avec URLProtocol : connexion 201, corps JSON, Bearer, fil/référentiels/détail/timings, erreurs et marges HLS.
- `/healthz` et `/readiness` répondent HTTP 200 ; `/rest/v1/sequences/1/words` répond HTTP 401 sans authentification.
- Le compte fourni a permis de vérifier la réponse distante HTTP 409. L’appel de diagnostic n’a remplacé ni révoqué d’appareil. Les identifiants et jetons ne sont pas conservés dans ce dépôt.
- Un contrôle natif ultérieur a confirmé la présence de la session réelle attendue et sa restauration après relance du simulateur. Le compte était déjà connecté ; aucun transfert supplémentaire n’a été exécuté.
- Le Swagger ne décrit pas les schémas JSON de réponse du fil, des référentiels ou du détail de séquence. Les modèles correspondants restent ceux récupérés dans l’APK. Un compte réel est nécessaire pour vérifier ces réponses et les flux privés de bout en bout.
- La fixture UI précise est activée uniquement en compilation Debug avec `--uitesting --demo --precise-word-timings`. Elle utilise des temps non uniformes et des silences sur l’audio instrumental local : elle valide les positions, pas la qualité de reconnaissance vocale du STT distant.
