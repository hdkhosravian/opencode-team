# Customizing

## Change a model

All models are in one file, **`models.conf`** in the kit root. Six roles, one line each:

```
LEAD=anthropic/claude-opus-5-5#high        # lead (product, domain, architecture, epics)
TECH_LEAD=anthropic/claude-sonnet-5-5      # tech-lead, and the default model
REVIEWER=anthropic/claude-sonnet-5-5       # reviewer
DEVELOPER=google/gemini-3.8-flash#high     # developer
DEVELOPER_STRONG=anthropic/claude-sonnet-5-5   # developer-strong (T2 and escalated cards)
BACKGROUND=google/gemini-3.8-flash         # explore, general, title, compaction, summary, reporter
```

`provider/model` picks the model; `#variant` (optional) is the reasoning level. IDs come from [models.dev](https://models.dev) or `opencode models`. Each provider you use needs `/connect` in OpenCode.

Three ways to apply a change:

| You want | Run |
|---|---|
| Permanent, from the kit | edit `models.conf`, then `bash setup.command` (reinstalls and applies it, V1 and V2) |
| Quick, on the installed config | `python3 ~/.config/opencode/team/models.py set developer openai/gpt-5.4-nano` |
| Edit by hand, then apply | edit `~/.config/opencode/team/models.conf`, then `python3 ~/.config/opencode/team/models.py apply` |

`models.py show` lists roles, models and warnings; `models.py check` verifies every ID against models.dev; `models.py verify FILE` compares what OpenCode 2.x actually resolved (`opencode debug agents > FILE`) with `models.conf`, which `setup.command` runs for you. It needs a real `python3` (3.8+, standard library only); on a Mac without developer tools run `xcode-select --install`. A quick `set` changes the installed copy only: re-running `setup.command` applies the kit's `models.conf` again (setup tells you when they differ).

`models.py` warns when `REVIEWER` and `DEVELOPER` or `DEVELOPER_STRONG` share a provider, because a reviewer from the same family shares the author's blind spots. With the defaults this happens on T2 cards (Sonnet reviews Sonnet); the tech lead's own read of the risky diff is the safeguard. To close it, point `REVIEWER` at another provider.

In this repository, `python3 tools/gen_v2.py` writes `models.conf` into `global/opencode.json` and regenerates `global-v2/`; CI fails if the committed files differ.

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
models.conf              the models of the team (the only place to change them)
global/                  V1-format team config; skills, AGENTS.md, commands, team/ are shared with V2
  agents/  commands/  skills/  team/{bootstrap.sh, models.py, project-template/}  opencode.json  AGENTS.md
global-v2/               GENERATED from global/ and models.conf for OpenCode 2.x. Never edit by hand
tools/gen_v2.py          the generator (also writes the models into global/opencode.json)
setup.command            macOS installer and validator
tests/board/             negative tests for board.sh verify
tests/test_models.py     tests for models.py
tests/validate_frontmatter.py   frontmatter and cross references (skills, sub-agents, models.conf)
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
python3 tests/validate_frontmatter.py   # frontmatter, plus skills, sub-agents and roles all exist
bash tests/board/run.sh                 # board.sh verify negative tests (GNU and BSD sed)
python3 tests/test_models.py            # models.py and models.conf
python3 tests/perm_check.py             # 170 permission checks on what a real OpenCode 2.x resolved (needs `opencode`)
# OpenCode 1.x: mkdir d; for a in lead tech-lead developer developer-strong reviewer reporter; do opencode debug agent $a > d/$a.json; done
python3 tests/perm_check.py --v1 d
```

Each case starts from a clean fixture project, breaks it in one way (done without a commit, a T1 card without a review, an acceptance file that doesn't exist, attempts over the cap, two cards `doing`, tampered slice counts, ...) and expects `board.sh verify` to fail with the right message. A clean board must pass.

## Install without `setup.command`

On Linux, or to do it by hand:

```bash
mkdir -p ~/.config/opencode
cp -R global/. ~/.config/opencode/           # OpenCode 1.x
cp -R global-v2/. ~/.config/opencode/        # additionally, for OpenCode 2.x
cp models.conf ~/.config/opencode/team/      # so models.py can find it
chmod +x ~/.config/opencode/team/bootstrap.sh ~/.config/opencode/team/project-template/scripts/*.sh
```

Back up an existing `~/.config/opencode` first; this overwrites files with the same names. Then, if you changed `models.conf`, run `python3 ~/.config/opencode/team/models.py apply`. Run `opencode debug agents` (2.x) or `opencode debug agent tech-lead` (1.x) to confirm the agents resolve.

## Contributing

Issues and PRs are welcome. Please keep prompts short (every token is paid on every turn), keep the English-only rule for prompts and skills, and add a negative test to `tests/board/run.sh` when you add a `verify` rule.
