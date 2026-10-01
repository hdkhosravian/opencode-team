# Task lifecycle

One principle: **the state of a task lives in the task's own card, and only the tech lead changes it.** There is no second file to drift out of sync. Planning (epics and slices) belongs to `lead`, delivery and state to `tech-lead`, implementation to the developers.

## 0. The entry point: /team

`/team` is the one command that starts all of this ([commands.md](commands.md) has the details). A script, `team/route.sh` (no model tokens), reads the files and prints a state block and the route an **empty** `/team` takes:

| Route | Meaning |
|---|---|
| `INIT` | the project is not set up yet |
| `RESUME` | a card is `doing`: unfinished work |
| `NEXT-CARD` | a `todo` card has all its dependencies done |
| `EPIC` | an epic has unticked slices |
| `KICKOFF` | product docs exist but no epics |
| `BLOCKED` | only blocked cards, or cards waiting on blocked ones, remain |
| `DONE` | every epic is delivered |
| `REPLY` / `STOP` | nothing planned yet / not a git repository |

What you type is never put into a shell line (OpenCode 2.x pastes it in raw, so a quote or a backtick would break or run it). The tech lead sees it as plain text and maps it to a route with a short table: a card id or path is `CARD`, an epic id or path is `EPIC`, `review` is `REVIEW`, free text is `WORK` (or `KICKOFF` when `planned: no`, meaning no epics, cards or product docs). It then follows the route with the delivery loop below, calling `lead` only for `KICKOFF` and T3 decisions. The lane for `WORK` is chosen by the tech lead (next section). `/team all` repeats the unit of work, stopping at 4 slices, a blocked card, an open decision, or when the epic is done.

## 1. Pick a lane

The tech lead chooses the cheapest lane that is safe. If it is unsure between two lanes it takes the lower one; a failed gate or review moves it up.

| Lane | When | What happens |
|---|---|---|
| **Trivial** | A few lines and no new behavior, or a small bug fix with an obvious cause (still one regression test) | One paragraph to `developer`, then `scripts/check.sh`. No card, no review. Commit as `chore:` or `fix:` with no card number |
| **Card** | One behavior. The default | One card, acceptance tests, `developer`, gate, review if T1 |
| **Hard card** | T2 (auth, payments, data loss, migrations, concurrency, security) or Gemini failed for capability reasons | `Dev: developer-strong`, always reviewed, and the tech lead reads the diff of the risky files |
| **Slice** | An epic slice made of several cards | Cards taken in order with `board.sh next`, one developer at a time |
| **Batch** | 6+ similar items, "fix all", migration, backfill, audit, anything that must survive a pause | Load `loop-contract` ([docs](loop-contract.md)); its gate decides completion. Each item is still a normal card |
| **T3** | Architecture decisions and new product direction | The tech lead calls `lead` once (it writes the ADR, brief and epics, then stops); delivery starts after that |

Risk tiers: **T0** mechanical, **T1** normal, **T2** high-risk, **T3** architectural.

## 2. The card

One file per task, `.opencode/work/tasks/NNN-slug.md`. Numbers come from `scripts/board.sh next-id`.

```
# 003 refund
Epic: EPIC-01 | none
Risk: T0 | T1 | T2 | T3
Depends: none | NNN [NNN ...]
Dev: developer | developer-strong
Status: todo | doing | done | blocked
Attempts: 0
Review: - | PASS | PASS WITH NOTES | BLOCK
Note: - | one line
## Behavior
## Scope (only these files may be created or changed)
## Design             <- layers, exact signatures, patterns only if forced
## Acceptance tests (frozen, written by tech lead)
## Test list for the developer (ordered, simplest first)
## Invariants that must hold
## Out of scope
## Check              <- scripts/check.sh
```

The card carries every design decision (naming, layer, signatures, error handling), so a cheap developer never has to make one. The header is edited twice: when the card is delegated (`Status: doing`, `Attempts` +1) and when it is closed.

Commits use the card number as scope: `test(003): acceptance tests (red)`, `feat(003): ...`, `refactor(003): ...`. `board.sh verify` relies on this, and the tech lead commits the final state as `docs(003): card state` so a pause or a fresh clone never loses it.

## 3. The delivery loop

One slice or card per call, so each call starts with a fresh context:

1. Run `scripts/board.sh`; read `PROGRESS.md` and the epic. Ask `explore` for code facts; never bulk-read the repo.
2. Write the next card(s) with `task-card`.
3. For the card about to be delegated only, write its acceptance tests (with fakes for its ports), run them, confirm the expected red, commit.
4. Set `Status: doing`, `Attempts` +1, call the card's `Dev` agent with only the card path.
5. Run `scripts/check.sh` personally and trust only its output.
6. Review by risk (below); record the verdict in `Review:`.
7. On a red gate or a BLOCK: one retry with the exact failing lines. After the second failure: `escalation-brief`, then decide.
8. Set `Status: done` and run `scripts/board.sh verify`. A card is done only when verify exits 0.
9. Tick the slice's box in the epic. When an epic with 3+ cards finishes, run **one** `reviewer` pass over the whole epic range (design and invariants across cards) and turn findings into new cards.
10. Update `PROGRESS.md`, report (30 lines max), stop. The next call continues from the board.

## 4. The board

`scripts/board.sh` is plain bash, awk and git: no Python, no model, no tokens.

| Command | Does |
|---|---|
| `board.sh` | Summary of epics and open cards, about 20 lines |
| `board.sh all` | Every card, one line each |
| `board.sh next` | The next card. An unfinished (`doing`) card is returned first, so resuming is automatic |
| `board.sh next-id` | The next free number |
| `board.sh verify` | Proof checks, exit 1 on any problem |

```
$ scripts/board.sh
BOARD cards 6: done 2, doing 1, todo 2, blocked 1
EPIC-01 orders  slices 1/3  cards 2/6
 003 doing   T2 strong try 1  rev -  refund
 006 blocked T1 dev    try 3  rev BLOCK  export  note: Gemini cannot stream CSV; needs redesign
 004 todo    T1 dev    try 0  rev -  list  after 002
 005 todo    T1 dev    try 0  rev -  notify  after 003

$ scripts/board.sh next
RESUME 003  .opencode/work/tasks/003-refund.md  (T2, developer-strong, try 1)  - unfinished: check git log and scripts/check.sh before delegating
```

### What `verify` checks

- Every card has all header fields, and `Status`, `Review`, `Risk` use the allowed values.
- A `done` card has a `feat|fix|refactor|perf|chore(NNN)` commit (a `test(NNN)` or `docs(NNN)` commit alone doesn't count) and `Attempts` of at least 1.
- A `done` T1+ card has a `PASS` or `PASS WITH NOTES` review, and the acceptance test files listed in its card exist.
- `Attempts` within the caps: 3 for `developer`, 2 for `developer-strong`.
- Dependencies exist and are done before the dependent card is.
- At most one card is `doing`. A `blocked` card has a `Note`.
- An epic's `Slices-frozen: N` equals its number of checkbox lines, and an epic whose slices are all ticked has no open cards.

This is the `loop-contract` idea at card scale: the gate is run, never read.

## 5. Review

| Risk | Review |
|---|---|
| T0 | None |
| T1 | `reviewer` once, on the card's commit range, limited to the card's files |
| T2 | `reviewer`, plus the tech lead reads the risky diff |
| Epic with 3+ cards | One integration review over the whole range |

After a BLOCK and a fix, one re-review of the fix commits only. A second BLOCK means `escalation-brief`, not a third round. PASS WITH NOTES triggers no new round; at most one cheap note is copied into `Note:`. The reviewer returns `VERDICT` plus up to 10 findings, each with `path:line`, evidence and a one-line fix. A finding without evidence is not a finding. It blocks only for incorrect behavior, a security issue, a violated invariant, a missing acceptance criterion, tests that cannot fail, or acceptance tests the gate doesn't actually run.

## 6. When a task is hard

1. First failure: the developer goes back once with the exact failing lines.
2. Second failure: an `escalation-brief` (25 lines max) ends with one decision: card unclear, interface wrong, acceptance test wrong, missing capability, or environment problem.
3. If the card or test was the problem, the tech lead fixes it and retries.
4. If it was a capability limit, `Dev` becomes `developer-strong` with `Attempts: 0` and a note. The strong developer gets 2 runs.
5. Still failing: `Status: blocked`, the reason in `Note:`, a line under *Open decisions* in `PROGRESS.md`. The card's red acceptance tests are parked with `git mv tests/acceptance/<files> tests/blocked/NNN/` (commit `chore(NNN): quarantine blocked card tests`) so the gate stays usable for other cards. Cards that don't depend on it continue. Move the tests back when unblocking.

## 7. New projects

`/team` sets a new project up first (the `INIT` route: bootstrap, `AGENTS.md`, the gate commands). Then the first card is `000-scaffold` (T0): skeleton, test framework, linter, folder layout. It is exempt from red-first and from the gate (there is no gate yet); the developer proves the runner and linter work with one green sample test. The tech lead then writes `.opencode/check.cmds`, runs `scripts/check.sh` once, and only then closes card 000.

## 8. Pausing and resuming

State is in the cards, so nothing is lost when the terminal closes or the context is compacted. Run `/team` again (or tell the tech lead to continue): it runs `board.sh`, finds the `doing` card, reads `git log --oneline -5`, runs the gate, and carries on.

## 9. Epics

`lead` writes epics as 3 to 8 thin vertical slices and records `Slices-frozen: N`. The tech lead only ticks boxes; adding or deleting a slice is the lead's call, and `verify` fails if the numbers disagree. `PROGRESS.md` holds only *Now*, *Open decisions* and *Lessons* (one line each: what failed and the rule that prevents it, at most 10).
