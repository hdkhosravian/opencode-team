---
name: escalation-brief
description: Write a compact brief when a task is stuck, so a higher tier can decide without re-reading the repository. Use after two failed attempts on the same problem.
---

Return this and stop. At most 25 lines. No narrative, no pasted source files.

```
TASK: <card path> — <one-line goal>
FAILING CHECK: <exact command>
FAILURE: <the 10 most relevant lines of output>
TRIED 1: <change> -> <result>
TRIED 2: <change> -> <result>
HYPOTHESIS: <best guess at the real cause>
SUSPECT FILES: <path:line, ...>
DECISION NEEDED: <one of: card unclear | interface wrong | acceptance test wrong | missing dependency or capability | environment problem> — <the specific question>
```

If the honest answer is that the card or acceptance test is wrong, say so plainly. That is the most useful escalation.
