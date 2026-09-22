---
objective: "Reconstituer InfoMétrie 0.4.0 en SwiftUI pour iOS 27 et livrer un projet compilable avec les parcours de l’APK."
status: implemented
---

# Plan: InfoMétrie iOS

## Overview

| Field | Value |
| --- | --- |
| **Goal** | Application Swift native, français, design iOS 27, API existante et lecture HLS authentifiée. |
| **Source** | `/Users/laurentsutterlity/Downloads/infometrie-0.4.0-hls-test.apk`, demande utilisateur du 21 septembre 2026. |

## Phases

| # | Phase | File |
| --- | --- | --- |
| 1 | Contrat API, modèles et stockage | [phase-1.md](phase-1.md) |
| 2 | Interface native et lecture | [phase-2.md](phase-2.md) |
| 3 | Compilation, tests et livraison | [phase-3.md](phase-3.md) |

## Resources

| Source | Verified |
| --- | --- |
| https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:) | Effets Liquid Glass natifs avec SwiftUI. |
| https://support.apple.com/en-ie/guide/iphone/iphfed2c4091/27/ios/27 | iOS 27 affine Liquid Glass. |

## Decisions

| Decision | Why |
| --- | --- |
| SwiftUI, Observation, URLSession, AVFoundation, SDK iOS 27 / minimum iOS 26 | Composants Apple natifs, aucune dépendance runtime tierce. |
| Reconstituer depuis le DEX sans importer le code Android | Aucun projet source fourni, dossier local vide, aucun AGENTS.md applicable trouvé. |
| Stockage du jeton dans Keychain et recherches par compte | Persistance locale et isolation des sessions. |
| Mode démonstration explicitement séparé | Revue visuelle et tests sans identifiants, données fictives clairement signalées. |
| API hls-test.yacast.fr conservée | Seul serveur identifié dans l’APK ; aucune URL de production inventée. |
| Validation réseau réelle documentée séparément | Distinguer les fixtures automatisées des contrôles effectués avec le compte fourni ultérieurement ; résultats actualisés dans `Docs/VALIDATION.md`. |
