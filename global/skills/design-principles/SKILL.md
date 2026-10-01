---
name: design-principles
description: SOLID, coupling and cohesion, YAGNI/KISS, and when a design pattern is justified. Use before introducing an abstraction, interface, or pattern, and when reviewing design.
---

## SOLID, as checks you can apply
- **S — Single responsibility:** a module has one reason to change (one actor or policy). Test: can you describe it without "and"?
- **O — Open/closed:** add behavior by adding code (a new implementation, a new handler), not by editing a growing `switch` on type. Apply only at variation points that already vary or are stated in the card.
- **L — Liskov substitution:** a subtype must honor the parent's contract: no stronger preconditions, no weaker postconditions, no surprising exceptions. If a subclass needs to "not support" a method, the hierarchy is wrong.
- **I — Interface segregation:** clients depend on small, role-specific interfaces (`OrderReader`, not `OrderRepositoryWithEverything`). Ports are defined by the consumer.
- **D — Dependency inversion:** policy (domain, use cases) depends on abstractions it owns; details (DB, HTTP, SDKs) implement them. Wire concrete classes only in the composition root. Inject dependencies through constructors.

## Balance rules (they override pattern enthusiasm)
- **YAGNI:** do not build for a requirement that is not in the card or brief.
- **KISS:** the simplest thing that passes the tests and keeps the design honest.
- **Rule of three:** abstract after the third real case, not the first.
- **Coupling and cohesion:** minimize what a change ripples into; keep things that change together close together.
- An interface with a single implementation is justified only at a port (for testing or an external dependency), not "for the future".

## Patterns
Use a pattern only when you can name the force it resolves. Read `references/patterns.md` (in this skill folder) for the trigger and the warning for each common pattern before using it. If no trigger applies, write plain code.
