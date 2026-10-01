# Changelog

## 0.4.0 - Linux, skills from git, /model

- **Linux and macOS.** `setup.sh` is the installer (`setup.command` is now a double-click wrapper for macOS). It no longer needs macOS tools: the model-ID check uses `models.py` instead of `osascript`, time limits use `timeout`, `gtimeout` or `perl`, the PATH line goes to the rc file of your shell, and the config folder follows `XDG_CONFIG_HOME`. CI runs the kit checks on Ubuntu and macOS, plus a job that runs `setup.sh` for real on Linux.
- **Third-party skills come from their git repositories.** `loop-contract` is no longer copied into this repository. `global/team/skills.lock` pins its repository and commit, `team/fetch-skills.sh` clones it, applies `team/patches/loop-contract-opencode.patch` (the 142-line OpenCode adaptation) and installs it. Add any skill from git by adding a line. Tested with a local git repository (`tests/fetch_skills/run.sh`).
- **`/model` inside OpenCode.** `/model` shows the six roles; `/model developer openai/gpt-5.4-nano` changes one; `/model claude-only` applies a preset (`claude-only`, `budget`); `/model reset` goes back. Choices are kept in `models.local.conf`, which `setup.sh` never overwrites. On 2.x the change is live at once (`models.py` runs `opencode reload`; 2.x does not reload agent files by itself); on 1.x restart `opencode`. The command runs on the background model. `models.py` without arguments opens an interactive picker that can search models.dev.

## 0.3.0 - models in one place

- **`models.conf`**: every model (six roles: lead, tech-lead, reviewer, developer, developer-strong, background) in one file. `global/team/models.py` (`show`, `set`, `apply`, `check`; standard library only) applies it to the installed config, V1 and V2. `setup.command` applies it on every run and checks exactly those IDs against models.dev. The generator writes it into `global/opencode.json` and `global-v2/`, so the two formats can no longer drift; CI fails on a difference.
- `models.py` warns when the reviewer shares a provider with a developer (with the defaults: Sonnet reviews `developer-strong` on T2 cards).
- New read-only `reporter` agent for `/status`. Before, `/status` ran on the built-in `general` agent, which has no edit lock.
- V2: `npm run test|lint|typecheck` also match `:suffix` scripts (`npm run test:unit`), as in V1.
- `board.sh verify` now fails a `done` card in a repository with no commits (it used to skip the commit check).
- **Checked against the real OpenCode** (1.18.34 and 2.0.21, installed by `setup.command` in a scratch HOME): the config resolves, every agent gets the model and variant from `models.conf`, and `tests/perm_check.py` evaluates 170 permission cases (edit, shell, read, skill, sub-agent, webfetch for all six agents) on the permission lists OpenCode computed. `setup.command` now runs these on every install. A live run with a free model confirmed the tech lead can run `scripts/board.sh` and the lead cannot run unlisted commands.
- Bug found that way: the V2 config did not set a model for the built-in `summary` agent, so it silently used the default (Sonnet) instead of the cheap background model. Fixed.
- `setup.command`: step-4 warnings now count towards the final result; the false "build/plan still listed" notice is gone; `--quiet` and one INFO line replace repeated model warnings.
- `tests/board/run.sh` works with BSD `sed` (macOS); it failed every case there. New cases and tests: `tests/test_models.py`; the frontmatter validator also checks that skills, sub-agents, command agents and roles exist.

## 0.2.0 - task lifecycle

- Task state lives in the card header (8 fields); only the tech lead edits it. New `scripts/board.sh` (summary, `all`, `next`, `next-id`, `verify`) costs zero model tokens.
- Work lanes: trivial, card, hard card, slice, batch. The tech lead picks the cheapest safe one.
- New `developer-strong` (Sonnet) for T2 cards and cards Gemini couldn't do. Attempt caps: 3 for `developer`, 2 for `developer-strong`.
- Review by risk: none for T0, one for T1, plus a diff read for T2, one integration review per epic of 3+ cards. One re-review after a BLOCK, never a third round.
- Epics carry `Slices-frozen: N`; `verify` fails if slices are added or removed behind `lead`'s back.
- Blocked cards park their red tests in `tests/blocked/NNN/` so the gate stays usable.
- `loop-contract` adopted for batch and long jobs (tech lead only), patched for OpenCode.
- Permissions: locks are ordered last so `ask` rules can't reopen them; developers lose `git add -A`, `git restore`, `git stash`; new locks for `.github/`, OpenCode config and `tests/blocked/`; `check.sh` ignores `--ignore/--exclude/--deselect` mentions of `tests/acceptance`.
- `000-scaffold` is exempt from the gate; `check.sh` no longer reads stdin.
- `bootstrap.sh` reports scripts that differ from the kit; `setup.command` warns about `opencode.jsonc` and a personal `AGENTS.md`, and guards against the macOS python3 stub.
- Fixed by an independent review of the kit: 25 findings across prompts, permissions, scripts and docs.
- Added CI, board tests, a frontmatter validator and the V2 generator.

## 0.1.0 - first version

- Lead, tech lead, developer, reviewer, explore. Double-loop TDD with frozen acceptance tests, deterministic gate, 13 skills, token rules.
- Installer using the official prebuilt OpenCode installer (no Homebrew, no Xcode); OpenCode 2.x by default with a 1.x fallback.
