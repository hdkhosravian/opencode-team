---
name: acceptance-tests
description: Write the outer-loop acceptance tests for a task card (Given/When/Then, through the public boundary), verify they fail for the right reason, and freeze them before implementation.
---

This is the outer loop of double-loop TDD. The tests describe behavior from the outside; the developer's unit tests are the inner loop.

## Where and how
- Location: `tests/acceptance/`, one file per card or per capability, using the project's normal test framework.
- Test through the public boundary: the use case / application service, the HTTP API, or the CLI. Do not reach into private functions or the database directly unless the behavior is about persistence.
- Name tests as behavior in the glossary's words: `test_customer_cannot_place_order_with_empty_cart`.
- Structure every test as Arrange / Act / Assert (Given / When / Then). One behavior per test.
- Use fakes for external systems at the port boundary (in-memory repository, fake clock, fake payment gateway). You write these fakes in `tests/acceptance/support/`, against the exact port signature fixed in the card. Do not mock what you do not own; wrap it in a port first.
- The gate must run this directory explicitly: make sure `.opencode/check.cmds` has a line containing `tests/acceptance` (scripts/check.sh fails otherwise).
- Deterministic: no real network, no sleeps, fixed clock and random seeds.

## Red before delegation
1. Write the tests against the interfaces named in the card. You do not create production code; if a module or function does not exist yet, the developer creates it.
2. Run them. Acceptable red: an assertion failure, or "not found / not implemented" for exactly the interfaces the card introduces. Not acceptable: a typo, a wrong fixture, or any error in the test itself; fix those before delegating. If the test framework itself is missing, deliver a `000-scaffold` card first.
3. Write the exact failing output (last few lines) into the card under "Acceptance tests" so the developer knows the expected red.
4. Commit: `test(NNN): acceptance tests (red)` (NNN = the card number; `scripts/board.sh verify` looks for it).

## Quality bar
- Each acceptance criterion from the brief/epic maps to at least one test.
- Include at least one negative or edge case per card.
- A test that would still pass if the feature were deleted is a bug in the test.
