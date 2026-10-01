# Troubleshooting

`setup.sh` (macOS and Linux; on a Mac you can also double-click `setup.command`) writes everything it does to `setup.log` next to the script. Start there.

## Install

**Homebrew tries to build OpenCode from source and fails on Xcode.** Don't use Homebrew for OpenCode. `setup.sh` uses the official prebuilt installer, which needs neither Homebrew nor a recent Xcode.

**"OpenCode 2.x is not available right now".** The script fell back to the stable 1.x installer and installed the V1-format config. Nothing is wrong; re-run later, or keep 1.x.

**More than one `opencode` on PATH.** The script lists them; the first wins. Remove the stale one (often an old Homebrew copy) or reorder PATH.

**`opencode` not found in a new terminal.** Open a new tab (the script adds `~/.opencode/bin` to `~/.zshrc`, `~/.bashrc`, `~/.bash_profile` or `~/.profile`, whichever your shell reads), or run `export PATH="$HOME/.opencode/bin:$PATH"`.

**macOS blocks `setup.command`.** Run it from Terminal: `bash ~/Tools/opencode-team/setup.sh`.

**"could not download the models.dev catalog".** Model IDs weren't checked, nothing else is affected. Check them yourself with `opencode models`.

## Config

**You had your own config.** It is backed up to `~/.config/opencode.backup-<timestamp>` first. The script warns when the old config had `provider`, `mcp`, `plugin` or `keybinds` sections, or an `opencode.jsonc` or global `AGENTS.md`; copy back what you still need.

**OpenCode 2.x rejects the config.** The script then installs the same configuration in V1 format (2.x normalizes it) and says so in `setup.log`. If you can, open an issue with the `opencode debug config` output.

**`build` and `plan` still show up.** The config disables them; if your version still lists them, just don't use them. Start in `tech-lead` or `lead`.

**"python3 (3.8+) is missing or only the macOS stub".** Developer tools aren't installed, so the `loop-contract` gate can't run. Normal cards are unaffected; run `xcode-select --install` if you want batch jobs.

## In a project

**`/team-init` prints STOP.** It only works inside a git repository (run `git init` yourself) and refuses `$HOME`, Desktop, Documents and Downloads. Open OpenCode in a specific project folder.

**"PROGRESS.md is missing".** The project isn't initialized: run `/team-init`.

**`check.sh` says `NO CHECKS RAN`.** It detected no stack. Write the commands into `.opencode/check.cmds`.

**`check.sh` says acceptance tests exist but no step runs them.** Add an explicit command for `tests/acceptance` to `check.cmds` (examples are printed). A step that only has `--ignore tests/acceptance` doesn't count.

**The developer keeps asking for permission.** Test-runner config files and dependency installs ask on purpose. Approve them when they're legitimate; they're the usual way to make failing tests vanish.

**An existing project has old scripts.** Bootstrap never overwrites, so projects initialized earlier keep their old `scripts/board.sh` and `check.sh`. It tells you when they differ; copy the new ones from `~/.config/opencode/team/project-template/scripts/` if you want the update.

**`board.sh verify` fails on a card you consider done.** Read the message: it names the card and the missing proof (commit scope, review, acceptance file, attempts). Fix the proof, not the check. Commits must be `feat|fix|refactor|perf|chore(NNN): ...` with the card number.

**A card is `blocked` and the gate is red for everyone.** Move its red tests out of the gate: `git mv tests/acceptance/<files> tests/blocked/NNN/`, commit, and move them back when you unblock the card.

**The session was closed mid-task.** Open OpenCode and tell the tech lead to continue. It reads `board.sh`, resumes the `doing` card and re-runs the gate.

## Cost surprises

Check which agent spent the tokens. An Opus session that is reading code means `lead` is being used for routine work: switch to `tech-lead` with `Tab`. Repeated large tool output points at the `tool_output` cap (2.x) or a command that should be piped through `tail -40`.

## Models and skills

**`/model` says "Not changed".** The message names the problem: an unknown role or preset, or a model that is not `provider/model` or `provider/model#variant`. Run `/model` alone for the list.

**`/model` changed the file but nothing changed in OpenCode.** On 2.x `models.py` runs `opencode reload` itself (run it by hand if that failed); on 1.x restart `opencode`. A model for a provider you did not `/connect` fails when used.

**`/model` shows an error about python3.** `/model` runs `python3 ~/.config/opencode/team/models.py`; install python3 (3.8+). Applying a model needs python3, so install it once (macOS: `xcode-select --install`).

**`fetch-skills` says it could not fetch a skill.** It needs `git` and network access to the repository named in `~/.config/opencode/team/skills.lock`. An already installed copy is kept; run `bash ~/.config/opencode/team/fetch-skills.sh` again when the network is back.

**`fetch-skills` says the patch does not apply.** The pinned ref changed or the patch is stale: pin the ref the patch was made for, or regenerate `team/patches/<name>.patch` against the new ref.
