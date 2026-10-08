# Coding Assertions

The checks that must pass for code to count as done. Scale them to the change: speed matters more than exhaustive proof on every commit.

## Before commit

The fast gate, every change (about 10 seconds).

| Order | Command | Checks |
| ----- | ------- | ------ |
| 1 | `git diff --check` | No whitespace errors |
| 2 | `xcodebuild -project Infometrie.xcodeproj -scheme Infometrie -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGN_IDENTITY=- build` | The app compiles with Swift 6 strict concurrency (incremental in `build/`) |
| 3 | `swift test`, only when `Infometrie/Core` or `Tests/` changed | Core logic, HTTP contract, storage, HLS manifests, word timings |

## When the change shows on screen

The user reviews the result in the simulator themselves: after any change that shows on screen, leave the updated app open on the booted simulator, in DeviceHub (`testing.md`).

| Change | Check |
| ------ | ----- |
| Any change on screen (layout, copy, behavior, navigation) | Open the updated app in the simulator for the user. No UI test and no screenshot unless asked: the user iterates fast and checks the result themselves. UI tests run only on request or before a push. This outranks a plan's acceptance criteria and a skill's assert step: there, the build plus the app open in the simulator is the proof |

## Before push

The heavier gate, only before a push or a pull request, or when the user asks.

| Order | Command | Checks |
| ----- | ------- | ------ |
| 1 | `xcodebuild -project Infometrie.xcodeproj -scheme Infometrie -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath build CODE_SIGN_IDENTITY=- test` | Full UI suite on iPhone, about 15 minutes |

## Keep it fast

- Build and test in the repository's `build/`, never in a clean copy: a clean copy costs a full build.
- No before/after comparison, temporary capture test or run in several appearances unless the user asks for one.
- Keep the simulator booted between checks.

## Behavior

If a fix is needed, spawn one agent per failing assertion (for example tests, build, UI journey = 3 agents).
