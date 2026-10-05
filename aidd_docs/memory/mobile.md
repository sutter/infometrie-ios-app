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
- Word timings are cached in memory for the session only. No media is written to disk and nothing works offline.

## Build and release

- Bundle id `fr.yacast.infometrie.ios`, automatic signing. Pick your own team and, if needed, a bundle id for a physical device.
- Simulator builds use `CODE_SIGN_IDENTITY=-` (see `testing.md`).
- Team `Q37972BSB3` is Laurent Sutterlity's own developer account; `fr.yacast.infometrie.ios` is registered there. Version 0.4.0 went to TestFlight on 2026-09-25 (builds 2 and 3) and build 4 on 2026-10-05, pointing at the test server; it is not on the App Store. The next upload needs build 5 or higher.
- TestFlight release: `xcodebuild -project Infometrie.xcodeproj -scheme Infometrie -configuration Release -destination 'generic/platform=iOS' -archivePath ~/Library/Developer/Xcode/Archives/<date>/<name>.xcarchive archive`, then Organizer > Distribute App > TestFlight, or from the command line `xcodebuild -exportArchive -archivePath <archive> -exportOptionsPlist <plist> -allowProvisioningUpdates` with `method` `app-store-connect`, `destination` `upload` and `teamID` `Q37972BSB3` (used for build 4). Xcode signs for distribution at that step. The App Store Connect record must exist first, and each upload needs a higher build number (`APP_BUILD` in `scripts/create_project.py`, or let the Organizer manage it).
- `Infometrie/Resources/PrivacyInfo.xcprivacy` declares UserDefaults (CA92.1), no tracking, and the email and device ID sent to the server. Update it when a new required-reason API or collected data type appears, or App Store Connect rejects the upload.
