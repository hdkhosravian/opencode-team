---
name: epic-planning
description: Break a product brief into epics made of thin, vertical, independently shippable slices in a sensible delivery order. Use after the brief and before any task cards.
---

Write one file per epic: `.opencode/work/epics/EPIC-NN-<slug>.md`.

```
# EPIC-NN <name>
Slices-frozen: <N, the number of slices below>
Goal: <user-visible outcome, links to docs/product/...>
Bounded context: <name from docs/domain/context-map.md, or "n/a">
Acceptance criteria: <Given/When/Then copied or refined from the brief>
Slices (in order; the tech lead ticks a box when the slice is delivered):
- [ ] S1 <thinnest end-to-end behavior> — why first
- [ ] S2 ...
Risks: <technical or product risk> — <how the first slices reduce it>
Out of scope: <explicit>
Definition of done: acceptance criteria automated and green; scripts/check.sh green; reviewed.
```

## Slicing rules
- **Vertical, not horizontal.** Each slice cuts through all layers and delivers observable behavior. "DB schema for orders" is not a slice; "a customer can place an order for one item" is.
- **Walking skeleton first** for a new system: the thinnest path through every layer, deployed or runnable end to end.
- **Riskiest assumption early.** Order slices to retire the biggest uncertainty first.
- **INVEST:** independent, negotiable, valuable, estimable, small, testable.
- An epic should have 3 to 8 slices. More means it is two epics.
- Do not write task cards here; the tech lead does that, one slice per call.
- **The slice list is frozen when you write it.** `Slices-frozen` must equal the number of checkbox lines. If the plan changes, the lead edits both and says why in the epic's last line; the tech lead never adds or deletes slices. `scripts/board.sh verify` fails when the numbers disagree.
