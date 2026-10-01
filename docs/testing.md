# Testing

Everything the kit does with scripts is tested, and every install is checked against the real OpenCode.

## The suites

| Run | What it covers |
|---|---|
| `python3 tests/validate_frontmatter.py` | Frontmatter of every agent, command and skill (description, mode, model for V2 agents, skill name equals folder). Cross references: every skill an agent may load exists (an own skill, or a line in `skills.lock` whose patch file exists); every sub-agent an agent may call exists; every command's `agent` exists; every agent file has a role in `models.py`; `models.conf` parses. |
| `bash tests/board/run.sh` | 22 cases for `scripts/board.sh verify`. Each starts from a clean fixture project, breaks it in one way (done without a commit, a T1 card without a review, a missing acceptance file, attempts over the cap, two cards `doing`, tampered slice counts, a done card in a repository with no commits, ...) and expects the right error. A clean board must pass; empty projects are checked too. Uses `sed -i.bak`, which works with GNU and BSD `sed`. |
| `bash tests/route/run.sh` | 27 cases for `team/route.sh`, the router behind `/team`: not a git repository, uninitialized project, nothing planned, new product, epic with open slices, a card in progress, next ready card, card number and path, epic id and path, `status`, `review`, `models`, `all`, `go`; and that typed text is never executed or expanded (metacharacters, command substitution, a `*`). |
| `python3 -W error tests/test_models.py` | 12 tests for `models.py`: apply to V1 and V2, set, reset, presets, the `/model` command output (including one argument holding both words), your choice surviving an update, the command's model line, XDG config folder, bad input, the family warning. It never reloads your own OpenCode (`OPENCODE_TEAM_NO_RELOAD=1`). |
| `bash tests/fetch_skills/run.sh` | 11 checks for `fetch-skills.sh` with a local git repository standing in for the upstream: install and patch, other files kept, no `.git`, source stamp, skip on the second run, new ref replaces, a stale patch fails and leaves the install alone, an unreachable repository (kept copy: warning; nothing installed: failure), a wrong folder. |
| `python3 tests/perm_check.py` | 180 permission cases against a **real OpenCode 2.x**: it reads `opencode debug agents` (the rules after OpenCode merged global and agent rules) and evaluates them with the documented semantics (last match wins, `*` is any characters, `?` one, a shell pattern ending in ` *` also matches the bare command, no match = ask). Covers edit, shell, read, skill, sub-agent and webfetch for all agents, including that only the tech lead may call `lead`. `--v1 DIR` does the same for OpenCode 1.x from `opencode debug agent <name> > DIR/<name>.json`. |

Plus one generated-files check: `python3 tools/gen_v2.py` must leave `git status` clean, so `global-v2/` and `global/opencode.json` always match `models.conf` and `global/`.

## Real OpenCode checks (setup.sh)

`setup.sh` runs these on every install, on the OpenCode it just installed: the config resolves, every agent resolves with the model and variant of your choice (`models.py verify`), the 180 permission cases, 14 of 14 skills (1.x), a smoke project (`bootstrap.sh`, `check.sh`, `board.sh`, `route.sh`, the `loop-contract` gate). See [installation.md](installation.md).

These were also run by hand against OpenCode 1.18.34 and 2.0.21, including: changing models with `models.py set` (also to another provider) and seeing the real agents resolve to them; the live reload of the 2.x service after a change; a live `/model` run through the 1.x command system; the tech lead running `scripts/board.sh` while the lead is refused unlisted commands; the tech lead calling `lead` through the real task tool; and the 2.x API (`session.command`) for how a command expands typed text (the reason `/team` keeps typed text out of shell lines).

## CI (GitHub Actions)

| Job | Runs |
|---|---|
| `kit` on **Ubuntu** and **macOS** | Shell syntax of every script; frontmatter and cross references; `gen_v2.py` leaves no diff; `models.py` tests; the board, route and fetch-skills suites; installing the git skill and running the `loop-contract` gate. |
| `setup-linux` (OpenCode **2.x** and **1.x**) | `bash setup.sh` for real on Ubuntu: installs OpenCode, applies models, fetches the skill, resolves every agent, runs the permission cases. It needs opencode.ai, so it is marked as allowed to fail (a warning, not a blocker). |

## Add a test

- A new `board.sh verify` rule: add a negative case to `tests/board/run.sh` (a `run "name" "expected message" "mutation command"` line).
- A new route or keyword for `/team`: add a `check` line to `tests/route/run.sh`.
- A new permission rule: add cases to `CASES` in `tests/perm_check.py`.
- A new model role or preset: `tests/test_models.py`.
- Keep scripts portable: no GNU-only `sed -i`, no `${var,,}`, no associative arrays (macOS ships bash 3.2 and BSD tools).
