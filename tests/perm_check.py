#!/usr/bin/env python3
"""Permission spot checks against the REAL OpenCode 2.x: reads `opencode debug agents` (the permission list
OpenCode computed after merging global and agent rules) and evaluates it with the documented V2 semantics:
last matching rule wins, `*` = any characters (including /), `?` = one character, a shell pattern ending in
` *` also matches the bare command, no match = ask.

  python3 tests/perm_check.py                    run `opencode debug agents` (config dir from the environment)
  python3 tests/perm_check.py agents.json        use a saved dump
  python3 tests/perm_check.py --v1 DIR           OpenCode 1.x: DIR holds `opencode debug agent NAME > DIR/NAME.json` for each agent
Exit 1 if any check fails. Standard library only."""
import json, re, subprocess, sys

A, D, K = "allow", "deny", "ask"
# (agent, action, resource, expected effect)
CASES = [
    # developer: cannot touch what defines "done"; test-runner config asks; own work is free
    *[("developer", "edit", r, e) for r, e in [
        ("src/app.ts", A), ("tests/unit/app.test.ts", A),
        ("tests/acceptance/a.test.ts", D), ("tests/acceptance/sub/x.py", D), ("tests/acceptance/conftest.py", D),
        ("packages/a/tests/acceptance/x.ts", D), ("tests/blocked/001/x.ts", D),
        ("docs/domain/glossary.md", D), ("PROGRESS.md", D), ("AGENTS.md", D), ("CLAUDE.md", D),
        (".opencode/work/tasks/001-x.md", D), (".opencode/check.cmds", D), (".github/workflows/ci.yml", D),
        ("scripts/check.sh", D), ("scripts/board.sh", D), ("opencode.json", D),
        ("package.json", K), ("pyproject.toml", K), ("conftest.py", K), ("vitest.config.ts", K), ("go.mod", K),
    ]],
    *[("developer", "shell", r, e) for r, e in [
        ("git status", A), ("git diff HEAD", A), ("git add src/a.ts tests/unit/a.ts", A), ("git commit -m 'feat(001): x'", A),
        ("git add -A", D), ("git add --all", D), ("git add .", D), ("git push origin main", D), ("git reset --hard HEAD~1", D),
        ("git restore src/a.ts", D), ("git stash", D), ("git clean -fd", D), ("git checkout -- src/a.ts", D),
        ("rm -rf node_modules", D), ("sudo ls", D),
        ("scripts/check.sh", A), ("./scripts/check.sh", A), ("npm test", A), ("npm run test:unit", A), ("npm run lint:fix", A),
        ("npx vitest run tests/unit", A), ("pytest -q", A), ("python3 -m pytest tests/unit", A), ("go test ./...", A), ("cargo test", A),
        ("curl https://example.com", K), ("echo hi", K), ("npm install left-pad", K),
    ]],
    ("developer", "read", ".env", D), ("developer", "read", "app/.env.local", D), ("developer", "read", "x/.env.example", A),
    ("developer", "read", "keys/server.pem", D), ("developer", "read", "src/app.ts", A),
    ("developer", "skill", "tdd-cycle", A), ("developer", "skill", "loop-contract", D), ("developer", "skill", "task-card", D),
    ("developer", "subagent", "reviewer", D), ("developer", "subagent", "explore", D), ("developer", "webfetch", "https://x.dev", K),
    # developer-strong has the same locks
    *[("developer-strong", "edit", r, e) for r, e in [("src/a.ts", A), ("tests/acceptance/a.ts", D), ("docs/x.md", D), ("package.json", K), ("scripts/board.sh", D)]],
    *[("developer-strong", "shell", r, e) for r, e in [("git add -A", D), ("git add src/a.ts", A), ("git push", D), ("npm run test:acceptance", A)]],
    # reviewer: read-only
    *[("reviewer", "edit", r, D) for r in ("src/a.ts", "PROGRESS.md", "tests/unit/a.ts")],
    *[("reviewer", "shell", r, e) for r, e in [
        ("git diff abc^..def -- src", A), ("git log --oneline -5", A), ("git show HEAD", A), ("git status", A), ("scripts/check.sh", A),
        ("ls", D), ("git commit -m x", D), ("rm -rf x", D), ("echo hi", D)]],
    ("reviewer", "skill", "code-review", A), ("reviewer", "skill", "tdd-cycle", D), ("reviewer", "subagent", "developer", D), ("reviewer", "webfetch", "https://x.dev", D),
    # lead: plans only
    *[("lead", "edit", r, e) for r, e in [
        ("PROGRESS.md", A), ("docs/product/brief.md", A), ("docs/domain/glossary.md", A), ("docs/adr/0001-x.md", A), ("docs/invariants.md", A),
        (".opencode/work/epics/EPIC-01-x.md", A), (".opencode/work/tasks/001-x.md", D), ("src/a.ts", D), ("tests/acceptance/a.ts", D), ("AGENTS.md", D)]],
    *[("lead", "shell", r, e) for r, e in [("scripts/board.sh", A), ("git status", A), ("git log --oneline", A), ("ls", A), ("git add -A", D), ("npm test", D), ("echo hi", D)]],
    ("lead", "subagent", "tech-lead", A), ("lead", "subagent", "explore", A), ("lead", "subagent", "developer", D), ("lead", "subagent", "reviewer", D),
    ("lead", "skill", "product-brief", A), ("lead", "skill", "epic-planning", A), ("lead", "skill", "task-card", D), ("lead", "skill", "loop-contract", D),
    # tech-lead: contracts and state, never production code
    *[("tech-lead", "edit", r, e) for r, e in [
        ("tests/acceptance/a.test.ts", A), ("tests/blocked/001/a.test.ts", A), (".opencode/work/tasks/001-x.md", A), (".opencode/loops/job/ledger.jsonl", A),
        (".opencode/check.cmds", A), ("PROGRESS.md", A), ("AGENTS.md", A), ("docs/adr/0001-x.md", A), ("docs/domain/glossary.md", A), ("docs/invariants.md", A),
        ("src/a.ts", D), ("docs/product/brief.md", D), ("scripts/check.sh", D), ("tests/unit/a.test.ts", D)]],
    *[("tech-lead", "shell", r, e) for r, e in [
        ("git commit -m 'test(001): x'", A), ("git add tests/acceptance/a.ts", A), ("git mv tests/acceptance/a.ts tests/blocked/001/a.ts", A),
        ("scripts/board.sh verify", A), ("scripts/check.sh", A), ("npm test", A), ("pytest -q", A),
        ("python3 ~/.config/opencode/skills/loop-contract/scripts/fold_ledger.py --help", A),
        ("python3 /Users/x/.config/opencode/skills/loop-contract/scripts/fold_ledger.py check", A),
        ("python3 evil.py", K), ("bash ~/.config/opencode/team/bootstrap.sh", A), ("bash evil.sh", K), ("git mv src/a.ts src/b.ts", K),
        ("git push", D), ("git reset --hard", D), ("git clean -fd", D), ("rm -rf x", D), ("sudo ls", D), ("curl https://x.dev", K)]],
    *[("tech-lead", "subagent", r, e) for r, e in [("developer", A), ("developer-strong", A), ("reviewer", A), ("explore", A), ("lead", D), ("reporter", D)]],
    *[("tech-lead", "skill", r, e) for r, e in [("task-card", A), ("acceptance-tests", A), ("loop-contract", A), ("escalation-brief", A), ("product-brief", D), ("tdd-cycle", D)]],
    # reporter (/status): only the board
    ("reporter", "edit", "PROGRESS.md", D), ("reporter", "edit", ".opencode/work/tasks/001-x.md", D),
    ("reporter", "shell", "scripts/board.sh", A), ("reporter", "shell", "scripts/board.sh all", A), ("reporter", "shell", "ls", D), ("reporter", "shell", "git status", D),
    ("reporter", "subagent", "developer", D), ("reporter", "webfetch", "https://x.dev", D),
    # no team agent may read secrets
    *[(a, "read", ".env", D) for a in ("lead", "tech-lead", "reviewer", "developer", "developer-strong", "reporter")],
]


def glob_re(pattern):
    return re.escape(pattern).replace(r"\*", ".*").replace(r"\?", ".")


def rx(pattern, action):
    if action == "shell" and pattern.endswith(" *"):  # also matches the command without arguments
        return re.compile("^" + glob_re(pattern[:-2]) + "( .*)?$", re.S)
    return re.compile("^" + glob_re(pattern) + "$", re.S)


def effect(perms, action, resource):
    result = K  # no match: ask
    for r in perms:
        if r["action"] not in (action, "*"):
            continue
        if rx(r["resource"], action).match(resource):
            result = r["effect"]
    return result


V1_ACTION = {"bash": "shell", "task": "subagent"}


def load_v1(directory):
    """V1 rules are {permission, pattern, action}; map them to the V2 field names."""
    import glob, os
    agents = []
    for path in sorted(glob.glob(os.path.join(directory, "*.json"))):
        d = json.load(open(path))
        agents.append({"id": os.path.basename(path)[:-5], "permissions": [
            {"action": V1_ACTION.get(r["permission"], r["permission"]), "resource": r["pattern"], "effect": r["action"]}
            for r in d["permission"]]})
    return agents


def main(argv):
    if argv[:1] == ["--v1"]:
        agents = load_v1(argv[1])
    elif argv:
        agents = json.load(open(argv[0]))
    else:
        out = subprocess.run(["opencode", "debug", "agents"], capture_output=True, text=True, timeout=90)
        if out.returncode != 0:
            print("opencode debug agents failed:", out.stderr[:300]); return 2
        agents = json.loads(out.stdout)
    if not agents:
        print("no agents in the dump. A cold OpenCode 2.x service answers `debug agents` with [] for about a second: run it again.")
        return 2
    by_id = {a["id"]: a for a in agents}
    bad = 0
    for agent, action, resource, want in CASES:
        if agent not in by_id:
            bad += 1; print(f"FAIL {agent}: agent not registered"); continue
        got = effect(by_id[agent]["permissions"], action, resource)
        if got != want:
            bad += 1; print(f"FAIL {agent:16} {action:8} {resource!r}: expected {want}, got {got}")
    print(f"permission checks: {len(CASES) - bad} of {len(CASES)} ok")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
