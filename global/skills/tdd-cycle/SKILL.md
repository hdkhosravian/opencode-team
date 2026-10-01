---
name: tdd-cycle
description: Strict red-green-refactor inner loop for implementing a task card - one failing test, the minimal code to pass, then refactor with tests green, repeated through the card's test list.
---

The card's frozen acceptance tests are the outer loop. You run the inner loop until they pass.

## The cycle (repeat for each item in the card's test list)
1. **RED** — Write one small unit test for the next item. Run it. It must fail, and fail for the expected reason (assertion or missing behavior, not a typo or import mistake). If it passes immediately, the test is wrong or the behavior already exists; find out which.
2. **GREEN** — Write the minimum code that makes it pass. Hard-coding is allowed as a step; the next test will force generalization (triangulation). Do not add code for tests you have not written yet.
3. **COMMIT** — at green: `feat|fix(NNN): <behavior>` (NNN = the card number).
4. **REFACTOR** — With all tests green, improve the design: remove duplication, clarify names, extract functions, move behavior to the object that owns the data, apply design principles. Run tests after each small change. Never change behavior during refactor. Commit separately if anything changed: `refactor(NNN): <what>`.

After the test list is done: run the acceptance tests, then `scripts/check.sh`. If an acceptance test still fails, add the missing unit test that explains why, and continue the cycle.

## Test quality rules
- One behavior per test; name states the behavior: `returns_zero_for_empty_cart`.
- Arrange / Act / Assert, visibly separated. No logic (loops, ifs) in tests.
- Test behavior through public interfaces, not private internals. Tests must survive refactoring.
- Fast and deterministic: no network, no real clock, no sleep, no shared mutable state between tests.
- Use test doubles at port boundaries only (repositories, gateways, clock). Prefer fakes over mocks; never mock the thing under test or value objects.
- Cover the edge cases in the card: empty, boundary values, invalid input, error paths.

## Anti-patterns to avoid
Writing all the code then the tests. Tests that assert on mocks' call order instead of outcomes. Snapshot tests for logic. Commenting out or weakening a failing test. Catching exceptions in production code to make a test pass.
