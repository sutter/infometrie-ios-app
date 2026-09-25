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
- UI tests attach screenshots. Results go to `build/<Name>.xcresult`, which git ignores. Report the result bundle and the counts in `Docs/VALIDATION.md`.
- A failing UI journey is often the driver (keyboard focus, element hidden under the persistent player), not the app. Fix the gesture, never weaken the assertion.
- Screenshots show fictional data only. The repository is public.

## Run

- Core: `swift test`.
- UI: `xcodebuild -project Infometrie.xcodeproj -scheme Infometrie -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath build CODE_SIGN_IDENTITY=- test`, with `-only-testing:InfometrieUITests/InfometrieUITests/<test>` to target one journey.
- Keep `CODE_SIGN_IDENTITY=-`. `CODE_SIGNING_ALLOWED=NO` blocks Keychain writes, so login fails.
