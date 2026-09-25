# Mobile

The mobile app: platform, navigation, native access, and release.

## Platform

- Native iOS and iPadOS in SwiftUI, with native Liquid Glass system controls. Built with the iOS 27 SDK, deployment target iOS 26. French only (`fr_FR` locale forced at the root).
- iPhone: portrait and landscape. iPad: every orientation, with a sidebar at regular width. Screen flow in `navigation.md`.

## Native access

- AVFoundation: `AVPlayer` with external playback off. Pauses on audio interruption, on headphones unplugged and when the app leaves the foreground. No background audio.
- Network: a loopback `NWListener` for the HLS relay, allowed by `NSAllowsLocalNetworking` in `Info.plist`.
- Security: Keychain for the session and device id.
- No user-facing permission prompt.

## State and storage

- Two `@MainActor @Observable` models passed through the environment: `AppModel` (session, feed, filters, suivis, word timings) and `PlaybackModel` (queue, player, transcript position).
- `UserDefaults`: saved searches keyed per account (`SearchStore`), last email. `@AppStorage`: `appearance`, `readingSize`.
- Word timings are cached in memory for the session only. No media is written to disk and nothing works offline except demo mode.

## Build and release

- Bundle id `fr.yacast.infometrie.ios`, automatic signing. Pick your own team and, if needed, a bundle id for a physical device.
- Simulator builds use `CODE_SIGN_IDENTITY=-` (see `testing.md`).
- Nothing has been distributed yet: no TestFlight, no App Store.
