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

| Change | Check |
| ------ | ----- |
| Visual only (layout, color, icon, copy) | One quick screenshot on the booted simulator (`testing.md`), shown to the user. No UI test |
| Behavior, navigation or interaction | The one or two UI tests of the touched area (`testing.md`), on iPhone. Add iPad only when the regular-width layout changed |

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
