# Contrat API utilisé par l’application iOS

Source officielle : [Swagger HLS Test](https://hls-test.yacast.fr/swagger/), [spécification YAML](https://hls-test.yacast.fr/swagger/specs.yaml), actualisée le 8 octobre 2026.

Copie locale : [openapi.yaml](openapi.yaml). Version annoncée : `0.11.0-20261007171809`. SHA-256 : `e28187b7b5945cf8cff688dd6f675fd42745dc863f6718dc1fba8642b376f38c`. Pour comparer avec la version en ligne : `scripts/check_api_contract.sh`.

## Routes branchées

| Route | Utilisation iOS |
| --- | --- |
| `POST /rest/v1/auth/login` | Connexion JSON, succès HTTP 201, identifiant stable de l’installation, remplacement d’appareil après confirmation |
| `GET /rest/v1/history` | Périodes 7 j et 30 j : jours complets de Paris jusqu’à hier (`from` / `to`), ou un seul jour choisi sur le graphique ; pages de 50 par `before_id`. `seq` vaut 0 et ne touche jamais le curseur Live |
| `GET /rest/v1/profile` | Fiche personnalité, ouverte depuis le nom sur la page passage : `person` et `days` (7 ou 30). Réponse réelle du 8 octobre 2026 : `person` (`name`, `role`, `party`), `totals` (`interventions`, `citations`, `tweets`, `intervention_sec`), `days` (comme `/days`), `top_channels` (`channel`, `channel_key`, `interventions`, `intervention_sec`). 404 `Unknown person` hors panel, 400 hors 1–31 jours |
| `GET /rest/v1/days` | Graphique par jour de 7 j et 30 j, empilant les types cochés ; total de la période ou du jour |
| `GET /rest/v1/feed` | Fil, filtres `persons`/`parties`/`kinds` séparés par virgules, limite 50, curseur `last_seq` renvoyé comme `since_seq` au prochain rafraîchissement |
| `GET /rest/v1/persons` | Sélecteur de personnalités |
| `GET /rest/v1/parties` | Sélecteur de partis |
| `GET /rest/v1/sequences/{id}` | Résumé, verbatim, métadonnées du passage et playlist |
| `GET /rest/v1/sequences/{id}/words` | Horodatages des mots pour les séquences et podcasts |
| `GET /rest/v1/hls/{id}/{file}` | Playlist et segments via le relais AVPlayer authentifié ; marge 10 secondes en séquence, zéro en podcast, bornée à 0–60 |

Les routes privées utilisent le JWT client dans `Authorization: Bearer …`. La route `/auth`, réservée à l’administration Yacast, n’est pas utilisée. Le Swagger ne précise pas l’unité de `expires` : la validité reste vérifiée par le serveur.

### Connexion : réponse réelle de quota

Vérifié le 22 septembre 2026 avec le compte fourni : HTTP 409 renvoie `error: true` (booléen), `reason: "device quota reached"`, `max_devices` (entier) et `devices` (liste d’appareils). Le Swagger ne détaille pas ce corps. Le modèle iOS décode uniquement les champs utiles au remplacement et ignore `error` : l’ancien type `String` faisait échouer tout le décodage, puis affichait à tort zéro appareil et une liste vide. Une réponse incomplète produit désormais une erreur explicite, sans inventer de quota. Aucun remplacement n’est envoyé avant confirmation.

La spécification 0.5.0 avait été relue le 22 septembre sans changement. La comparaison du 23 septembre avec 0.6.0 ajoute `kinds` et décrit `tweet`, `url` et `channel_key`, sans nouvelle route.

### Routes ajoutées en 0.11.0

La comparaison du 8 octobre 2026 avec 0.11.0 ajoute trois routes, sans modifier celles que l’application appelle. Elles renvoient HTTP 503 quand l’historique est indisponible.

| Route | Contenu annoncé | Usage possible |
| --- | --- | --- |
| `GET /rest/v1/history` | Passages d’une fenêtre (`from` / `to`, au plus 31 jours de Paris), du plus récent au plus ancien, paginés par `before_id`, filtres `persons` / `parties` / `kinds`, `limit` 1–200 (50 par défaut). Réponse `items` et `has_more`. Les passages gardent leur `id` du fil, mais leur `seq` vaut 0 et ne doit jamais alimenter `last_seq` | Périodes 7 j et 30 j du journal, défilement infini |
| `GET /rest/v1/days` | Comptes par jour complet de Paris (aujourd’hui exclu), du plus ancien au plus récent : `interventions`, `citations`, `tweets`, `intervention_sec`. `days` de 1 à 31 (7 par défaut), filtres `persons` / `parties` | Vue Graphique, par jour et par type |
| `GET /rest/v1/profile` | Activité d’une personnalité (`person` obligatoire) sur les derniers jours complets : totaux, un point par jour, ses cinq chaînes principales. `intervention_sec` additionne les interventions du journal, pas le temps de parole officiel | Fiche personnalité (branchée, voir plus haut) |

Le Swagger décrit le corps de `/days` champ par champ ; ceux de `/history` (`items` sans schéma) et de `/profile` restent à vérifier sur le serveur réel avant tout branchement.

## Publications X, filtres et logos — API 0.6

- `tweet` est un type distinct : libellé « Publication X », pictogramme X, lecture du texte et lien externe « Voir la publication sur X ». Le résumé est masqué dans la fiche X pour éviter de répéter la publication ; il reste disponible pour les interventions et citations. Les champs `url` et `channel_key` sont conservés dans le modèle du fil et du détail. Un lien absent ou invalide laisse le texte consultable ; seuls les liens HTTPS vers X/Twitter sont ouverts par le système, sans requête authentifiée ni transfert du JWT.
- Les publications X sont exclues des commandes de lecture, des durées audio, des demandes de timings et de la file du podcast, même si `has_media` est incohérent. Deux publications fictives sans lien externe complètent les contenus des tests UI.
- Les cases « Interventions / Citations / X » du fil et le panneau de filtres transmettent explicitement les types choisis dans `kinds`. Le changement d’un type, d’une personnalité ou d’un parti repart de `since_seq=0`. Le filtrage local demeure une vérification complémentaire, et les réponses d’une ancienne requête ne remplacent pas la nouvelle sélection.
- Les nouveaux suivis peuvent inclure X. Les suivis précédents, dont le champ `tweets` est absent, conservent exactement leur périmètre interventions/citations. Leur combinaison est indiquée dans le fil et dans le panneau, sans l’afficher à tort comme « Tous ».
- `channel_key` permet de chercher une image vectorielle embarquée nommée `channel-<clé en minuscules>` dans le catalogue d’assets. Les 27 logos fournis avec le projet client sont intégrés et affichés dans les items du fil ; les clés avec `_` et les alias `lcp-public-senat` et `backup-cnews` sont normalisés vers leurs images canoniques. Les clés inconnues gardent le nom du média et le pictogramme TV, radio ou publication. Le Swagger ne publie pas lui-même le catalogue ni les images.

### Validation du 23 septembre 2026

- Les 39 tests Swift passent, dont le décodage des publications, les liens externes, les paramètres `kinds` et la compatibilité des suivis existants.
- Trois parcours UI validés sur iPhone 17 Pro et iPad mini 5 sous iOS 26.4, avec le SDK iOS 27 : filtres et podcast, publications X et restauration des suivis, mode sombre et taille de texte d’accessibilité maximale. La fixture HTTP vérifie le redémarrage du curseur après chaque changement de type et l’absence de commandes audio pour X.
- Le premier passage a rencontré deux erreurs de pilotage sur iPhone (focus clavier et élément partiellement masqué). Le test expose désormais les contrôles avant les taps et donne explicitement le focus au mot de passe. Les deux parcours relancés sur iPhone passent sans échec. Rapports locaux : `build/APIPublications06.xcresult` (iPad 3/3, iPhone 1/3), puis `build/APIPublications06PhoneVerified.xcresult` (iPhone 2/2).
- Contrôle manuel avec la session réelle déjà connectée : chargement du fil, sélection de X, affichage de publications réelles et de leur texte, ouverture de la publication d’origine sur `x.com` dans Safari, puis retour dans InfoMétrie. Aucun nouvel identifiant n’a été saisi et aucun appareil n’a été remplacé.
- Les 27 assets vectoriels apparaissent dans `Assets.car`, notamment les logos X, CNews, BFMTV et LCP-Sénat. Les alias de chaînes sont couverts par les tests du modèle ; les clés inconnues conservent le rendu de secours.

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
- Le Swagger ne décrit pas les schémas JSON de réponse du fil, des référentiels ou du détail de séquence (seul `/days`, ajouté en 0.11.0, a un schéma détaillé). Les modèles issus de l’APK ont été complétés pour l’API 0.6. Le contrôle réel des publications décrit ci-dessus confirme ce parcours, sans constituer une validation exhaustive des réponses et des flux privés.
- La fixture UI précise est activée uniquement en compilation Debug avec `--uitesting --signed-in --precise-word-timings`. Elle utilise des temps non uniformes et des silences sur l’audio instrumental local : elle valide les positions, pas la qualité de reconnaissance vocale du STT distant.
