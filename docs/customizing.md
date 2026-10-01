# Customizing

## Change a model

- **OpenCode 2.x:** the `model:` line at the top of `~/.config/opencode/agents/<agent>.md` (for example `anthropic/claude-opus-5-5#high`; what follows `#` is the reasoning variant). Background agents (`explore`, `general`, `title`, `compaction`) are in `opencode.json` under `agents`.
- **OpenCode 1.x:** everything is in `opencode.json` under `agent`.

To make the reviewer cheaper or to swap Gemini for DeepSeek, change just that line. Keep the reviewer in a different model family from the developer. In this repository, change `global/` (and `global-v2/` via the generator below), not the installed copy, if you want the change to survive a re-run of `setup.command`.

## Change the gate

The gate is `.opencode/check.cmds` in each project: one shell command per line, `#` for comments. It should contain lint, typecheck if any, unit tests, an **explicit** `tests/acceptance` command, and an import-boundary check where the stack has one (dependency-cruiser, import-linter, packwerk, ...). `/team-init` fills it in; only the tech lead edits it. With no `check.cmds`, `check.sh` auto-detects npm, Python, Go, Cargo or Ruby projects, and exits 2 with `NO CHECKS RAN` if it recognizes nothing.

```
npm run lint
npx tsc --noEmit
npx vitest run tests/unit
npx vitest run tests/acceptance
```

## Add or change a skill

A skill is `global/skills/<name>/SKILL.md` with frontmatter (`name` equal to the folder name, and a one-sentence `description` that says when to use it). Keep the description short: it is in the prompt every turn. Then give it to the agents that need it in their `permission.skill` block in `global/agents/*.md`, and regenerate V2.

## Add a project-specific rule

Put it in the project's `AGENTS.md` (under *Project-specific rules*). If the project has a `CLAUDE.md` and no `AGENTS.md`, use `CLAUDE.md`. Keep it under 40 lines; every agent reads it.

## Repository layout

```
global/                  V1-format team config; skills, AGENTS.md, commands, team/ are shared with V2
  agents/  commands/  skills/  team/{bootstrap.sh, project-template/}  opencode.json  AGENTS.md
global-v2/               GENERATED from global/ for OpenCode 2.x. Never edit by hand
tools/gen_v2.py          the generator
setup.command            macOS installer and validator
tests/board/             negative tests for board.sh verify
tests/validate_frontmatter.py
.github/workflows/ci.yml
```

## Regenerate the V2 files

```bash
pip install pyyaml
python3 tools/gen_v2.py
```

CI regenerates and fails if `global-v2/` differs from what is committed.

## Run the tests

```bash
python3 tests/validate_frontmatter.py   # agents, commands, skills have valid frontmatter
bash tests/board/run.sh                 # board.sh verify negative tests
```

Each case starts from a clean fixture project, breaks it in one way (done without a commit, a T1 card without a review, an acceptance file that doesn't exist, attempts over the cap, two cards `doing`, tampered slice counts, ...) and expects `board.sh verify` to fail with the right message. A clean board must pass.

## Install without `setup.command`

On Linux, or to do it by hand:

```bash
mkdir -p ~/.config/opencode
cp -R global/. ~/.config/opencode/           # OpenCode 1.x
cp -R global-v2/. ~/.config/opencode/        # additionally, for OpenCode 2.x
chmod +x ~/.config/opencode/team/bootstrap.sh ~/.config/opencode/team/project-template/scripts/*.sh
```

Back up an existing `~/.config/opencode` first; this overwrites files with the same names. Then run `opencode debug agents` (2.x) or `opencode debug agent tech-lead` (1.x) to confirm the agents resolve.

## Contributing

Issues and PRs are welcome. Please keep prompts short (every token is paid on every turn), keep the English-only rule for prompts and skills, and add a negative test to `tests/board/run.sh` when you add a `verify` rule.
