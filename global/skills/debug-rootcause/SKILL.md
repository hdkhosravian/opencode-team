---
name: debug-rootcause
description: Find and fix the root cause of a failing test or bug - reproduce, isolate, hypothesize, fix minimally, prove. Use when a failure's cause is not obvious.
---

1. **Reproduce.** Get one command that fails. If you cannot reproduce it, say so; do not guess-fix.
2. **Read the actual error.** The full message and the top relevant stack frame, not your expectation of it.
3. **Isolate.** Shrink the case. Find the first point where actual state diverges from expected state (assert, print, or bisect with `git log -p` on the suspect file).
4. **Hypothesize in one sentence** before changing code: "X happens because Y."
5. **Write a failing test that captures the bug** (red), if one does not already exist.
6. **Fix the cause, minimally.** No try/catch that hides it, no retries over a race, no special case for the test's input.
7. **Prove.** The new test and the whole suite pass; `scripts/check.sh` is green; you can explain why the fix works.

Two wrong hypotheses in a row: stop and write an escalation brief.
