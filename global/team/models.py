#!/usr/bin/env python3
"""Choose the models of the OpenCode team in one place (models.conf). Standard library only.

  models.py show                    roles, models, and warnings
  models.py set ROLE provider/model[#variant]   change one role, then apply
  models.py apply                   write models.conf into the OpenCode config
  models.py check                   verify every model ID against models.dev
  models.py verify FILE             compare the agents OpenCode 2.x resolved (opencode debug agents > FILE) with models.conf

--dir  OpenCode config folder (default ~/.config/opencode; V1 and V2 formats are detected)
--conf models.conf to use (default: next to this script, else the kit's models.conf)
"""
import argparse, json, os, re, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROLES = ["LEAD", "TECH_LEAD", "REVIEWER", "DEVELOPER", "DEVELOPER_STRONG", "BACKGROUND"]
AGENTS = {  # role -> agents that use it
    "LEAD": ["lead"],
    "TECH_LEAD": ["tech-lead"],
    "REVIEWER": ["reviewer"],
    "DEVELOPER": ["developer"],
    "DEVELOPER_STRONG": ["developer-strong"],
    "BACKGROUND": ["explore", "general", "title", "compaction", "summary", "reporter"],
}
V2_JSON_AGENTS = ["explore", "general", "title", "compaction", "summary"]  # background agents kept in V2 opencode.json
VALUE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.:/@+-]+(#[A-Za-z0-9_-]+)?$")


def role_of(agent):
    return next(r for r, names in AGENTS.items() if agent in names)


def norm_role(name):
    r = name.strip().upper().replace("-", "_")
    return "BACKGROUND" if r == "BG" else r


def default_conf():
    for p in (os.path.join(HERE, "models.conf"), os.path.join(HERE, "..", "..", "models.conf")):
        if os.path.exists(p):
            return os.path.normpath(p)
    sys.exit("models.conf not found; pass --conf")


def _read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def _write(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def load_conf(path):
    conf = {}
    for n, line in enumerate(_read(path).splitlines(), 1):
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        key, sep, val = s.partition("=")
        key = key.strip()
        if not sep or key not in ROLES:
            raise ValueError(f"{path}:{n}: unknown role '{key}' (valid: {', '.join(ROLES)})")
        if not VALUE.match(val.strip()):
            raise ValueError(f"{path}:{n}: '{val.strip()}' is not provider/model or provider/model#variant")
        conf[key] = val.strip()
    missing = [r for r in ROLES if r not in conf]
    if missing:
        raise ValueError(f"{path}: missing {', '.join(missing)}")
    return conf


def agent_value(conf, agent):
    return conf[role_of(agent)]


def split(value):
    model, _, variant = value.partition("#")
    return model, variant


def write_conf_value(path, role, value):
    text = _read(path)
    new, n = re.subn(rf"(?m)^{role}=.*$", f"{role}={value}", text)
    if n == 0:
        new = text.rstrip("\n") + f"\n{role}={value}\n"
    _write(path, new)


def _dump(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
        f.write("\n")


def apply_dir(d, conf):
    """Write the models into the config folder d. Returns the list of changed files."""
    changed = []
    jp = os.path.join(d, "opencode.json")
    cfg = json.loads(_read(jp))
    before = json.dumps(cfg, sort_keys=False)
    v2 = "permissions" in cfg
    if v2:
        cfg["model"] = conf["TECH_LEAD"]
        for name in V2_JSON_AGENTS:
            if name in cfg.get("agents", {}):
                cfg["agents"][name]["model"] = conf["BACKGROUND"]
    else:
        cfg["model"] = split(conf["TECH_LEAD"])[0]
        cfg["small_model"] = split(conf["BACKGROUND"])[0]
        agents = cfg.setdefault("agent", {})
        for role, names in AGENTS.items():
            model, variant = split(conf[role])
            for name in names:
                entry = agents.setdefault(name, {})
                entry["model"] = model
                if variant:
                    entry["variant"] = variant
                else:
                    entry.pop("variant", None)
    if json.dumps(cfg, sort_keys=False) != before:
        _dump(jp, cfg)
        changed.append(jp)
    # V2 keeps the model of the five main agents (and reporter) in the agent file's frontmatter
    for role, names in AGENTS.items():
        for name in names:
            p = os.path.join(d, "agents", name + ".md")
            if not os.path.exists(p):
                continue
            text = _read(p)
            m = re.match(r"(?s)^(---\n)(.*?)(\n---\n)(.*)$", text)
            if not m or not re.search(r"(?m)^model:", m.group(2)):
                continue  # V1 agent file: its model lives in opencode.json
            head = re.sub(r"(?m)^model:.*$", f"model: {conf[role]}", m.group(2), count=1)
            if head != m.group(2):
                _write(p, m.group(1) + head + m.group(3) + m.group(4))
                changed.append(p)
    return changed


def family(value):
    return split(value)[0].split("/")[0]


def warnings(conf):
    out = []
    rv = family(conf["REVIEWER"])
    for role in ("DEVELOPER", "DEVELOPER_STRONG"):
        if family(conf[role]) == rv:
            out.append(f"REVIEWER and {role} are both '{rv}': the reviewer shares its blind spots with the author"
                       + (" (on T2 cards, the riskiest ones)" if role == "DEVELOPER_STRONG" else ""))
    return out


def cmd_show(conf):
    w = max(len(r) for r in ROLES)
    for r in ROLES:
        print(f"{r:<{w}}  {conf[r]:<42} {', '.join(AGENTS[r])}")
    for msg in warnings(conf):
        print("WARN  " + msg)


def cmd_check(conf):
    try:
        req = urllib.request.Request("https://models.dev/api.json", headers={"User-Agent": "opencode-team-models/1.0"})
        with urllib.request.urlopen(req, timeout=30) as r:  # models.dev answers 403 to the default Python agent
            cat = json.load(r)
    except Exception as e:  # offline, DNS, TLS: not a config error
        print(f"could not download the models.dev catalog ({e}); nothing checked")
        return 2
    bad = 0
    for value in dict.fromkeys(split(v)[0] for v in conf.values()):
        prov, _, model = value.partition("/")
        models = cat.get(prov, {}).get("models", {})
        if model in models:
            print(f"  OK    {value}")
        else:
            bad = 1
            stem = "-".join(model.split("-")[:2])
            near = [k for k in models if stem in k][-5:]
            print(f"  FAIL  {value} not found" + (f". Close: {', '.join(near)}" if near else f". Provider '{prov}' unknown or has no such model"))
    return bad


def cmd_verify(conf, path):
    """Every team agent must resolve to the model and variant that models.conf says (OpenCode 2.x dump)."""
    agents = json.loads(_read(path))
    if not agents:
        print("no agents in the dump. A cold OpenCode 2.x service answers `debug agents` with [] for about a second: run it again.")
        return 2
    by_id = {a["id"]: a for a in agents}
    bad = 0
    for role, names in AGENTS.items():
        want, variant = split(conf[role])
        for name in names:
            m = (by_id.get(name) or {}).get("model") or {}
            got = f"{m.get('providerID')}/{m.get('id')}"
            ok = name in by_id and got == want and (m.get("variant") or "") == variant
            bad += not ok
            shown = got + (f"#{m['variant']}" if m.get("variant") else "")
            print(f"  {'OK  ' if ok else 'FAIL'}  agent {name} -> {shown}" + ("" if ok else f"   (models.conf says {conf[role]})"))
    for name in ("build", "plan"):
        if name in by_id:
            print(f"  INFO  built-in agent {name} is still listed (the config disables it; check it is hidden in the TUI)")
    return 1 if bad else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["show", "set", "apply", "check", "verify"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--dir", default=os.path.expanduser("~/.config/opencode"))
    ap.add_argument("--conf")
    ap.add_argument("--quiet", action="store_true", help="apply: print nothing but errors")
    a = ap.parse_args(argv)
    conf_path = a.conf or default_conf()
    if a.cmd == "set":
        if len(a.args) != 2:
            ap.error("usage: models.py set ROLE provider/model[#variant]   (ROLE: " + ", ".join(r.lower().replace("_", "-") for r in ROLES) + ")")
        role = norm_role(a.args[0])
        if role not in ROLES:
            ap.error(f"unknown role '{a.args[0]}'")
        if not VALUE.match(a.args[1]):
            ap.error(f"'{a.args[1]}' is not provider/model or provider/model#variant")
        write_conf_value(conf_path, role, a.args[1])
    try:
        conf = load_conf(conf_path)
    except ValueError as e:
        sys.exit(f"ERROR {e}")
    if a.cmd == "show":
        cmd_show(conf)
        return 0
    if a.cmd == "check":
        return cmd_check(conf)
    if a.cmd == "verify":
        if len(a.args) != 1:
            ap.error("usage: models.py verify FILE   (FILE = output of: opencode debug agents)")
        return cmd_verify(conf, a.args[0])
    changed = apply_dir(os.path.expanduser(a.dir), conf)
    if not a.quiet:
        print(f"models from {conf_path}: " + (f"{len(changed)} file(s) updated in {a.dir}" if changed else f"already applied in {a.dir}"))
        for msg in warnings(conf):
            print("WARN  " + msg)
    return 0


if __name__ == "__main__":
    sys.exit(main())
