# Tools evaluated

Each repository was cloned and read before deciding. The question was always the same: does it earn its place in a team whose goals are fewer tokens and no extra moving parts?

| Tool | Verdict | Reason |
|---|---|---|
| [loop-contract-skill](https://github.com/hdkhosravian/loop-contract-skill) | **Adopted** | Frozen scope, oracle-first and a completion gate are exactly what long jobs need. Used for batch work only ([details](loop-contract.md)). It is installed from its own git repository at a pinned commit, never copied into this kit ([skills.md](skills.md)). Its 38 KB `SKILL.md` is why it is visible to the tech lead alone |
| [context-mode](https://github.com/mksglu/context-mode) | Not now | It is a plugin for the OpenCode 1.x API, and compatibility with 2.x isn't documented. It adds 11 tools to every agent's prompt, and its "run all shell through the sandbox" rule collides with this team's fine-grained permissions and TDD flow. It also solves a problem the team already solves: `check.sh` truncates output and hand-offs are file paths |
| [headroom](https://github.com/headroomlabs-ai/headroom) | Not now | A proxy between OpenCode and the model API. It compresses repetitive logs and JSON well, but by its own account does little for prose and already-compact output. It adds a moving part and rewrites prompts, so prompt-cache behavior would have to be verified first |
| [hyperresearch](https://github.com/jordan-gibbs/hyperresearch) | No | Built for Claude Code and Codex. A full run is 16 steps, dozens of sub-agents and hundreds of sources over hours, which is the opposite of saving tokens, and deep research reports aren't what a coding team produces. Use it separately for research |
| [prime-agent](https://github.com/PrimeIntellect-ai/prime-agent) | No | A complete harness that replaces OpenCode, not something that plugs into it |

## When to look again

After a few weeks of real use, if the usage report shows tool output (logs, JSON) as a large share of tokens, re-test **headroom** and **context-mode**. Until then, `tool_output` limits, the read rules in `AGENTS.md` and `check.sh`'s truncation do the same job without a new component.

## Why not the popular skill packs?

Superpowers-style skill collections install their own automatic workflows, which overlap with this pipeline. Two competing processes confuse the model and double the tokens. "Token saver" tools such as RTK and caveman didn't reduce cost in independent tests. And every third-party skill is code that runs with your permissions. The 13 original skills here are short and readable; the 14th is `loop-contract` from this author's own repository, installed from git.
