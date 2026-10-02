# Installation

## Requirements

- macOS or Linux, with `bash`, `git` and `curl`. No Homebrew, no Xcode.
- A time limit tool: `timeout` (Linux), `gtimeout` (Homebrew coreutils) or `perl` (every Mac has it). Without any of them the checks run without a limit.
- An API key for each provider you use. The default setup uses Anthropic and Google.
- Optional: `python3` 3.8 or newer (standard library only). It adds the model-ID check, `models.py` (so `/model` and the model choice from `models.conf`), the permission checks and the `loop-contract` gate. Without it everything else works with the default models. On a Mac without developer tools `/usr/bin/python3` is a stub that opens the Xcode installer; `setup.sh` detects that and treats python3 as missing (`xcode-select --install` fixes it).

Windows is not supported.

## Install

```bash
git clone https://github.com/hdkhosravian/opencode-team ~/Tools/opencode-team
bash ~/Tools/opencode-team/setup.sh
```

On macOS you can double-click `setup.command` instead; it runs the same script and keeps the Terminal window open at the end. Everything the script prints is also written to `setup.log` next to it.

| Variable | Effect |
|---|---|
| `OPENCODE_MAJOR=1` | Install the stable 1.x line instead of 2.x (the default). |
| `XDG_CONFIG_HOME` | Where the config goes: `$XDG_CONFIG_HOME/opencode`, default `~/.config/opencode`. |
| `SETUP_PAUSE=1` | Wait for Enter at the end (what `setup.command` sets). |

The script is safe to run again: it is how you **update** the team. Run `git pull` in the clone, then `bash setup.sh`. It is also how you switch between OpenCode 1.x and 2.x (`OPENCODE_MAJOR=1` or not); see the session-database note in [troubleshooting.md](troubleshooting.md#install).

Your own OpenCode settings (plugins, providers, MCP servers) go in `~/.config/opencode/opencode.jsonc`, which `setup.sh` never overwrites; the team's `opencode.json` is replaced on every run.

### What it does

1. **OpenCode.** Runs the official prebuilt installer (`https://opencode.ai/v2/install`, or `/install` for 1.x). If 2.x is not available it falls back to 1.x. It warns when more than one `opencode` is on the PATH (the first one wins) and adds `~/.opencode/bin` to the rc file of your shell (`~/.zshrc`, `~/.bashrc` on Linux or `~/.bash_profile` on macOS for bash, otherwise `~/.profile`) if no rc file mentions it yet.
2. **Team config.**
   - Backs up an existing config folder to `~/.config/opencode.backup-<timestamp>` (every run makes a new backup). It warns if the old config had `provider`, `mcp`, `plugin` or `keybinds` sections, an `opencode.jsonc`, or a global `AGENTS.md` that is not the team's own; copy back what you still need.
   - Copies `global/` (and, for 2.x, `global-v2/` over it) into the config folder. Your `skills/` and other files are not deleted.
   - Applies the models: copies `models.conf` to `team/models.conf` and runs `models.py apply`, which merges your `models.local.conf` (kept across runs). On 2.x it then runs `opencode reload`.
   - Installs the third-party skill from its git repository (`team/fetch-skills.sh`, see [skills.md](skills.md)).
3. **Model IDs.** `models.py check` verifies every distinct model ID against models.dev (needs python3 and network).
4. **Validation** against the real OpenCode:
   - the config resolves (`opencode debug config`);
   - every agent resolves with the model and variant of your choice (2.x: `opencode debug agents`, waiting until the team's own agents appear, because a cold service first lists none or only the built-in ones; 1.x: `opencode debug agent <name>`);
   - 180 permission cases pass on the rules OpenCode computed (`tests/perm_check.py`: edit, shell, read, skill, sub-agent and webfetch rules of all agents);
   - 1.x: all 14 skills are found;
   - a smoke project: `bootstrap.sh`, `check.sh`, `board.sh`, `route.sh` run, and the `loop-contract` gate answers `--help`;
   - the skill files are present.
   If 2.x rejects the V2-format config, setup installs the V1-format config instead (2.x converts it in memory) and says so; the rejected file is saved as `opencode.v2.rejected.json` in the clone.
5. **Providers.** Prints `opencode auth list`. Connecting providers is yours: open `opencode` and run `/connect`.

The end result is `SETUP RESULT: OK`, or `DONE WITH WARNINGS` (see the `WARN` lines). The exit code is 1 only if `curl`, `git` or `opencode` is missing; warnings do not change it. Without python3 the model-ID check, the permission checks and `/model` are reported as skipped, and the rest runs.

### After the install

```bash
cd your-project        # a git repository, not your home folder
opencode
```

1. `/connect`, then add **Anthropic** and **Google** (or the providers you chose in [models.md](models.md)).
2. `/team`. It sets the project up the first time. Or `/team <what you want>` to start working at once. See [commands.md](commands.md).

If an OpenCode 2.x background service was already running during the install, `setup.sh` reloads it. If you still see old agents or models, run `opencode reload` (2.x) or restart `opencode` (1.x).

## What is installed where

```
~/.config/opencode/            (or $XDG_CONFIG_HOME/opencode)
  opencode.json                default model, default agent, permissions, disabled build/plan agents
  AGENTS.md                    team rules every agent reads
  agents/                      lead, tech-lead, developer, developer-strong, reviewer, reporter
  commands/                    team, team-init, kickoff, epic, task, review, status, model
  skills/                      13 own skills + loop-contract (from git)
  team/
    bootstrap.sh               sets a project up (used by /team and /team-init)
    route.sh                   state and route for /team
    models.py  models.conf  models.local.conf  presets/
    fetch-skills.sh  skills.lock  patches/
    project-template/          files copied into a project
```

`service.json` (OpenCode 2.x) may also be there; it is OpenCode's, not the kit's.

## Update, roll back, uninstall

- **Update:** `git pull`, then `bash setup.sh`. Your model choices stay (`models.local.conf`); the skill is re-fetched only if its pinned ref or patch changed.
- **Roll back:** every run left `~/.config/opencode.backup-<timestamp>`. Copy it back over `~/.config/opencode` (or delete the folder and rename the backup).
- **Uninstall the team** and keep OpenCode: restore a backup that predates the kit, or delete the files listed above (`agents/` files, the `team`, `model`, `team-init`, `kickoff`, `epic`, `task`, `review` and `status` commands, the 14 skill folders, `team/`, `AGENTS.md`, `opencode.json`). To remove OpenCode itself, use its own uninstaller (`opencode uninstall`).
- **Projects** keep what `/team` created in them (`PROGRESS.md`, `docs/`, `.opencode/work/`, `scripts/`); remove those by hand if you want.

## Install by hand

If you do not want the installer:

```bash
mkdir -p ~/.config/opencode
cp -R global/. ~/.config/opencode/             # OpenCode 1.x format
cp -R global-v2/. ~/.config/opencode/          # additionally, for OpenCode 2.x
cp models.conf ~/.config/opencode/team/        # so models.py finds the defaults
bash ~/.config/opencode/team/fetch-skills.sh   # third-party skills from their git repositories
chmod +x ~/.config/opencode/team/*.sh ~/.config/opencode/team/project-template/scripts/*.sh
python3 ~/.config/opencode/team/models.py apply   # only if you changed models.conf; reloads 2.x
```

Back up an existing `~/.config/opencode` first: this overwrites files with the same names. Check with `opencode debug agents` (2.x) or `opencode debug agent tech-lead` (1.x).

## Linux notes

- Tested on Ubuntu 24.04 (arm64) with OpenCode 2.x and 1.x: `setup.sh` ends with `SETUP RESULT: OK`. A minimal image with only `curl` and `git` also works: without python3 the model and permission checks are skipped, and without `patch` the skill patch is applied with `git apply`.
- A fresh container needs `apt-get install curl git ca-certificates` first; add `python3` for the checks.
- OpenCode 2.x starts a background service on `127.0.0.1:49374`. If two installs with different `HOME` folders run on one machine, the second cannot start its service and `opencode debug ...` hangs; give it its own port: `opencode service set port 49777`.

## Troubleshooting

[troubleshooting.md](troubleshooting.md) has the install, config and project problems and their fixes.
