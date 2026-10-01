# Safety and permissions

## The locks

| Who | Cannot edit | Why |
|---|---|---|
| `developer`, `developer-strong` | `tests/acceptance/`, `tests/blocked/`, `docs/` (and any `*/docs/**`), `AGENTS.md`, `CLAUDE.md`, `PROGRESS.md`, `.opencode/` (cards, loop state, `check.cmds`), `.github/`, `opencode.json(c)`, anything under `~/.config/opencode`, `scripts/check.sh`, `scripts/board.sh` | The one who writes code must not decide what "done" means |
| `reviewer` | Anything | Read-only |
| `reporter` (`/status`) | Anything; runs only `scripts/board.sh` | Status must never change state |
| `lead` | Code, cards | Plans only: edits `docs/product|domain|adr`, `docs/invariants.md`, epics, `PROGRESS.md`. Can be **called** only by the tech lead (see *Subagents*) |
| `tech-lead` | Production code | Writes cards, acceptance tests, `check.cmds`, state; developers write code |

Edits that **ask you first**: test-runner and build config (`package.json`, `vitest.config*`, `jest.config*`, `pytest.ini`, `pyproject.toml`, `setup.cfg`, `tox.ini`, `conftest.py`, `.rspec`, `Gemfile`, `go.mod`, `Cargo.toml`) and any dependency install. That is deliberate: these are the usual ways to make failing tests disappear.

For everyone: `git push`, `git reset --hard`, `git clean` and `rm -rf` and `sudo` are denied, `.env`, `*.pem` and `*id_rsa*` can't be read, and `curl`/`wget` ask. Developers additionally can't use `git add -A`, `git add .`, `git restore`, `git stash`, `git checkout --` or `git checkout -f`: they stage explicit paths and undo their own mistakes by editing. `webfetch` asks for `lead` and `tech-lead`, is denied for `reviewer`, and asks for developers.

The reviewer blocks any change that skips or excludes tests, and checks that the `tests/acceptance` step actually ran. `check.sh` fails on its own when acceptance tests exist that no step runs, and ignores steps that only mention the folder in an `--ignore`, `--exclude` or `--deselect` flag.

## Last match wins

OpenCode evaluates permission rules in order and the **last matching rule wins**. The agent files list broad `allow`/`ask` rules first and the hard `deny` rules last. The order matters: with the denies first, a later `"*conftest.py": ask` would reopen `tests/acceptance/conftest.py`. Keep denies at the bottom when you edit these files.

## What each agent can run

- `developer`: git read commands, `git add <paths>`, `git commit`, `scripts/check.sh`, and the usual test, lint, typecheck and build commands (npm, pnpm, yarn, bun, npx vitest/jest/tsc/eslint, pytest and `python3 -m pytest`, uv, ruff, mypy, go, cargo, bundle/rspec/rubocop, bin/rails). Everything else asks.
- `tech-lead`: the same read commands plus `git add`, `git commit`, `git switch`, `git mv tests/*`, `scripts/board.sh`, `scripts/check.sh`, test runners, and three pinned commands: `python3 <skills dir>/loop-contract/scripts/fold_ledger.py ...` from the installed skill, `bash ~/.config/opencode/team/bootstrap.sh` (what `/team` runs to set a project up), and `python3 ~/.config/opencode/team/models.py cmd ...` (what `/team model` runs). Anything else asks, including other `models.py` subcommands and other Python.
- `lead`: `git status`, `git log`, `ls`, `scripts/board.sh`. Nothing else.
- `reviewer`: `git diff|log|show|status` and `scripts/check.sh`.
- `reporter`: `scripts/board.sh`. Nothing else.

## Subagents and skills

Each agent can call only the sub-agents it needs (`lead` → `tech-lead`, `explore`; `tech-lead` → `developer`, `developer-strong`, `reviewer`, `explore`, `lead`; developers, reviewer and reporter → none), and load only its own skills. Sub-agent depth is capped at 2.

**Only the tech lead may call `lead`.** `/team` needs it for a new product or a T3 decision, and `lead` is the most expensive agent, so the global config has `task: lead: deny` for everyone, and the tech lead's own rule (`lead: allow`) comes later and wins. `lead` is mode `all` (so it can be called and still appears with `Tab`); when the tech lead calls it, `lead` writes its artifacts and stops. All of this is covered by the permission cases in `tests/perm_check.py`, run against the real OpenCode on every install.

## Shell lines in commands

A command can run a shell line (`!` plus backticks) before the prompt is sent. OpenCode runs it **outside the agent's permission flow**, so the kit keeps such lines to two things: `/team` runs `team/route.sh`, which only reads the project and prints, and `/model` runs `models.py cmd`, which only touches the model files. `/team` passes **no typed text** to its shell line: OpenCode 2.x pastes `$ARGUMENTS` in raw, so a quote or a backtick in a sentence would break or run it. `/model` does pass your words (role names and model IDs), which `models.py` validates strictly; do not put free text into a shell line in a command of your own.

## Project bootstrap

`/team` (its `INIT` route) and `/team-init` run only inside a git repository, refuses `$HOME`, `~/Desktop`, `~/Documents` and `~/Downloads`, never runs `git init`, never overwrites an existing file, and doesn't create `AGENTS.md` when the project already has `CLAUDE.md` (OpenCode reads `CLAUDE.md` only when `AGENTS.md` is absent). In a monorepo it bootstraps the repository root. If your project's `scripts/` differ from the kit's, bootstrap says so and leaves them alone. The tech lead may run `bootstrap.sh` itself (a pinned permission) when `/team` finds an uninitialized project; it never runs anything else to set up.

## V1 and V2 formats

`global/` is the V1 format (`agent`, `permission` with `bash`/`task` maps). `global-v2/` is **generated** from it and from `models.conf` by `tools/gen_v2.py` into the 2.x format: an ordered `permissions` list of `{action, resource, effect}` entries, `shell` and `subagent` in place of `bash` and `task`, `model: provider/model#variant`, and `agents` in place of `agent`. The generator also emits both relative and absolute path forms of each file rule, and the global `task` deny for `lead` becomes a `subagent` rule. Shell rules ending in `*` become two rules (with and without arguments); `npm run test`, `lint` and `typecheck` also get a `:*` rule, so `npm run test:unit` matches as it does in V1. Never edit `global-v2/` by hand.

OpenCode 2.x reads V1-format config by normalizing it in memory, which is why `setup.sh` can fall back to V1 files if 2.x rejects the V2 ones.
