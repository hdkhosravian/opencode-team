---
description: Prepare this project for the team (PROGRESS.md, docs/, gate commands, AGENTS.md)
agent: tech-lead
---
Initialize this project for the team:
1. Run `bash ~/.config/opencode/team/bootstrap.sh`. If it prints STOP, relay the message to me and stop.
2. Ask `explore` for: stack and versions, build/lint/typecheck/test commands, source layout, where tests live, and any import-boundary tooling.
3. Fill the `<fill in>` lines of AGENTS.md (or CLAUDE.md if the project uses it). Keep it under 40 lines.
4. Write `.opencode/check.cmds` with the real commands (lint, typecheck, unit tests, `tests/acceptance`, boundary check if available). If the project has no code yet, leave it and plan a `000-scaffold` card.
5. Run `scripts/check.sh` and report the result and what was created, in at most 12 lines.
