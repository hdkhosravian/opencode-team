# Architecture

## Three layers, one direction of trust

```
you ──► /team ──► tech-lead (Sonnet)  decides how, owns state     ← default agent, does the daily work
                    │  │  │
     new product,   │  │  └─ card + commit range ──► reviewer (Sonnet)   ← independent, read-only
     T3 decision    │  └──── card path ──► developer (Gemini)            ← cheap typing, strict TDD
                    │                      developer-strong (Sonnet)     ← T2 / escalated cards
                    ▼
                  lead (Opus)         decides what and why        ← most expensive, called rarely
                  writes brief, ADRs, epics (files), then stops
```

You can also talk to `lead` directly (`Tab`, or `/kickoff`); then it hands epics to `tech-lead` by file path. Information flows down as **file paths** and back up as **short structured reports**. Nothing is passed as a pasted summary, which keeps each hand-off small and lets any agent restart from the files after a context reset.

## One entry point

`/team` is a thin layer over the three layers: a script (`team/route.sh`, no model tokens) reads the project files and prints its state; the tech lead (the default agent) reads that state and what you typed, picks a route, and does one unit of work. `lead` is mode `all` so the tech lead can call it for a new product or a T3 decision; a global `task` deny for `lead` keeps every other agent, OpenCode's built-ins included, from calling the most expensive model (the tech lead's own rule comes later and wins). When the tech lead calls it, `lead` writes its artifacts and stops; it does not call the tech lead back.

Details, the route table and the reasons are in [commands.md](commands.md). Typing to the tech lead without a command works the same way; `/team` only adds the computed state and the playbook.

## How the pieces fit

| Piece | Where | What it is |
|---|---|---|
| Agents | `global/agents/*.md` | Prompt, permissions and step limit per role. The model of each is set by `models.conf` ([models.md](models.md)). |
| Commands | `global/commands/*.md` | `/team` and its shortcuts, `/model`, `/status` ([commands.md](commands.md)). |
| Skills | `global/skills/` + `skills.lock` | Engineering principles loaded on demand ([skills.md](skills.md)). |
| Team scripts | `global/team/` | `bootstrap.sh` (sets a project up), `route.sh` (state for `/team`), `models.py`, `fetch-skills.sh`, the project template. |
| Project files | created in your project | Cards, epics, `PROGRESS.md`, `docs/`, the gate and the board scripts (see the README). |
| Formats | `global/` (1.x) and `global-v2/` (2.x, generated) | Same team, two config formats ([safety-and-permissions.md](safety-and-permissions.md#v1-and-v2-formats)). |
| Installer | `setup.sh` | macOS and Linux ([installation.md](installation.md)). |

## Roles are not agents

Product manager, domain architect and planner are three *hats* of one agent (`lead`), not three Opus agents. A separate agent means rebuilding context and losing detail at each hand-off, so a new agent exists only where one of these differs: the model, the permissions, or the need for an isolated context.

| Agent | Why it exists as its own agent |
|---|---|
| `lead` | Needs the strongest model; must not write code or touch task state |
| `tech-lead` | Sonnet-level judgment for daily work; the only writer of task state; may not write production code |
| `developer` | Cheapest model that can follow a precise card; hard locks on what it can edit |
| `developer-strong` | Same rules, stronger model, used only when risk or a failure justifies it |
| `reviewer` | Different model family from the developer, read-only, fresh context |
| `explore` | Cheap codebase search so expensive agents never open files "to get oriented" |
| `reporter` | `/status` must not be able to edit card state, so it has its own read-only agent instead of the unrestricted built-in `general` |

`build` and `plan` (OpenCode's built-ins) are disabled so there is exactly one way into the team.

## Models

Six roles (`LEAD`, `TECH_LEAD`, `REVIEWER`, `DEVELOPER`, `DEVELOPER_STRONG`, `BACKGROUND`), chosen in one place and changeable at any time with `/model`. The defaults:

| Role | Agents | Default |
|---|---|---|
| `LEAD` | lead | `anthropic/claude-opus-5-5`, variant `high` |
| `TECH_LEAD` | tech-lead (and the default model) | `anthropic/claude-sonnet-5-5` |
| `REVIEWER` | reviewer | `anthropic/claude-sonnet-5-5` |
| `DEVELOPER` | developer | `google/gemini-3.8-flash`, variant `high` |
| `DEVELOPER_STRONG` | developer-strong | `anthropic/claude-sonnet-5-5` |
| `BACKGROUND` | explore, general, title, compaction, summary, reporter | `google/gemini-3.8-flash` |

Keep the reviewer in a different model family from the developer: a model reviewing its own family's output shares its blind spots. The defaults honor this for `developer` (Gemini) but not for `developer-strong` (Sonnet, the same family as the reviewer), so T2 cards rely on the tech lead's own read of the risky diff. `models.py` warns about this; point `REVIEWER` at another provider to close it. Everything about changing models: [models.md](models.md).

## Two-loop TDD

- **Outer loop (tech-lead):** before delegating a card, write Given/When/Then acceptance tests through the public boundary, run them, and confirm they fail for the right reason. Commit `test(NNN): acceptance tests (red)`. These tests are locked: the developer cannot edit them, so "make the test pass" can never mean "change the test".
- **Inner loop (developer):** red, green, refactor on unit tests, one failing test at a time, committing at green and again after refactoring.
- **Gate:** `scripts/check.sh` runs `.opencode/check.cmds` (lint, typecheck, unit tests, an explicit `tests/acceptance` command, an import-boundary check where the stack has one). If acceptance tests exist but no step runs them, the gate fails by itself.

## Skills: principles live in files, not in prompts

Fourteen skills: 13 written for this kit and `loop-contract`, which is installed from its own git repository. Each agent can load only its own skills (enforced by permissions), because skill descriptions are in the prompt on every turn: a reviewer that sees three skills instead of fourteen is cheaper on every single call. The full table (who uses which skill, what it covers) and how third-party skills are fetched and patched: [skills.md](skills.md).

`design-principles` is the anti-complexity brake: YAGNI and the rule of three outrank patterns, every pattern has a "use when / don't use when" table, and tactical DDD is explicitly banned for plain CRUD. Models love adding abstraction; this is the counterweight.

## Left out on purpose

- **A per-task "owner" field.** The role follows from the risk tier.
- **Parallel developers.** Concurrent writers make contradictory decisions about the same files.
- **Running `loop-contract` for every task.** It is for batches and long jobs; a normal card has a cheaper protocol.
- **A separate project-manager agent.** That is `lead`'s planning hat, plus `board.sh` for tracking.
- **A second status file or a "Done" list.** Cards and git already say it, more accurately.
- **A router that guesses intent from your words.** `/team` computes facts from the files with a script and leaves intent to the tech lead, who already picks lanes; the script never interprets free text, and your text never goes into a shell line.
- **Third-party skill packs and token-saver tools** ([evaluated here](tools-evaluated.md)): overlapping workflows confuse models and double the tokens.
