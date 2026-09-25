# Testing

How the project is tested: the layers, the tools, and the conventions. Where tests live and how to run them.

## Strategy

- Core: unit and contract tests on macOS, with no simulator. HTTP is stubbed with `URLProtocol` to check routes, bodies, the Bearer header, error mapping and HLS margins against the Swagger.
- UI: XCUITest journeys on the simulator, driving the demo mode or a local HTTP transport through the real screens. They also assert touch targets, truncation and contrast on the visible feed cards.
- No automated test ever uses the real account. Real-server checks are manual and logged in `Docs/VALIDATION.md`.

## Tools

- Swift Testing (`import Testing`, `@Suite`, `#expect`) for `Tests/InfometrieCoreTests`.
- XCTest / XCUITest for `InfometrieUITests`.
- Debug-only fixtures: `LoginTestProtocol` (local login server and isolated Keychain service), `DemoMediaProtocol` (local HLS).

## Conventions

- Core suites live in `Tests/InfometrieCoreTests`, one file per concern. UI journeys live in `InfometrieUITests/InfometrieUITests.swift`, named `test<Behavior>`.
- UI tests find elements by `accessibilityIdentifier` (`feed-item-1`, `reading-size-M`, `login-password`). Give any new interactive element an identifier.
- Launch arguments, Debug builds only: `--uitesting` (no real session), `--demo`, `--reset-demo`, `--precise-word-timings`. Login journeys also need the `INFOMETRIE_LOGIN_TEST_ID` environment variable (a UUID).
- UI tests attach screenshots. Results go to `build/<Name>.xcresult`, which git ignores. Log a full-suite run and its counts in `Docs/VALIDATION.md`; smaller checks need no entry.
- A failing UI journey is often the driver (keyboard focus, element hidden under the persistent player), not the app. Fix the gesture, never weaken the assertion.
- Screenshots show fictional data only. The repository is public.

## UI tests by area

Run only the area a change touches; the first test of each row is the broadest.

| Area | Tests |
| ---- | ----- |
| Login, session, device quota | `testLoginCallsAPIStoresSessionAndRestoresAfterRelaunch`, `testLoginDeviceQuotaRequiresConfirmationThenAuthenticates`, `testLoginDisplaysAPIErrorsAndAllowsRetry`, `testLoginFormAndEmptyFilters` |
| Feed kinds, Publications X | `testFeedKindSelectionSyncNavigationAndPodcast`, `testPublicationsUseServerKindsResetCursorAndHaveNoAudio`, `testFeedKindsDarkAppearanceAndMaximumText` |
| Filters | `testFilterSearchMultipleSelectionIntersectionAndReset`, `testFiltersDarkAppearanceAndMaximumText` |
| Main navigation, iPad sidebar | `testMainNavigationPreservesFeedSelection` |
| Suivis, sequence, podcast | `testDemoSearchPersistenceSequenceAndPodcast` |
| Appearance, reading size | `testReadingComfortUpdatesTextImmediatelyAndPersists`, `testReadingSizesRespectSystemAccessibilityAndDarkAppearance`, `testDarkAppearanceAndLargeText` |
| Transcript, player | `testTranscriptSeeksPlayerAndFollowsScrubbingWhilePaused`, `testFullscreenTranscriptKeepsPreciseSeekingAndPlayback`, `testFullscreenTranscriptStartsFromTextAtMaximumSize` |
| Podcast, word timings | `testPodcastTranscriptUsesCurrentSequenceAndResetsOnNext`, `testPreciseAPITimingsSeekToTwelveSecondsAndLeaveSilencesUnhighlighted`, `testPodcastUsesPreciseAPITimingsAfterChangingSequence` |

## Show it in the simulator

Xcode 27 has no Simulator app: the simulator screen lives in DeviceHub (`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`). After the fast build, on a booted iOS 26.4 iPhone:

```sh
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Infometrie.app
xcrun simctl launch --terminate-running-process booted fr.yacast.infometrie.ios --demo
```

- No simulator booted: `xcrun simctl boot <udid>` with the iOS 26.4 iPhone 17 Pro from `xcrun simctl list devices available`.
- `-appearance dark` or `-appearance light` forces the theme for that launch; `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` gives the largest text.
- A screenshot, only when asked: `xcrun simctl io booted screenshot <file>.png`, about two seconds after launch.

## Run

- Core: `swift test`.
- UI: `xcodebuild -project Infometrie.xcodeproj -scheme Infometrie -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath build CODE_SIGN_IDENTITY=- test`, with `-only-testing:InfometrieUITests/InfometrieUITests/<test>` to target one journey.
- Keep `CODE_SIGN_IDENTITY=-`. `CODE_SIGNING_ALLOWED=NO` blocks Keychain writes, so login fails.
- Three simulators are named `iPhone 17 Pro`, on iOS 17.0, 26.3 and 26.4. The iOS 17 one cannot launch the app (deployment target iOS 26), and validation runs on 26.4. Always target `OS=26.4` or the udid of the 26.4 device, never the name alone.
- A run can stall before `Testing started` on a simulator that was just booted. Stop it after two minutes without progress, then rerun.
- `testFullscreenTranscriptStartsFromTextAtMaximumSize` fails at the largest text size: swiping the fullscreen text does not suspend listening-follow, so "Reprendre le suivi" never appears. The same swipe works at the standard size (`testFullscreenTranscriptKeepsPreciseSeekingAndPlayback`). The cause has not been found.
- After the tests finish, `xcodebuild` can hang while finalizing the result bundle. The `Executed N tests` lines in the log are the result; stop the process instead of waiting.
- Every UI test run logs the SwiftUI warning `Adding '_UIReparentingView' as a subview of UIHostingController.view is not supported`. It predates the current changes, so it is not a regression from the change under test. Its cause has not been investigated.
