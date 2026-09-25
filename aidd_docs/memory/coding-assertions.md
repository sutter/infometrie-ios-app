# Coding Assertions

The checks that must pass for code to count as done. Minimal, run after every change.

## Before commit

The fast gate.

| Order | Command | Checks |
| ----- | ------- | ------ |
| 1 | `swift test` | Core logic, HTTP contract, storage, HLS manifests, word timings |
| 2 | `xcodebuild -project Infometrie.xcodeproj -scheme Infometrie -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath build CODE_SIGN_IDENTITY=- build` | The app compiles with Swift 6 strict concurrency |
| 3 | `git diff --check` | No whitespace errors |

## Before push

The heavier gate.

| Order | Command | Checks |
| ----- | ------- | ------ |
| 1 | `xcodebuild -project Infometrie.xcodeproj -scheme Infometrie -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4' -derivedDataPath build CODE_SIGN_IDENTITY=- test` | UI journeys on iPhone |
| 2 | Same command with an iPad simulator (`name=iPad mini (6th generation)`) when the change touches layout | Regular width, sidebar navigation |

## Behavior

If a fix is needed, spawn one agent per failing assertion (for example tests, build, UI journey = 3 agents).
