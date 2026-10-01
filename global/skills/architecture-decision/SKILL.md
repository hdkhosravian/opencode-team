---
name: architecture-decision
description: Make and record an architecture decision (ADR) and keep the system's layering clean (hexagonal / ports and adapters, dependency rule). Use for decisions that are expensive to reverse.
---

## When an ADR is required
Data model and storage, public API shape, module or service boundaries, framework or vendor choice, security boundary, cross-cutting patterns (errors, logging, transactions, events). Not for local implementation choices.

## ADR file: `docs/adr/NNNN-<slug>.md`
```
# NNNN. <Decision as a short statement>
Status: proposed | accepted | superseded by NNNN
## Context
Forces at play: requirements, constraints, quality attributes (performance, security, operability, cost).
## Options
1. <option> — pros / cons
2. <option> — pros / cons
## Decision
What we do, in one paragraph.
## Consequences
What becomes easier, what becomes harder, what we must now watch. Follow-up invariants (add them to docs/invariants.md).
```

## Default architecture (deviate only with an ADR)
- **Hexagonal / ports and adapters.** From the inside out: `domain` (entities, value objects, domain services, domain events, repository interfaces) ← `application` (use cases; other driven ports such as email, payment, clock) ← `adapters` (HTTP, CLI, DB, queues, external API clients; also called infrastructure) ← `composition root` (wiring). The arrow means "is used by": outer layers depend on inner ones, never the reverse.
- **Dependency rule:** domain imports nothing from application, adapters, or frameworks; application imports only domain.
- **Ports are defined by the inside** (what the use case needs), implemented by adapters.
- **Modular monolith first.** Split into services only when a bounded context needs independent deployment, scaling, or ownership, and record it in an ADR.
- **Make it enforceable:** list the rule in `docs/invariants.md` and ask tech-lead (in the epic) to wire an import-boundary tool into `.opencode/check.cmds` when the stack has one (dependency-cruiser, eslint-plugin-boundaries, import-linter, ArchUnit, packwerk, go-arch-lint).

## Principles for choosing
Prefer the reversible option when two options are close. Prefer boring, well-known technology. Choose the simplest design that satisfies the stated quality attributes; do not design for hypothetical scale.
