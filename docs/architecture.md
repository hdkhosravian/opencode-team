# Architecture

## Three layers, one direction of trust

```
you ──► lead (Opus)         decides what and why        ← most expensive, talks least
            │ epic file path
            ▼
        tech-lead (Sonnet)  decides how, owns state     ← default agent, does the daily work
            │ card path             │ card + commit range
            ▼                       ▼
        developer (Gemini)      reviewer (Sonnet)       ← cheap typing, independent review
        developer-strong (Sonnet) for T2 / escalated cards
```

Information flows down as **file paths** and back up as **short structured reports**. Nothing is passed as a pasted summary, which keeps each hand-off small and lets any agent restart from the files after a context reset.

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

The defaults below come from `models.conf`, the single place where models are chosen (six roles). How to change them: [customizing.md](customizing.md).

| Role | Agents | Default |
|---|---|---|
| `LEAD` | lead | `anthropic/claude-opus-5-5`, variant `high` |
| `TECH_LEAD` | tech-lead (and the default model) | `anthropic/claude-sonnet-5-5` |
| `REVIEWER` | reviewer | `anthropic/claude-sonnet-5-5` |
| `DEVELOPER` | developer | `google/gemini-3.8-flash`, variant `high` |
| `DEVELOPER_STRONG` | developer-strong | `anthropic/claude-sonnet-5-5` |
| `BACKGROUND` | explore, general, title, compaction, summary, reporter | `google/gemini-3.8-flash` |

Keep the reviewer in a different model family from the developer: a model reviewing its own family's output shares its blind spots. The defaults honor this for `developer` (Gemini) but not for `developer-strong` (Sonnet, the same family as the reviewer), so T2 cards rely on the tech lead's own read of the risky diff. `models.py` warns about this; point `REVIEWER` at another provider to close it.

## Two-loop TDD

- **Outer loop (tech-lead):** before delegating a card, write Given/When/Then acceptance tests through the public boundary, run them, and confirm they fail for the right reason. Commit `test(NNN): acceptance tests (red)`. These tests are locked: the developer cannot edit them, so "make the test pass" can never mean "change the test".
- **Inner loop (developer):** red, green, refactor on unit tests, one failing test at a time, committing at green and again after refactoring.
- **Gate:** `scripts/check.sh` runs `.opencode/check.cmds` (lint, typecheck, unit tests, an explicit `tests/acceptance` command, an import-boundary check where the stack has one). If acceptance tests exist but no step runs them, the gate fails by itself.

## Skills: principles live in files, not in prompts

| Skill | Used by | Covers |
|---|---|---|
| `product-brief` | lead | One-page brief: problem, users, outcomes, non-goals |
| `domain-modeling` | lead, tech-lead | DDD, pragmatically: language, contexts, aggregates, invariants. Skipped for plain CRUD |
| `architecture-decision` | lead | ADRs, hexagonal layering, the dependency rule |
| `epic-planning` | lead | Thin vertical slices, riskiest first, frozen slice count |
| `task-card` | tech-lead | Card format, risk tiers, header rules |
| `acceptance-tests` | tech-lead | Outer-loop tests, fakes for ports, confirming the right red |
| `design-principles` | tech-lead, developers, reviewer | SOLID, coupling, YAGNI/KISS, when a pattern is justified |
| `debug-rootcause` | tech-lead, developers | Reproduce, isolate, hypothesize, minimal fix, prove |
| `escalation-brief` | tech-lead, developers | 25-line brief after two failed attempts |
| `loop-contract` | tech-lead only | Large or long jobs. Third-party: installed from its git repository ([details](loop-contract.md)) |
| `tdd-cycle` | developers | Strict red-green-refactor |
| `clean-code` | developers, reviewer | Names, functions, errors, comments, boundaries |
| `refactor-safely` | developers | Characterization tests first, small named refactorings |
| `code-review` | reviewer | Five lenses, evidence-only findings, PASS / PASS WITH NOTES / BLOCK |

Each agent can load only its own skills (enforced by permissions). Skill descriptions are in the prompt on every turn, so a reviewer that sees three skills instead of fourteen is cheaper on every single call.

`design-principles` is the anti-complexity brake: YAGNI and the rule of three outrank patterns, every pattern has a "use when / don't use when" table, and tactical DDD is explicitly banned for plain CRUD. Models love adding abstraction; this is the counterweight.

## Left out on purpose

- **A per-task "owner" field.** The role follows from the risk tier.
- **Parallel developers.** Concurrent writers make contradictory decisions about the same files.
- **Running `loop-contract` for every task.** It is for batches and long jobs; a normal card has a cheaper protocol.
- **A separate project-manager agent.** That is `lead`'s planning hat, plus `board.sh` for tracking.
- **A second status file or a "Done" list.** Cards and git already say it, more accurately.
- **Third-party skill packs and token-saver tools** ([evaluated here](tools-evaluated.md)): overlapping workflows confuse models and double the tokens.
