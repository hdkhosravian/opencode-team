---
name: clean-code
description: Clean code rules for naming, functions, classes, errors, comments, and boundaries. Use while writing or refactoring code and when reviewing it.
---

## Names
- Reveal intent; use the domain glossary's words. `invoice.markAsPaid()`, not `inv.setStatus(2)`.
- Classes and types are nouns, functions are verbs. Booleans read as questions: `isExpired`, `hasAccess`.
- No abbreviations, no type prefixes, no `Manager`/`Helper`/`Util`/`Data` catch-alls.
- Name length grows with scope: short in a 3-line lambda, descriptive at module level.

## Functions
- Small and at one level of abstraction. If you need a comment to separate sections, extract functions.
- Do one thing. No boolean flag parameters that switch behavior; make two functions.
- Few parameters (0 to 3). More means a missing concept: introduce a value object.
- Prefer command-query separation: a function either changes state or answers a question. Accepted exceptions: a create command returning the new id, an aggregate command returning the domain events it raised, and atomic operations like pop or compare-and-set.
- No hidden side effects. Pure where possible.

## Classes and modules
- High cohesion: everything in a class uses the same data and serves one reason to change.
- Tell, don't ask: put behavior next to the data it uses instead of pulling data out to decide elsewhere.
- Law of Demeter: talk to direct collaborators only; `a.getB().getC().do()` is a smell.
- Prefer composition over inheritance. Keep public surfaces small.

## Errors
- Fail fast at boundaries: validate input where it enters; inside the domain, types and value objects make invalid states unrepresentable.
- Use exceptions or result types consistently with the codebase. Never return null for "not found" if the language offers an option or result type.
- Do not swallow errors. Do not use exceptions for normal control flow. Error messages say what failed and with which value.

## Comments
- Code explains what; comments explain why (a decision, a constraint, a non-obvious reason). Delete commented-out code and comments that restate the code.

## Boundaries and duplication
- Wrap third-party APIs behind your own interface at the edge.
- DRY applies to knowledge, not to lines that look alike. Duplicate twice; abstract on the third, when the shared concept is clear.
- Leave the code cleaner than you found it, but only inside the card's scope.

## Formatting
Follow the project's formatter and linter. Consistency with the surrounding code beats personal preference.
