# Changelog

## 0.2.0 - task lifecycle

- Task state lives in the card header (8 fields); only the tech lead edits it. New `scripts/board.sh` (summary, `all`, `next`, `next-id`, `verify`) costs zero model tokens.
- Work lanes: trivial, card, hard card, slice, batch. The tech lead picks the cheapest safe one.
- New `developer-strong` (Sonnet) for T2 cards and cards Gemini couldn't do. Attempt caps: 3 for `developer`, 2 for `developer-strong`.
- Review by risk: none for T0, one for T1, plus a diff read for T2, one integration review per epic of 3+ cards. One re-review after a BLOCK, never a third round.
- Epics carry `Slices-frozen: N`; `verify` fails if slices are added or removed behind `lead`'s back.
- Blocked cards park their red tests in `tests/blocked/NNN/` so the gate stays usable.
- `loop-contract` adopted for batch and long jobs (tech lead only), patched for OpenCode.
- Permissions: locks are ordered last so `ask` rules can't reopen them; developers lose `git add -A`, `git restore`, `git stash`; new locks for `.github/`, OpenCode config and `tests/blocked/`; `check.sh` ignores `--ignore/--exclude/--deselect` mentions of `tests/acceptance`.
- `000-scaffold` is exempt from the gate; `check.sh` no longer reads stdin.
- `bootstrap.sh` reports scripts that differ from the kit; `setup.command` warns about `opencode.jsonc` and a personal `AGENTS.md`, and guards against the macOS python3 stub.
- Fixed by an independent review of the kit: 25 findings across prompts, permissions, scripts and docs.
- Added CI, board tests, a frontmatter validator and the V2 generator.

## 0.1.0 - first version

- Lead, tech lead, developer, reviewer, explore. Double-loop TDD with frozen acceptance tests, deterministic gate, 13 skills, token rules.
- Installer using the official prebuilt OpenCode installer (no Homebrew, no Xcode); OpenCode 2.x by default with a 1.x fallback.
