# loop-contract

[loop-contract](https://github.com/hdkhosravian/loop-contract-skill) is a skill for large or long-running jobs. It is installed for the **tech lead only**, and only for real batch work.

## When it runs

Six or more similar items, "fix all of them", a migration, a backfill, an audit, a recurring check, or resuming a paused job of that kind. A single feature or a normal slice never needs it; the card lane has a cheaper protocol.

## What it adds on top of cards

- **Frozen scope.** The list of items is counted and written down before work starts, and the gate compares the count.
- **An oracle written red first.** A check that fails on the unchanged world and passes only when the work is really done.
- **A per-item ledger and verdicts.** Each item needs its own proof; one test cited for twenty rows is rejected by the gate.
- **A gate script** (`fold_ledger.py`, standard-library Python 3) that decides completion. "The agent believes it is finished" is never an input.

Run state lives in `.opencode/loops/<job-slug>/`. Each item is still implemented as a normal task card by `developer` (or `developer-strong`), reviewed by `reviewer`; the ledger adds the proof, it doesn't replace the cards or `board.sh`.

## Changes made for OpenCode

The skill is copied from the upstream repository (MIT) with these differences, all documented in a "host notes" block at the top of `SKILL.md`:

- State path is `.opencode/loops/` instead of `.claude/loops/`, in `SKILL.md` and in the references. It is committed as the audit trail.
- The description is shortened to about 300 characters so the standing prompt stays small.
- Scripts run in place from `~/.config/opencode/skills/loop-contract/scripts/`, never copied into the project.
- Workers are the team's own agents; they never spawn workers; writes are serial; workers return text and only the tech lead writes ledger, index and verdict files.
- `ScheduleWakeup`, `CronCreate`, `/loop`, `/plugin` and Claude memory don't exist in OpenCode. Pausing means updating `PROGRESS.md` and `INDEX.md`, saying the run is paused with counts, and waiting for "continue".
- Triage routes only among the team's lanes.
- It needs `python3`. If Python is missing, the tech lead says so and falls back to the card lane.

`fold_ledger.py` and `extract_requirements.py` are untouched.

## Pinned permission

The tech lead may run exactly `python3 <skills dir>/loop-contract/scripts/fold_ledger.py ...`, not arbitrary Python.
