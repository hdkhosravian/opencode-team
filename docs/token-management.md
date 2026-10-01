# Token management

Where the tokens go in a multi-agent coding setup, and how this kit closes each leak. Items marked *(V2)* apply to OpenCode 2.x only.

## 1. Spend the expensive model only on decisions

- **The default agent is `tech-lead` (Sonnet), not Opus.** Daily work never reaches Opus. `lead` is called only for a new product (`/kickoff`, or `/team <idea>` when nothing is planned) and for T3 decisions, and only the tech lead can call it.
- **Opus never reads code or diffs.** It asks `explore` (Gemini) one precise question and gets a short answer, and from the tech lead it gets a report of at most 30 lines.
- **Background agents run on the `BACKGROUND` model (Gemini by default):** `explore`, `general`, title generation, summaries, context compaction, `reporter` and the `/model` command. They get called silently and often, so they must be cheap. Change the model of any role with `/model` ([models.md](models.md)).

## 2. Hand off by file, not by chat

- A card, an epic and `PROGRESS.md` are the team's memory. Every sub-agent starts with a fresh context and receives a path, not a retelling.
- `PROGRESS.md` is *Now / Open decisions / Lessons* only. There is no "Done" list, because the cards and git say it more precisely.
- Reports have a fixed format and a line limit (developer 20 lines, tech lead 30, lead 15). No narrative, no restating the task, no code blocks over 5 lines.

## 3. Don't read what a script can tell you

- `scripts/board.sh` prints about 20 lines and costs zero tokens. The model never opens cards to summarize them.
- `scripts/check.sh` prints only the **last 40 lines of a failing step**, and one line (`PASS name`) for each passing one.
- `/status` runs on the background model and only reads the board and `PROGRESS.md`.
- `/team` computes its state with `team/route.sh`, a script: finding out what to do next (is the project set up, which card is in progress, which epic has open slices) costs no model tokens. The command template adds about 700 tokens, only when you use it.
- Shared reading rules in `AGENTS.md`: search first (grep or glob), then read only the needed line range; pipe long output through `tail -40`; evidence is `path:line`.

## 4. Keep the standing prompt small and stable

- **Per-agent skill lists.** Skill descriptions ride along in the prompt on every turn. The reviewer sees 3 skills, not 14, and `loop-contract` is visible to the tech lead only.
- **`loop-contract`'s description is trimmed** from about 1,400 to about 300 characters. Its full body (around 10k tokens) loads only when a job really is a batch.
- **Prompts are short and constant** (about 80 tokens for `reporter`, 250 for `reviewer`, 470 for the developers, 650 for `lead`, 1,600 for the tech lead, which is the largest because the task loop lives in it), which also helps prompt caching. Commands add to the prompt only while they run (`/team` about 700 tokens, the others under 200).
- **Everything is in English.** Persian or other non-Latin text costs 2 to 3 times the tokens, and models follow English instructions more precisely. You can still talk to the agents in your own language.

## 5. Hard ceilings

- **Step limits:** lead 40, tech-lead 80, reviewer 30, developers 80, reporter 8.
- **`/team all` is bounded:** at most 4 slices per call, and it stops at a blocked card or an open decision.
- **Attempt caps per card:** 3 runs for `developer`, 2 for `developer-strong`, then `blocked`. The count is written in the card, so context compaction can't lose it and a retry loop can't run away.
- **One review round after a BLOCK**, never a third; PASS WITH NOTES triggers none.
- **One integration review per epic**, not one per card on top of the card reviews.
- **Review ranges are explicit** (`<first>^..<last>`, limited to code and tests), so the reviewer never diffs the whole history.
- **Tool output cap *(V2)*:** `tool_output` is set to 600 lines and 24 KB (defaults are 2,000 lines and 50 KB). One giant output no longer adds ~12k tokens to every later turn. If an agent keeps hitting the cap, raise it in `opencode.json`.
- **Leave `warming` off *(V2)*.** It sends periodic requests to keep the cache warm, and each one costs tokens. It is off by default and stays that way.

## 6. Cheap lanes for cheap work

A typo fix doesn't need a card, acceptance tests and a review. The trivial lane is one paragraph and one gate run. See [task-lifecycle.md](task-lifecycle.md#1-pick-a-lane).

## What was tried and not adopted

Generic "token saver" proxies and prompt compressors, and routing every shell command through a sandbox plugin: see [tools-evaluated.md](tools-evaluated.md). The short version is that the file-based hand-offs, `tool_output` cap and read rules already remove the biggest sources of waste without adding a moving part.

## Measuring

OpenCode shows token and cost per session. After a week of real use, look at which agent spends most. If tool output (logs, JSON) turns out to be a large share, that is the moment to re-evaluate a compressor.
