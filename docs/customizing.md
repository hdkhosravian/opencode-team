# Customizing

## Change a model

**From inside OpenCode** (the `/model` command, persistent, no file to edit):

```
/model                                   show the six roles and their models
/model developer openai/gpt-5.4-nano     change one role: provider/model, optional #reasoning-level
/model claude-only                       apply a preset (claude-only, budget; add your own, see below)
/model reset                             back to the defaults (/model reset developer for one role)
```

The choice is written to `~/.config/opencode/team/models.local.conf` and applied to the installed config (V1 and V2). On OpenCode 2.x it is active at once, because `models.py` runs `opencode reload` after applying; on 1.x restart `opencode`. The `/model` command runs on the background model (its `model:` line follows `BACKGROUND`), so it costs almost nothing. `setup.sh` never overwrites `models.local.conf`, so your choices survive an update. For one session only, use OpenCode's own `/models`.

**From a terminal**: `python3 ~/.config/opencode/team/models.py` (an interactive picker that can search models.dev), or `show`, `set ROLE MODEL`, `preset NAME`, `reset [ROLE]`, `apply`, `check` (IDs against models.dev), `verify FILE` (compares what OpenCode 2.x resolved, `opencode debug agents > FILE`, with your choice). It needs `python3` 3.8+ (standard library only); on a Mac without developer tools run `xcode-select --install`.

**The defaults** are `models.conf` in the kit root, six roles, one line each:

```
LEAD=anthropic/claude-opus-5-5#high        # lead (product, domain, architecture, epics)
TECH_LEAD=anthropic/claude-sonnet-5-5      # tech-lead, and the default model
REVIEWER=anthropic/claude-sonnet-5-5       # reviewer
DEVELOPER=google/gemini-3.8-flash#high     # developer
DEVELOPER_STRONG=anthropic/claude-sonnet-5-5   # developer-strong (T2 and escalated cards)
BACKGROUND=google/gemini-3.8-flash         # explore, general, title, compaction, summary, reporter
```

`provider/model` picks the model; `#variant` (optional) is the reasoning level. IDs come from [models.dev](https://models.dev) or `opencode models`. Each provider you use needs `/connect` in OpenCode. To change the defaults for everyone who installs the kit, edit `models.conf` and run `bash setup.sh`.

Presets are files in `global/team/presets/*.conf` (all six roles); add one and it appears in `/model`.

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

## Add a skill from a git repository

Third-party skills are never copied into this kit. List them in `global/team/skills.lock`:

```
# name | git url | commit, tag or branch | folder of the skill in the repo | patch in team/patches/ (optional)
loop-contract|https://github.com/hdkhosravian/loop-contract-skill.git|9d13d9a|skills/loop-contract|loop-contract-opencode.patch
```

`team/fetch-skills.sh` (run by `setup.sh`, or by hand: `bash ~/.config/opencode/team/fetch-skills.sh`) clones each repository at the pinned ref, applies the patch if there is one, and installs the result into `~/.config/opencode/skills/<name>`. An entry that is already installed from the same url, ref and patch is skipped. If the network is down, an installed copy is kept. Then give the skill to the agents that need it in their `permission.skill` block in `global/agents/*.md`, and regenerate V2. To update a skill, change the pinned ref (and regenerate the patch if it no longer applies; `fetch-skills.sh` says so).

## Add or change a skill of your own

A skill is `global/skills/<name>/SKILL.md` with frontmatter (`name` equal to the folder name, and a one-sentence `description` that says when to use it). Keep the description short: it is in the prompt every turn. Then give it to the agents that need it in their `permission.skill` block in `global/agents/*.md`, and regenerate V2.

## Add a project-specific rule

Put it in the project's `AGENTS.md` (under *Project-specific rules*). If the project has a `CLAUDE.md` and no `AGENTS.md`, use `CLAUDE.md`. Keep it under 40 lines; every agent reads it.

## Repository layout

```
models.conf              the default models of the team (six roles)
global/                  V1-format team config; skills, AGENTS.md, commands, team/ are shared with V2
  agents/  commands/  skills/  opencode.json  AGENTS.md
  team/{bootstrap.sh, models.py, presets/, fetch-skills.sh, skills.lock, patches/, project-template/}
global-v2/               GENERATED from global/ and models.conf for OpenCode 2.x. Never edit by hand
tools/gen_v2.py          the generator (also writes the models into global/opencode.json)
setup.sh                macOS and Linux installer and validator (setup.command: double-click wrapper for macOS)
tests/board/             negative tests for board.sh verify
tests/test_models.py     tests for models.py
tests/fetch_skills/      tests for fetch-skills.sh
tests/perm_check.py      permission checks against a real OpenCode
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
python3 tests/test_models.py            # models.py, presets, /model, models.conf
bash tests/fetch_skills/run.sh          # fetch-skills.sh against a local git repository
python3 tests/perm_check.py             # 170 permission checks on what a real OpenCode 2.x resolved (needs `opencode`)
# OpenCode 1.x: mkdir d; for a in lead tech-lead developer developer-strong reviewer reporter; do opencode debug agent $a > d/$a.json; done
python3 tests/perm_check.py --v1 d
```

Each case starts from a clean fixture project, breaks it in one way (done without a commit, a T1 card without a review, an acceptance file that doesn't exist, attempts over the cap, two cards `doing`, tampered slice counts, ...) and expects `board.sh verify` to fail with the right message. A clean board must pass.

## Install without `setup.sh`

To do it by hand (macOS or Linux):

```bash
mkdir -p ~/.config/opencode
cp -R global/. ~/.config/opencode/           # OpenCode 1.x
cp -R global-v2/. ~/.config/opencode/        # additionally, for OpenCode 2.x
cp models.conf ~/.config/opencode/team/      # so models.py can find it
bash ~/.config/opencode/team/fetch-skills.sh # third-party skills from their git repositories
chmod +x ~/.config/opencode/team/bootstrap.sh ~/.config/opencode/team/project-template/scripts/*.sh
```

Back up an existing `~/.config/opencode` first; this overwrites files with the same names. Then, if you changed `models.conf`, run `python3 ~/.config/opencode/team/models.py apply`. Run `opencode debug agents` (2.x) or `opencode debug agent tech-lead` (1.x) to confirm the agents resolve.

## Contributing

Issues and PRs are welcome. Please keep prompts short (every token is paid on every turn), keep the English-only rule for prompts and skills, and add a negative test to `tests/board/run.sh` when you add a `verify` rule.
