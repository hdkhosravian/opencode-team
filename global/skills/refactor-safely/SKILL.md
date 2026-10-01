---
name: refactor-safely
description: Change the structure of existing code without changing its behavior - characterization tests first, small named refactorings, tests green after every step. Use for legacy code and before modifying untested code.
---

## Before touching untested code
1. Write **characterization tests** that pin the current behavior at the boundary you will change (including behavior that looks wrong; note it, do not fix it now).
2. Run them green. Commit.

## Refactor in small, named steps
Use known refactorings, one at a time, running tests after each: Rename, Extract Function, Inline Function, Extract Variable, Move Function/Field, Introduce Parameter Object, Replace Conditional with Polymorphism, Replace Primitive with Value Object, Extract Interface (at a port), Split Phase, Encapsulate Collection.

## Rules
- Never mix a refactoring commit with a behavior change. Refactor first (tests green), then change behavior in a separate TDD cycle.
- If a step breaks tests, revert that step (`git restore <file>` or `git stash`) instead of debugging forward.
- Keep public interfaces stable unless the card says otherwise; if you must change one, update every caller in the same step.
- Stop when the change the card needs becomes easy. Do not refactor beyond the card's scope.
