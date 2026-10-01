---
name: task-card
description: Turn a slice or feature into small task cards with scope, interfaces, test list, invariants, and risk tier, so a cheaper model can implement without making design decisions.
---

One card per file: `.opencode/work/tasks/NNN-<slug>.md`. A good card lets a developer succeed without asking a question.

```
# NNN <short name>
Epic: EPIC-NN | none
Risk: T0 | T1 | T2 | T3
Depends: none | NNN [NNN ...]
Dev: developer | developer-strong
Status: todo
Attempts: 0
Review: -
Note: -
## Behavior
One observable behavior, in the glossary's words.
## Scope (only these files may be created or changed)
- production: path/to/file
- unit tests: path/to/test_file
- fakes/fixtures used only by unit tests: path (optional)
## Design
- Layer and module for each new piece (domain / application / adapter).
- Interfaces and signatures, exact:
    <function/method/class signatures, types, errors>
- Patterns to use, only if forced by a named need (see design-principles). Otherwise "none".
## Acceptance tests (frozen, written by tech lead)
- tests/acceptance/<file> :: <test name>
## Test list for the developer (inner TDD loop, in order)
1. <simplest case>
2. <next case>
3. <edge / error case>
## Invariants that must hold
- <from docs/invariants.md or the domain model>
## Out of scope
- <what not to touch or add>
## Check
scripts/check.sh
```

## Rules
- **Size:** one behavior, about 1 to 5 files, finishable in one session. Split otherwise.
- **Decisions live in the card.** Naming, layer placement, signatures, and error handling are decided here by you, not by the developer.
- **The test list is ordered** from the simplest example to edge cases (triangulation). It drives the developer's red-green-refactor cycles.
- **Risk tiers:** T0 mechanical; T1 normal; T2 auth, payments, data loss, migrations, concurrency, security; T3 architecture (needs an ADR from lead first).
- Reference paths; do not paste code from the repo into the card.
- **New or empty project:** the first card is `000-scaffold` (T0): project skeleton, test framework, linter, layout from the ADR. It is exempt from red-first and has no acceptance tests. After it, write `.opencode/check.cmds`.
- Write acceptance tests only for the card you are about to delegate, so earlier cards are never blocked by later red tests.

## Header fields (the card is the task's state; only the tech lead edits them)
- `Dev`: `developer` (Gemini) by default. `developer-strong` (Sonnet) for T2 cards, or after the tech lead decides the failures were a capability limit, not a card defect.
- `Status`: `todo` -> `doing` (when delegated) -> `done` or `blocked`. Nothing else.
- `Attempts`: developer runs used under the current `Dev`; max 3 for `developer`, max 2 for `developer-strong`.
- `Review`: `-` until reviewed, then `PASS`, `PASS WITH NOTES` or `BLOCK`. T0 cards stay `-`.
- `Note`: `-`, or one line: why it is blocked, or a minor review note worth fixing.
- Commits for the card use its number as scope: `feat(007): ...`, `test(007): ...`, `refactor(007): ...`. `scripts/board.sh verify` relies on this.
- Number cards `NNN` with `scripts/board.sh next-id`. Dependencies name card numbers.
