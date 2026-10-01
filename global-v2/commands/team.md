---
description: One command for everything. /team resumes; /team <what you want>; /team <epic or card path>; /team review, status, init, model ...
agent: tech-lead
---
Input: $ARGUMENTS

State, computed by a script. Trust it. Do not run again what it already reports.

!`bash "${XDG_CONFIG_HOME:-$HOME/.config}/opencode/team/route.sh"`

Choose the route from the Input, do it, then stop and report (30 lines at most, ending with what `/team` will do next):
1. Input empty, or `all`, `auto`, `continue`, `go`: use the ROUTE line above (it is the route for an empty input; for any other input ignore it and use rules 2 to 6). `all`, `auto` and `continue` also mean auto mode.
2. `status` or `board`: print the board and the Now and Open decisions of PROGRESS.md. Nothing else.
3. `model` or `models`, then words: run `python3 ~/.config/opencode/team/models.py cmd <those words>` and print its output as it is.
4. `init`: INIT. `review`, then an optional range: REVIEW.
5. `EPIC-NN` or an epic path: EPIC. A card number or card path: CARD. (The files are listed above.)
6. Anything else is a request: WORK. If the state says `planned: no` and it is a new product or a large, unclear direction, it is KICKOFF; a small task in existing code (many tracked files) stays WORK.
If the project is not initialized, do INIT first for every input except `status` and `model`, then go on with the route above.

Routes:
- STOP: relay the message and stop.
- INIT: run `bash ~/.config/opencode/team/bootstrap.sh` (if it prints STOP, relay it and stop). Ask `explore` for stack and versions, build, lint, typecheck and test commands, source layout, where tests live, and import-boundary tooling. Fill the `<fill in>` lines of AGENTS.md (CLAUDE.md if the project uses it), under 40 lines. Write `.opencode/check.cmds` with the real commands; with no code yet, plan a `000-scaffold` card instead. Run `scripts/check.sh`.
- KICKOFF: call `lead` once. Tell it: the input; write the brief, domain notes, ADRs and epics; you (tech-lead) deliver, so it must not call you; report in at most 15 lines. Then deliver the first slice of the first epic with your delivery loop.
- EPIC: deliver the next undelivered slice of that epic with your delivery loop.
- CARD, RESUME, NEXT-CARD: run that card (RESUME: read `git log --oneline -5` and run the gate first).
- WORK: pick the lane as usual (trivial, card, hard card, slice, batch). A decision with irreversible consequences (T3) goes to `lead`.
- REVIEW: call `reviewer` on the range given, or on `git diff HEAD`, or on `git show HEAD` if that is empty.
- BLOCKED: list the blocked cards with their notes and ask me for the decision. Do not guess.
- DONE: say the epic is delivered, show the board, and suggest the next step.
- REPLY: print the text between REPLY-BEGIN and REPLY-END as it is.
- Auto mode: after a slice finishes with a green gate and no open decision, take the next slice the same way. Stop at 4 slices, at a blocked card, at an open decision, or when the epic is done.
