# Project Brief

What this project is, the problem it solves, and its domain language. The non-derivable "why", not the "how".

## What it is

- Native iPhone and iPad client for InfoMétrie (Yacast): a French-language political media watch that lists what public figures said on TV, radio and X over the last 24 hours, with the transcript and the audio/video excerpt.
- Audience: people aged 45 to 80. Readability, large targets and Dynamic Type drive every UI choice.

## Why it exists

- Port of the Android app `fr.yacast.iactus` 0.4.0. No Android source was provided: the contract was rebuilt from the decompiled APK (`Docs/APK-ANALYSIS.md`), then aligned on the official Swagger (`Docs/API/README.md`).
- Read-only by design, like the APK: no export, copy or share of a sequence. Alerts and the daily digest are announced "coming soon" in the APK and are not shown as working.
- Asked by the client on 2026-10-05, waiting for an API: feed periods 7 j and 30 j beside Live (the current 24 h), and a chart synthesis beside the list, counting passages per person, per party and per kind. The feed shows these choices with "Bientôt disponible" until the API exists; the live Swagger (0.9.0) has no route for them yet.

## Domain language

| Term | Meaning |
| ---- | ------- |
| Fil (feed) | Items of the last 24 hours, refreshed incrementally with the `since_seq` / `last_seq` cursor |
| Passage / Séquence | One media excerpt: title, résumé, verbatim and an HLS playlist (`SequenceDetail`) |
| Kind | `intervention`, `citation` (someone quoted, `cited_by`) or `tweet` (Publication X, never playable) |
| Verbatim | The sequence transcript; tapping a word seeks the player to it |
| Personnalités / Partis | `persons` / `parties`, the feed filters, intersected with each other |
| Suivi | A saved search (`SavedSearch`), stored per account on the device, archivable |
| Podcast | Chronological queue of the playable results, with previous / next and auto-advance |
| Synchronisation par mot / Calage estimé | Word highlighting from the API word timings, or its uniform estimate fallback |
| Quota d'appareils | Device limit per account; login answers HTTP 409 and the user picks a device to replace |
| `channel_key` | Broadcaster key that selects the bundled `channel-<key>` logo |

## Key features

- Login, Keychain session restore, device quota replacement after confirmation, logout.
- Feed with 30-second refresh, kind checkboxes (Interventions / Citations / X, combinable), person and party filters.
- Seen passages: opened or listened passages step back in the feed ("✓ Vu"), stored on the device.
- Mes suivis: save, reuse, archive, restore and delete filter sets.
- Sequence page: text before résumé, word-tap seeking, persistent player (play/pause, scrubber, ±10 s), fullscreen transcript.
- Podcast of the current results.
- Appearance: system, light or dark theme, reading size S / M / L on top of the system text size.
