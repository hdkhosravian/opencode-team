# Customizing

What you can change, and where it is documented in detail.

| I want to | See |
|---|---|
| Change a model, switch provider, use a preset | [models.md](models.md): `/model` inside OpenCode, `models.py`, `models.conf` |
| Install, update, roll back, install by hand, Linux | [installation.md](installation.md) |
| Add a skill, use a skill from a git repository | [skills.md](skills.md) |
| Change what `/team` or another command does | [commands.md](commands.md#changing-or-adding-commands) |
| Run the tests, add a test | [testing.md](testing.md) |

The rest of this page: the gate, project rules, the repository layout, regenerating the V2 files, and contributing.

## Change the gate

The gate is `.opencode/check.cmds` in each project: one shell command per line, `#` for comments. It should contain lint, typecheck if any, unit tests, an **explicit** `tests/acceptance` command, and an import-boundary check where the stack has one (dependency-cruiser, import-linter, packwerk, ...). `/team` fills it in when it sets a project up (`/team-init` does the same); only the tech lead edits it. With no `check.cmds`, `scripts/check.sh` auto-detects npm, Python, Go, Cargo or Ruby projects, and exits 2 with `NO CHECKS RAN` if it recognizes nothing. It prints only the last 40 lines of a failing step (`CHECK_TAIL_LINES=N` changes that).

```
npm run lint
npx tsc --noEmit
npx vitest run tests/unit
npx vitest run tests/acceptance
```

## Add a project-specific rule

Put it in the project's `AGENTS.md` (under *Project-specific rules*). If the project has a `CLAUDE.md` and no `AGENTS.md`, use `CLAUDE.md`. Keep it under 40 lines; every agent reads it.

## Change an agent

An agent is `global/agents/<name>.md`: frontmatter (`description`, `mode`, `steps`, `permission`) and the prompt. The model is **not** in the V1 file; it comes from `models.conf` ([models.md](models.md)). Keep prompts short: every token is paid on every turn. Keep the hard `deny` rules at the bottom of each `permission` block, because the last matching rule wins ([safety-and-permissions.md](safety-and-permissions.md)). A new agent needs a role in `global/team/models.py` (`AGENTS`), a line in the table of `docs/architecture.md`, and cases in `tests/perm_check.py`. Then `python3 tools/gen_v2.py`.

## Repository layout

```
models.conf              the default models of the team (six roles)
setup.sh                 macOS and Linux installer and validator (setup.command: double-click wrapper for macOS)
global/                  V1-format team config; skills, AGENTS.md, commands and team/ are shared with V2
  agents/  commands/  skills/  opencode.json  AGENTS.md
  team/
    bootstrap.sh         sets a project up (used by /team and /team-init)
    route.sh             state and route for /team
    models.py  presets/  model choice (/model, apply, check, verify)
    fetch-skills.sh  skills.lock  patches/    third-party skills from git
    project-template/    files copied into a project (scripts/board.sh, scripts/check.sh, ...)
global-v2/               GENERATED from global/ and models.conf for OpenCode 2.x. Never edit by hand
tools/gen_v2.py          the generator (also writes the models into global/opencode.json)
tests/                   board/  route/  fetch_skills/  test_models.py  perm_check.py  validate_frontmatter.py
docs/                    this documentation (English); README.fa.md is the Persian overview
.github/workflows/ci.yml
```

## Regenerate the V2 files

```bash
pip install pyyaml
python3 tools/gen_v2.py
```

It reads `models.conf` (never your `models.local.conf`), writes the models into `global/opencode.json`, and regenerates everything in `global-v2/` from `global/`. CI runs it and fails if the committed files differ.

## Contributing

Issues and PRs are welcome. Please:

- keep prompts short and in English (every token is paid on every turn; non-Latin text costs 2 to 3 times more);
- keep scripts portable to macOS (bash 3.2, BSD tools) and Linux: no GNU-only `sed -i`, no `${var,,}`;
- add a negative test to `tests/board/run.sh` when you add a `verify` rule, a case to `tests/route/run.sh` when you change `route.sh`, and permission cases to `tests/perm_check.py` when you change a permission;
- run `python3 tools/gen_v2.py` and the suites in [testing.md](testing.md) before you push.
