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

# cross references: skills and sub-agents named in agent permissions, command agents, models.conf
import os
skills = {os.path.basename(os.path.dirname(p)) for p in glob.glob("global/skills/*/SKILL.md")}
for line in open("global/team/skills.lock", encoding="utf-8"):  # third-party skills come from git at install time
    parts = [x.strip() for x in line.split("|")]
    if line.strip() and not line.startswith("#"):
        skills.add(parts[0])
        if len(parts) > 4 and parts[4] and not os.path.exists("global/team/patches/" + parts[4]):
            bad += 1
            print(f"FAIL global/team/skills.lock: patch {parts[4]} does not exist")
agents = {os.path.basename(p)[:-3] for p in glob.glob("global/agents/*.md")} | {"explore", "general", "build", "plan"}
for path in sorted(glob.glob("global/agents/*.md")):
    perm = fm(path).get("permission", {})
    for kind, known in (("skill", skills), ("task", agents)):
        for name in (perm.get(kind) or {}):
            if name != "*" and name not in known:
                bad += 1
                print(f"FAIL {path}: permission.{kind} names '{name}', which does not exist")
for path in sorted(glob.glob("global/commands/*.md")):
    a = fm(path).get("agent")
    if a is not None and a not in agents:
        bad += 1
        print(f"FAIL {path}: agent '{a}' does not exist")
try:
    sys.path.insert(0, "global/team")
    import models
    conf = models.load_conf("models.conf")
    for agent in (os.path.basename(p)[:-3] for p in glob.glob("global/agents/*.md")):
        models.role_of(agent)  # every agent file needs a role in models.py
except Exception as e:
    bad += 1
    print(f"FAIL models.conf / models.py: {e}")
print("frontmatter ok" if not bad else f"{bad} problem(s)")
sys.exit(1 if bad else 0)
