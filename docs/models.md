# Models

Which model each agent uses is chosen in **six roles**. You can change them from inside OpenCode (`/model`), from a terminal (`models.py`), or for everyone who installs the kit (`models.conf`). All three end up in the same place and work for OpenCode 1.x and 2.x.

## The six roles

| Role | Agents that use it | Default |
|---|---|---|
| `LEAD` | `lead` | `anthropic/claude-opus-5-5#high` |
| `TECH_LEAD` | `tech-lead`, and OpenCode's default model | `anthropic/claude-sonnet-5-5` |
| `REVIEWER` | `reviewer` | `anthropic/claude-sonnet-5-5` |
| `DEVELOPER` | `developer` | `google/gemini-3.8-flash#high` |
| `DEVELOPER_STRONG` | `developer-strong` (T2 and escalated cards) | `anthropic/claude-sonnet-5-5` |
| `BACKGROUND` | `explore`, `general`, `title`, `compaction`, `summary`, `reporter`, and the `/model` command | `google/gemini-3.8-flash` |

A value is `provider/model` or `provider/model#variant`. The variant is the reasoning level (`high`, `max`, ...); which names exist depends on the model, and an unknown one is an error in OpenCode. IDs come from [models.dev](https://models.dev) or `opencode models`. Every provider you use needs a key: run `/connect` in OpenCode once per provider.

## Change a model from OpenCode: /model

```
/model                                   show the six roles, which ones you changed (*), and warnings
/model developer openai/gpt-5.4-nano     change one role
/model lead anthropic/claude-sonnet-5-5#high
/model claude-only                       apply a preset
/model reset                             forget all your changes (the defaults come back)
/model reset developer                   forget the change of one role
```

Role names are the agent names in lower case with `-` (`lead`, `tech-lead`, `reviewer`, `developer`, `developer-strong`, `background`). `/team model ...` does the same.

What happens:

1. Your choice is written to `~/.config/opencode/team/models.local.conf` (all of it, or one line per changed role).
2. `models.py` writes the merged result into the installed OpenCode config (see *Where the models are written*).
3. On **OpenCode 2.x** it runs `opencode reload`, so the change is active at once. (2.x keeps the agent files in memory and does not re-read them by itself; this was checked against the real service.) On **1.x** restart `opencode`.

`/model` runs on the cheap background model: the command file has a `model:` line that always follows `BACKGROUND`. It runs in whatever agent you are in, so it costs almost nothing. For one session only, use OpenCode's own `/models`; it does not touch any file.

If a role names a provider you did not connect, the agent fails when it is used ("Model not found"): run `/connect`.

### Presets

A preset is a file with all six roles in `global/team/presets/` (installed to `~/.config/opencode/team/presets/`). `/model <name>` writes it into `models.local.conf`.

| Preset | What it is |
|---|---|
| `claude-only` | One provider: Anthropic only (Opus lead, Sonnet tech lead, reviewer and strong developer, Haiku developer and background). No Google key needed. |
| `budget` | Sonnet instead of Opus for the lead; everything else as the default. |

To add one, drop a `<name>.conf` next to them (same six `ROLE=value` lines) and it shows up in `/model`.

## Change a model from a terminal: models.py

```bash
python3 ~/.config/opencode/team/models.py                 # interactive picker (a terminal), else `show`
python3 ~/.config/opencode/team/models.py show            # roles, models, your changes (*), warnings
python3 ~/.config/opencode/team/models.py set developer openai/gpt-5.4-nano
python3 ~/.config/opencode/team/models.py preset budget   # `preset` alone lists them
python3 ~/.config/opencode/team/models.py reset [role]
python3 ~/.config/opencode/team/models.py apply           # write the current choice into the OpenCode config
python3 ~/.config/opencode/team/models.py check           # every ID against models.dev
python3 ~/.config/opencode/team/models.py verify FILE     # opencode debug agents > FILE: do agents resolve to your choice?
python3 ~/.config/opencode/team/models.py cmd [words]     # what /model runs
```

The **interactive picker** lists the roles, asks for a number, then for a model: type `provider/model[#variant]`, or a few words to search the models.dev catalog (for example `sonnet 5`), pick a number, and optionally a variant. It applies the change and reloads 2.x.

Options: `--dir` (OpenCode config folder; default `${XDG_CONFIG_HOME:-~/.config}/opencode`), `--conf` (the `models.conf` to use), `--quiet` (for `apply`). It needs `python3` 3.8 or newer and nothing else (standard library only). On a Mac without developer tools run `xcode-select --install`.

`check` answers `OK` or `FAIL` per distinct model ID and lists close matches. If models.dev cannot be reached it says so and exits 2 (a network problem is not a config error).

## Defaults and where your choices live

| File | Who writes it | Meaning |
|---|---|---|
| `models.conf` (kit root; installed as `~/.config/opencode/team/models.conf`) | you, to change the **defaults** | Six `ROLE=value` lines. `setup.sh` copies it over the installed one on every run. |
| `~/.config/opencode/team/models.local.conf` | `/model`, `models.py set|preset|reset` | **Your** choices. They override `models.conf` role by role. `setup.sh` never touches it, so they survive updates. Not in git. |

Resolution: `models.conf`, then `models.local.conf` on top. To go back to the defaults: `/model reset`. To change the defaults for everyone who installs the kit: edit `models.conf` and run `bash setup.sh` (and, in a clone of this repository, `python3 tools/gen_v2.py`, see below).

Format rules: one `ROLE=value` per line; lines starting with `#` are comments; no comment after a value (`#` there is the variant separator); unknown roles and malformed values are rejected with the file and line number.

## Where the models are written

`models.py apply` updates the files OpenCode reads, in the format it finds:

| Format | What changes |
|---|---|
| **OpenCode 1.x** (`opencode.json` has `agent`) | `model` (= `TECH_LEAD`), `small_model` (= `BACKGROUND`), and `agent.<name>.model` / `.variant` for every agent in the table above. |
| **OpenCode 2.x** (`opencode.json` has `permissions`) | `model`, the `agents.explore|general|title|compaction|summary.model` entries, and the `model:` line in the frontmatter of `agents/*.md` (`lead`, `tech-lead`, `reviewer`, `developer`, `developer-strong`, `reporter`), written as `provider/model#variant`. |
| Either | The `model:` line of `commands/model.md` follows `BACKGROUND` (without the variant on 1.x). |

Files in V1 format have no model line in the agent files; their models live in `opencode.json`. Both formats are detected per file, so a mixed install works.

## The reviewer-family warning

A reviewer from the same model family as the author shares its blind spots. `models.py show` and `apply` warn when `REVIEWER` and `DEVELOPER` or `DEVELOPER_STRONG` use the same provider. With the defaults the reviewer (Sonnet) is a different family from `developer` (Gemini) but the same as `developer-strong` (Sonnet), which handles T2 cards; the tech lead's own read of the risky diff is the safeguard there. To close the gap, point `REVIEWER` at another provider (`/model reviewer openai/gpt-5.4`).

## In a clone of this repository

`global/opencode.json` and all of `global-v2/` are **generated**. `python3 tools/gen_v2.py` (needs `pyyaml`) reads `models.conf` only (never `models.local.conf`), writes the models into `global/opencode.json`, and regenerates `global-v2/`. CI runs it and fails if the committed files differ, so the two formats cannot drift. After changing the defaults: edit `models.conf`, run the generator, commit.

## Troubleshooting

See [troubleshooting.md](troubleshooting.md#models-and-skills): `/model` says "Not changed", the change does not show up, python3 is missing.
