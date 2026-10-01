---
name: code-review
description: Review a diff against its task card in five lenses (correctness, design, clean code, tests, security) and report evidence-based findings with a PASS/BLOCK verdict.
---

## Inputs
The task card path and a commit range. Read the card first, then `git diff <range> --stat`, then the diff of each file. Open surrounding code only when a finding depends on it.

## Lens 1: Correctness
- Does it do what the card's behavior and acceptance tests say, and nothing more?
- Edge cases: empty, null/None, boundaries, duplicates, ordering, time zones, concurrency, partial failure.
- Did any signature or behavior change affect existing callers? Check usages of changed symbols.

## Lens 2: Design (load `design-principles` if unsure)
- Dependency rule: nothing in domain imports adapters or frameworks.
- Business rules live in the domain (entities, value objects), not in controllers, use cases, or SQL.
- SOLID violations with a concrete consequence; abstractions without a present need (YAGNI); patterns without a trigger.
- Names match `docs/domain/glossary.md`.

## Lens 3: Clean code (load `clean-code` if unsure)
- Function size and single level of abstraction, flag parameters, long parameter lists, hidden side effects, swallowed errors, dead or commented-out code, duplicated knowledge.

## Lens 4: Tests
- Were tests written for every new behavior? Would they fail if the behavior were broken?
- Tests assert outcomes, not mock call sequences. Deterministic. Behavior-named.
- Acceptance tests unchanged (`git diff <range> -- tests/acceptance` must be empty unless the card says otherwise).
- Gate integrity: any change to test-runner config (package.json test scripts, vitest/jest config, pytest.ini, pyproject.toml, conftest.py, .rspec) that skips, excludes, or narrows tests is a BLOCK. Run `scripts/check.sh` and confirm a step for `tests/acceptance` ran and passed.

## Lens 5: Security
- Untrusted input reaching SQL, shell, file paths, templates, deserializers, or redirects.
- Missing authentication or authorization checks; secrets in code or logs; unsafe defaults.

## Output rules
- Max 10 findings, severity order. Each: `[blocker|major|minor] path:line — problem — evidence — fix`.
- No evidence, no finding. No style nits that the linter would catch.
- BLOCK only for incorrect behavior, security, violated invariant, missing acceptance criterion, or tests that cannot fail.
