---
name: product-brief
description: Write or update a one-page product brief (problem, users, outcomes, scope, non-goals, acceptance criteria) before any design or code. Use at the start of a product, feature set, or major change.
---

Write `docs/product/<slug>.md`. One page. Every line must help someone decide what to build or not build.

```
# <Name>
## Problem
Who has what pain today, and how we know (evidence or assumption, labeled).
## Users and jobs
- <user type>: when <situation>, they want to <job>, so they can <outcome>.
## Outcomes (measurable)
- <metric or observable result>, target <value>.
## Scope (in)
- Capabilities, stated as user-visible behavior.
## Non-goals (out)
- What we deliberately will not do now, and why.
## Acceptance criteria
- Given <context> When <action> Then <observable result>.
## Constraints
- Compliance, performance, platforms, budget, deadlines.
## Risks and open questions
- <risk> — <mitigation or question for the user>.
```

Rules:
- Behavior, not implementation. "User can export invoices as CSV", not "add ExportService".
- Every acceptance criterion must be testable from outside the system. These become the tech lead's acceptance tests.
- Non-goals are mandatory; they are the main defense against scope creep and token waste.
- Label assumptions. Ask the user when an assumption would change the scope.
