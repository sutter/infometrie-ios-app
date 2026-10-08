# Testing

How the project is tested: the layers, the tools, and the conventions. Where tests live and how to run them.

## Strategy

- Core: unit and contract tests on macOS, with no simulator. HTTP is stubbed with `URLProtocol` to check routes, bodies, the Bearer header, error mapping and HLS margins against the Swagger.
- UI: XCUITest journeys on the simulator, driving the real screens against a local API server. They also assert touch targets, truncation and contrast on the visible feed cards.
- No automated test ever uses the real account. Real-server checks are manual and logged in `Docs/VALIDATION.md`.

## Tools

- Swift Testing (`import Testing`, `@Suite`, `#expect`) for `Tests/InfometrieCoreTests`.
- XCTest / XCUITest for `InfometrieUITests`.
- Debug-only `UITestServer` (`Infometrie/Fixtures`): a local API for login, feed, choices, sequences, word timings and HLS media, with fictional content, instrumental audio and a dedicated Keychain service. Its media always starts at the passage, whatever the HLS margin; the playlist's `EXT-X-PROGRAM-DATE-TIME` sets the player clock.

## Conventions

- Core suites live in `Tests/InfometrieCoreTests`, one file per concern. UI journeys live in `InfometrieUITests/InfometrieUITests.swift`, named `test<Behavior>`.
- UI tests find elements by `accessibilityIdentifier` (`feed-item-1`, `reading-size-M`, `login-password`). Give any new interactive element an identifier. An identifier on a container without `.accessibilityElement(children: .contain)` replaces every child's own: the Compte appearance section hid `appearance-picker` this way until 2026-10-05, which failed `testFiltersDarkAppearanceAndMaximumText`.
- Launch arguments, Debug builds only: `--uitesting` (no real session), `--signed-in` (starts with the test server's session), `--reset-searches` (empties its suivis), `--precise-word-timings` (serves word timings, otherwise 404), `--feed-kinds-fixture` (three-item feed for the kind tests). Every fixture launch also empties the seen passages of the test account, so tests stay independent of their order. Login journeys start signed out with the `INFOMETRIE_LOGIN_TEST_ID` environment variable (a UUID) instead of `--signed-in`.
- A sequence page prepares its player on opening: it shows the dock (`player-toggle`, "Écouter"), and `play-sequence` only flashes while the detail loads. Tapping a word there seeks without starting playback.
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
| Suivis, sequence, podcast | `testSearchPersistenceSequenceAndPodcast` |
| Appearance, reading size | `testReadingComfortUpdatesTextImmediatelyAndPersists`, `testReadingSizesRespectSystemAccessibilityAndDarkAppearance`, `testDarkAppearanceAndLargeText` |
| Transcript, player | `testTranscriptSeeksPlayerAndFollowsScrubbingWhilePaused`, `testFullscreenTranscriptKeepsPreciseSeekingAndPlayback`, `testFullscreenTranscriptSeeksFromTextAtMaximumSize` |
| Podcast, word timings | `testPodcastTranscriptUsesCurrentSequenceAndResetsOnNext`, `testPreciseAPITimingsSeekToTwelveSecondsAndLeaveSilencesUnhighlighted`, `testPodcastUsesPreciseAPITimingsAfterChangingSequence` |

## Show it in the simulator

Xcode 27 has no Simulator app: the simulator screen lives in DeviceHub (`/Applications/Xcode.app/Contents/Applications/DeviceHub.app`). After the fast build, on a booted iOS 26.4 iPhone:

```sh
open -a /Applications/Xcode.app/Contents/Applications/DeviceHub.app
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Infometrie.app
xcrun simctl launch --terminate-running-process booted fr.yacast.infometrie.ios
```

- The user reviews with the real account: open the app for them with no test argument, and relaunch it that way after any capture run. `--uitesting --signed-in` points the app at the local test server, which rejects any other login (HTTP 422); it is for the agent's own captures only.

- No simulator booted: `xcrun simctl boot <udid>` with the iOS 26.4 iPhone 17 Pro from `xcrun simctl list devices available`.
- `-appearance dark` or `-appearance light` forces the theme for that launch, and also blocks the Thème picker (the launch argument outranks the stored choice): drive theme changes without it; `-UIPreferredContentSizeCategoryName UICTContentSizeCategoryAccessibilityXXXL` gives the largest text.
- A screenshot, only when asked: `xcrun simctl io booted screenshot <file>.png`, about two seconds after launch.
- To see a screen the agent cannot tap (a pushed page, a sheet, a theme change), write a temporary XCUITest, never committed, that saves `app.screenshot()` PNGs to the scratchpad; run it with `-only-testing`, stop `xcodebuild` as soon as the log shows `Test Case … passed` or `failed` (it may hang finalizing), then delete the file and relaunch the app for the user.
- Client screenshots with real data: run the same kind of temporary test without `--uitesting` on simulators where the user signed in (launch with `-appearance light|dark` only), with the status bar set first (`xcrun simctl status_bar <udid> override --time "9:41" …`, cleared afterwards). The real feed names real politicians: keep these captures out of the repository, which is public. `XCUIScreen.main.screenshot()` on the iPhone 13 mini is 1124 × 2436 while a `simctl` capture and its screen mask are 1080 × 2340: scale a capture to the mask before framing it in a device. A run that is interrupted can leave temporary token patches in `Infometrie/Views`: check `git status` and restore before the next run.
- Motion glitches never show on a screenshot. Record the simulator (`xcrun simctl io <udid> recordVideo --codec=h264 --force <file>.mp4`, stopped with SIGINT) while a temporary UI test, never committed, drives the journey. Then extract frames with `ffmpeg -i <file>.mp4 -vf "select='between(t,A,B)',crop=…,drawtext=text='%{pts\\:hms}'" -vsync vfr`: `-ss` lands on the wrong frames of these variable-frame-rate recordings, and scene detection misses thin changes such as an underline.
- The test server's feed holds seven passages, so a bug tied to scrolling a long list may not reproduce there. Ask the user for a screen recording of the real feed and read it frame by frame the same way.

## Run

- Core: `swift test`.
- UI: `xcodebuild -project Infometrie.xcodeproj -scheme Infometrie -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath build CODE_SIGN_IDENTITY=- test`, with `-only-testing:InfometrieUITests/InfometrieUITests/<test>` to target one journey.
- Keep `CODE_SIGN_IDENTITY=-`. `CODE_SIGNING_ALLOWED=NO` blocks Keychain writes, so login fails.
- The client uses an iPhone 13 mini (5.4", 375 pt wide): an `iPhone 13 mini` simulator on iOS 26.4 (`9A847134-E906-4731-A2EE-4A989B0AAA58`, added on 2026-10-07) is the narrow-screen check.
- Simulators named `iPhone 17 Pro` exist on iOS 26.3, 26.4 and 27.0 (`C94E8A8A-C804-4A5F-A2EF-845BEC187CA8`, added on 2026-10-05; the iOS 17.0 runtime was deleted to free disk space). Validation runs on 26.4. Always target `OS=26.4` or the udid of the device, never the name alone. The disk is nearly full: check free space before downloading another runtime.
- A run can stall before `Testing started` on a simulator that was just booted. Stop it after two minutes without progress, then rerun.
- Run one simulator at a time: the same test launched on two destinations at once (two `-destination` flags) failed on the iPhone 13 mini right away on 2026-10-07, then passed when run alone.
- `testFullscreenTranscriptSeeksFromTextAtMaximumSize` fails at the largest text size: swiping the fullscreen text does not suspend listening-follow, so "Reprendre le suivi" never appears. The same swipe works at the standard size (`testFullscreenTranscriptKeepsPreciseSeekingAndPlayback`). The cause has not been found.
- `testFeedKindSelectionSyncNavigationAndPodcast` is flaky: after switching to Citations it opens a passage while the feed may still be refreshing, and the reload can pop the passage page before the test taps back (`navigationBars["Séquence"]` not found). Rerun it once before suspecting a regression.
- In a sheet ("Tout écouter", filters), a `reveal` swipe can occasionally dismiss the sheet, so the next element is missing and the app shows the feed again. `testPodcastTranscriptUsesCurrentSequenceAndResetsOnNext` hit it once; rerun before suspecting a regression.
- In a sheet, `reveal` stops once a row's centre is in the band above the footer: a shorter list can end before the row clears the margin, and a further drag that cannot scroll taps the row (it opened "Enregistrer un suivi" behind `testSearchPersistenceSequenceAndPodcast`'s back, 2026-10-05).
- `testSearchPersistenceSequenceAndPodcast` was also flaky before that fix: it failed once not finding `sequence-context` after collapsing the summary, and once finding `save-search` not hittable in the filters sheet; both times it passed alone.
- Known failures (full suite 17/20 on 2026-09-25, 17/20 on 2026-10-05 evening): `testLoginFormAndEmptyFilters` (the audit reports clipped text and contrast issues with no exposed element), `testFullscreenTranscriptSeeksFromTextAtMaximumSize` (see above). Causes not found. `testFiltersDarkAppearanceAndMaximumText` passes since the appearance section stopped hiding `appearance-picker`'s identifier.
- `testFilterSearchMultipleSelectionIntersectionAndReset` failed once (`pick-parties` vanished right after existing) and passed alone.
- After the tests finish, `xcodebuild` can hang while finalizing the result bundle. The `Executed N tests` lines in the log are the result; stop the process instead of waiting.
- Every UI test run logs the SwiftUI warning `Adding '_UIReparentingView' as a subview of UIHostingController.view is not supported`. It predates the current changes, so it is not a regression from the change under test. Its cause has not been investigated.
