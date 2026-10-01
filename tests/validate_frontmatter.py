#!/usr/bin/env python3
"""Every agent, command and skill file must start with valid YAML frontmatter and a description.
Agents must also declare mode, and the V2 copies must declare a model."""
import glob, re, sys, yaml

bad = 0
def fm(path):
    m = re.match(r"^---\n(.*?)\n---\n", open(path).read(), re.S)
    if not m:
        raise ValueError("no frontmatter")
    return yaml.safe_load(m.group(1))

for pattern in ("global/agents/*.md", "global-v2/agents/*.md", "global/commands/*.md",
                "global-v2/commands/*.md", "global/skills/*/SKILL.md"):
    for path in sorted(glob.glob(pattern)):
        try:
            d = fm(path)
            assert d.get("description"), "missing description"
            if "/agents/" in path:
                assert d.get("mode") in ("primary", "subagent", "all"), "bad mode"
            if path.startswith("global-v2/agents/"):
                assert d.get("model"), "missing model"
            if "/skills/" in path:
                assert d.get("name") == path.split("/")[2], "skill name must match its folder"
        except Exception as e:
            bad += 1
            print(f"FAIL {path}: {e}")
print("frontmatter ok" if not bad else f"{bad} problem(s)")
sys.exit(1 if bad else 0)
