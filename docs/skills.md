# Skills

A skill is a folder with a `SKILL.md` (plus optional `references/` and `scripts/`). OpenCode shows the skill's one-line description to the agent on every turn and loads the full text only when the agent decides it needs it. This kit uses skills to keep engineering principles out of the prompts.

## Two kinds

| Kind | Where it lives | How it gets installed |
|---|---|---|
| **Own skills** (13) | `global/skills/<name>/` in this repository | Copied with the rest of `global/` by `setup.sh`. |
| **Third-party skills** (`loop-contract`) | **Not** in this repository. Its git repository. | `team/fetch-skills.sh` clones it at a pinned commit, applies the kit's patch, and installs it. |

Nothing from a third-party repository is ever copied into this repository. The only thing stored here is a pin (`skills.lock`) and, if the skill needs adapting, a small patch file.

## Which agent sees which skill

Skill descriptions ride along in the prompt on every turn, so each agent can load only its own skills (enforced by permissions, `permission.skill` in `global/agents/*.md`).

| Skill | Used by | Covers |
|---|---|---|
| `product-brief` | lead | One-page brief: problem, users, outcomes, non-goals |
| `domain-modeling` | lead, tech-lead | Pragmatic DDD: language, contexts, aggregates, invariants. Skipped for plain CRUD |
| `architecture-decision` | lead | ADRs, hexagonal layering, the dependency rule |
| `epic-planning` | lead | Thin vertical slices, riskiest first, frozen slice count |
| `task-card` | tech-lead | Card format, risk tiers, header rules |
| `acceptance-tests` | tech-lead | Outer-loop tests, fakes for ports, confirming the right red |
| `design-principles` | tech-lead, developers, reviewer | SOLID, coupling, YAGNI/KISS, when a pattern is justified |
| `debug-rootcause` | tech-lead, developers | Reproduce, isolate, hypothesize, minimal fix, prove |
| `escalation-brief` | tech-lead, developers | 25-line brief after two failed attempts |
| `loop-contract` | tech-lead only | Large or long jobs ([loop-contract.md](loop-contract.md)) |
| `tdd-cycle` | developers | Strict red-green-refactor |
| `clean-code` | developers, reviewer | Names, functions, errors, comments, boundaries |
| `refactor-safely` | developers | Characterization tests first, small named refactorings |
| `code-review` | reviewer | Five lenses, evidence-only findings, PASS / PASS WITH NOTES / BLOCK |

## Third-party skills from git: skills.lock

`global/team/skills.lock` (installed as `~/.config/opencode/team/skills.lock`), one skill per line, fields separated by `|`:

```
# name | git url | commit, tag or branch | folder of the skill inside the repo | patch in team/patches/ (optional)
loop-contract|https://github.com/hdkhosravian/loop-contract-skill.git|9d13d9a|skills/loop-contract|loop-contract-opencode.patch
```

### What `fetch-skills.sh` does

```bash
bash ~/.config/opencode/team/fetch-skills.sh [--dest DIR]      # default DIR: ~/.config/opencode/skills
```

For every line: clone the repository, check out the ref, copy the skill folder (without `.git`), apply the patch (`patch -p1`, or `git apply` when `patch` is not installed), write `.source` (`url ref folder patch-checksum`), and move the result to `DIR/<name>`. It prints one line per skill:

| Output | Meaning |
|---|---|
| `OK name installed from url@ref (patched: file)` | Fetched and installed. |
| `OK name already installed (ref)` | `.source` matches url, ref, folder and patch: skipped, no network. |
| `WARN name: could not fetch ...; keeping the installed copy` | Network or git problem, and a copy is already installed. Exit code stays 0. |
| `FAIL name: ...` | Nothing installed, or the patch does not apply, or the folder has no `SKILL.md`. Exit code 1, and an installed copy is left alone. |

Environment overrides (used by the tests): `SKILLS_LOCK=<file>`, `SKILLS_PATCHES=<dir>`.

### Add a skill from any git repository

1. Add a line to `global/team/skills.lock`.
2. Give the skill to the agents that should see it: add it to their `permission.skill` block in `global/agents/*.md` (for example `"my-skill": allow`).
3. `python3 tools/gen_v2.py` (regenerates `global-v2/`), then `bash setup.sh` (or only `bash ~/.config/opencode/team/fetch-skills.sh` for the skill itself).

CI checks that every skill an agent names exists (as an own skill or in `skills.lock`) and that every patch in the lock file exists.

### Update a skill

Change the pinned ref in `skills.lock` and run `fetch-skills.sh`. If the patch no longer applies you get `FAIL ... the kit patch ... does not apply` and the installed copy stays. Then regenerate the patch against the new ref:

```bash
mkdir work && cd work
git clone <url> up && git -C up checkout <new-ref>
cp -R up/<folder> a && cp -R a b      # a = untouched upstream, b = the copy you adapt
# edit the files in b the way the kit needs them (state paths, short description, host notes)
diff -ruN a b > ../global/team/patches/<name>.patch
```

`diff -ruN a b` gives the `a/<file>` and `b/<file>` paths that both `patch -p1` and `git apply -p1` accept.

## Own skills

A skill is `global/skills/<name>/SKILL.md` with frontmatter: `name` (equal to the folder name) and a one-sentence `description` that says when to use it. Keep the description short, because it is in the prompt every turn (the tech lead's skill list is the biggest). Then:

1. Add it to the `permission.skill` block of the agents that need it.
2. `python3 tools/gen_v2.py`, then `bash setup.sh`.

`python3 tests/validate_frontmatter.py` checks the frontmatter and that every skill named by an agent exists.

## Why not popular skill packs

Overlapping workflows confuse models and double the tokens, and every third-party skill is code that runs with your permissions. See [tools-evaluated.md](tools-evaluated.md).
