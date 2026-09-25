# AI Operating Guidelines

How this team drives AI coding assistants on this project. Keep it short and specific to this repo. Fill the placeholders, drop what does not apply.

## Setup

- Claude Code: `.claude/settings.json` declares the AIDD marketplace and its six stable plugins, and Claude Code offers to install them when the repository is trusted.
- Codex has no project-level plugins, so each contributor installs AIDD once per machine: `codex plugin marketplace add ai-driven-dev/framework`, then `codex plugin add <plugin>@aidd-framework` for `aidd-context`, `aidd-refine`, `aidd-dev`, `aidd-vcs`, `aidd-pm` and `aidd-orchestrator`. `AGENTS.md` then loads the project memory.
- Updates: `/plugin marketplace update aidd-framework` in Claude Code, `codex plugin marketplace upgrade aidd-framework` for Codex.

## House rules

- <A rule the AI must follow here, for example "a failing test comes before any bug fix">
- <A boundary, for example "never edit the generated client under src/api/">
- <A convention the AI keeps, for example "commits stay atomic and intention-revealing">

## Validation depth

- <When a change here needs a quick check versus a full review>
- <What must be green before a merge>

## When the AI drifts

- <How this team recovers, for example "reset the session and restate the objective in one sentence">

For the general AIDD playbook (planning, review loops, prompting and context hygiene, anti-patterns), see the framework docs: <https://github.com/ai-driven-dev/framework>.
