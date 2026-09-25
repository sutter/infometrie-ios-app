# VCS

The version-control conventions this project follows: branches, commits, and the platform.

## Setup

- Main branch: `main`
- Platform: `github` (`sutter/infometrie-ios-app`, public)

## Branches

- Format: none yet, history is linear on `main`

## Commits

- Convention: Conventional Commits
- Format: `type(scope): description`
- Rules: English, lowercase, imperative mood, one intent per commit
- Scopes in use: `ui`, `feed`, `player`, `transcript`, `api`, `ios`

## Commit Strategy

AI should auto commit: `after task done`

- Commit once the before-commit gate in `coding-assertions.md` passes. Never push unless asked.
- Leave out changes the task did not make (for example the user's work in progress).
