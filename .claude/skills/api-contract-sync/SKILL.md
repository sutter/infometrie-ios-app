---
name: api-contract-sync
description: Check the live Yacast Swagger against the local API contract, explain what changed for the app, and bring the contract docs and tests up to date. Use when the user asks whether the API changed, after the contract check fails, or before working on a new API route. Not for implementing a feature on a new route.
---

# API contract sync

The local contract is `Docs/API/openapi.yaml`, a copy of `https://hls-test.yacast.fr/swagger/specs.yaml`. Detection is `scripts/check_api_contract.sh`; this skill turns its result into an up-to-date contract and an impact report.

## 1. Detect

Run `scripts/check_api_contract.sh` from the repository root.

- Exit 0: the API is unchanged. Report the version and stop.
- Exit 2: the check could not run. Quote the error line and stop (missing `oasdiff` => `brew install oasdiff`).
- Exit 1: the API changed. The changelog is printed and the live spec is in `build/api-contract/specs.yaml`. Continue.

## 2. Explain the impact

Read the changed paths in `build/api-contract/specs.yaml`: parameters, request bodies, descriptions. The Swagger does not describe response bodies, so a diff never shows a JSON change.

For each change, say what it means for the app:

- Changed or removed route the app calls (`Infometrie/Core/APIClient.swift`, `Infometrie/Services/HLSRelay.swift`): name the affected code. A breaking change comes first in the report.
- New route: say which awaited feature it may serve (`aidd_docs/memory/project-brief.md` lists them, for example the 7 j / 30 j periods and the chart synthesis), or that it serves none yet.
- Say "I don't know" when the spec does not tell what a route returns.

To see a real response body, ask the user first. Private routes need a session of the real account, and a login can hit the device quota: never log in on your own, never send a device replacement, never write a token to a file.

## 3. Update the contract

1. Copy `build/api-contract/specs.yaml` over `Docs/API/openapi.yaml`.
2. In `Docs/API/README.md`: the version, the SHA-256 printed by the script, the refresh date, and the routes and choices the change touches.
3. Wherever the docs quote the Swagger version (`README.md`, `aidd_docs/memory/project-brief.md`), write the new one.
4. Update `Tests/InfometrieCoreTests/SwaggerContractTests.swift` only for routes the app calls, then run `swift test`.
5. Rerun `scripts/check_api_contract.sh`: it must exit 0.

Do not implement a new route or change the app's behavior here: report the opportunity and let the user decide.

## 4. Commit

`git diff --check`, then one commit, for example `docs(api): sync the contract with swagger 0.11.0`. Do not push.
