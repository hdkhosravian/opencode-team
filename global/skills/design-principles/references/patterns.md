# Patterns: trigger and warning

Use a pattern only when its trigger is present in the code or the card today.

| Pattern | Trigger (use it when) | Warning (avoid when) |
|---|---|---|
| Strategy | Several interchangeable algorithms chosen at runtime; a growing `if/switch` on a policy | Only one algorithm exists |
| Factory / factory method | Construction is complex, varies by input, or must enforce invariants | `new X()` is simple and fixed |
| Builder | Many optional parameters or step-wise construction of an immutable object | Few parameters; use a value object or named args |
| Adapter | Wrapping a third-party or legacy API behind your own port | You own both sides |
| Facade | A subsystem is complex and callers need a simple entry point | It just forwards 1:1 calls |
| Decorator | Add cross-cutting behavior (caching, retry, logging, metrics) without changing the core | Behavior is core, not cross-cutting |
| Observer / domain events | Other parts must react to something that happened, without the source knowing them | A single, synchronous, required follow-up; call it directly |
| Command | Actions must be queued, logged, retried, or undone; use-case inputs as objects | Plain function calls suffice |
| State | An object's behavior changes by state with many transitions and guarded rules | Two states and a boolean are clearer |
| Template method | Fixed algorithm skeleton with a few varying steps (prefer Strategy via composition) | Inheritance would couple unrelated subclasses |
| Repository | Persistence of an aggregate behind a domain-owned interface | Simple read models or reports; query directly |
| Unit of work | Several changes must commit atomically across repositories | One aggregate per transaction (the DDD default) |
| Specification | Business rules for selection/validation are combined and reused | A single one-off condition |
| Null object | Many callers check for "missing" with the same default behavior | Absence is an error that should surface |
| Singleton | Almost never. Use dependency injection with a single instance in the composition root | Always prefer DI |
| Anti-corruption layer | Integrating an external or legacy model into your domain | Model is already your own |
| CQRS | Read and write models truly diverge in shape or scale | Ordinary CRUD; it doubles complexity |
| Event sourcing | Full audit history of state changes is a core requirement | Anything else; it is costly to operate |
