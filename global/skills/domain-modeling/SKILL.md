---
name: domain-modeling
description: Apply Domain-Driven Design pragmatically - ubiquitous language, bounded contexts, aggregates, value objects, domain events, invariants. Use when business rules are non-trivial; skip for plain CRUD.
---

## First decide if DDD is worth it
Use the tactical patterns only where the domain has real rules (state transitions, invariants across several objects, money, scheduling, permissions). For CRUD over a table, use a simple layered design and say so in one line in `docs/domain/model.md`.

## Strategic design (files in `docs/domain/`)
1. `glossary.md` — ubiquitous language: term, one-line definition, context it belongs to, synonyms to avoid. Code, tests, and cards must use these exact words.
2. `context-map.md` — bounded contexts, each with its responsibility in one sentence, and the relationships between them (upstream/downstream, shared kernel, anti-corruption layer, published language). A term may mean different things in different contexts; that is expected.
3. `model.md` — per context: aggregates, their invariants, commands, and events.

## Tactical design rules
- **Entity**: identity matters, lifecycle changes. Behavior lives on it, not in services that poke its fields.
- **Value object**: defined by its values, immutable, validates itself on creation (Money, Email, DateRange). Prefer value objects over primitives for domain concepts.
- **Aggregate**: consistency boundary with one root. External code holds only the root's id. One transaction changes one aggregate. Keep aggregates small; reference others by id.
- **Invariant**: a rule that must always hold; enforce it inside the aggregate and list it in `docs/invariants.md` when it is critical.
- **Domain event**: something that happened, named in past tense (`OrderPlaced`), carries the data other contexts need. Use events across aggregates/contexts instead of direct calls when eventual consistency is acceptable.
- **Domain service**: only for behavior that belongs to no single entity. Stateless.
- **Repository**: one per aggregate root, interface (port) in the domain, implementation in an adapter.
- **Application service / use case**: orchestrates: load aggregate, call behavior, save, publish events. No business rules here.
- **Anti-corruption layer**: translate external models at the boundary; never let a vendor's model leak into the domain.

## Output check
Each aggregate lists: root, invariants, commands, events. Each invariant is testable. No framework or database types appear in the domain model.
