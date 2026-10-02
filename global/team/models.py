#!/usr/bin/env python3
"""Choose the models of the OpenCode team (six roles). Standard library only; Linux and macOS.

  models.py                          interactive picker (a terminal), otherwise `show`
  models.py show                     roles, models, which ones you changed, warnings
  models.py set ROLE provider/model[#variant]    change one role (kept in models.local.conf), then apply
  models.py preset NAME              apply a preset (claude-only, budget, ...); `preset` alone lists them
  models.py reset [ROLE]             forget your changes for one role, or for all roles
  models.py apply                    write the current choice into the OpenCode config
  models.py check                    verify every model ID against models.dev
  models.py verify FILE              compare what OpenCode 2.x resolved (opencode debug agents > FILE) with the choice
  models.py cmd [WORDS...]           what the /model command runs (same as the commands above, short output)

Defaults live in models.conf; your changes in models.local.conf next to it, which setup.sh never overwrites.
--dir  OpenCode config folder (default ${XDG_CONFIG_HOME:-~/.config}/opencode; V1 and V2 formats are detected)
--conf models.conf to use (default: next to this script, else the kit's models.conf)
"""
import argparse, json, os, re, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
LOCAL_NAME = "models.local.conf"
HEADER = "# Your model choices (written by /model and models.py). They override models.conf. Delete a line to go back to the default.\n"
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


def config_dir():
    return os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "opencode")


def local_path(conf_path):
    return os.path.join(os.path.dirname(os.path.abspath(conf_path)), LOCAL_NAME)


def parse_conf(path):
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
    return conf


def load_conf(path, local=True):
    """models.conf (all six roles) with the roles from models.local.conf laid over it."""
    conf = parse_conf(path)
    missing = [r for r in ROLES if r not in conf]
    if missing:
        raise ValueError(f"{path}: missing {', '.join(missing)}")
    lp = local_path(path)
    if local and os.path.exists(lp):
        conf.update(parse_conf(lp))
    return conf


def local_roles(conf_path):
    lp = local_path(conf_path)
    return parse_conf(lp) if os.path.exists(lp) else {}


def write_local(conf_path, roles):
    """Replace models.local.conf with these roles (an empty dict deletes the file)."""
    lp = local_path(conf_path)
    if not roles:
        if os.path.exists(lp):
            os.remove(lp)
        return
    _write(lp, HEADER + "".join(f"{r}={roles[r]}\n" for r in ROLES if r in roles))


def agent_value(conf, agent):
    return conf[role_of(agent)]


def split(value):
    model, _, variant = value.partition("#")
    return model, variant


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
    # commands that name a model (the /model command) run on the cheap background model
    cdir = os.path.join(d, "commands")
    for fname in sorted(os.listdir(cdir)) if os.path.isdir(cdir) else []:
        p = os.path.join(cdir, fname)
        m = re.match(r"(?s)^(---\n)(.*?)(\n---\n)(.*)$", _read(p)) if fname.endswith(".md") else None
        if not m or not re.search(r"(?m)^model:", m.group(2)):
            continue
        value = conf["BACKGROUND"] if v2 else split(conf["BACKGROUND"])[0]
        head = re.sub(r"(?m)^model:.*$", f"model: {value}", m.group(2), count=1)
        if head != m.group(2):
            _write(p, m.group(1) + head + m.group(3) + m.group(4))
            changed.append(p)
    return changed


def reload_opencode():
    """OpenCode 2.x keeps agent files in memory: `opencode reload` makes it read them again. Never runs on 1.x
    (there `opencode reload` would open the TUI). Returns True when it reloaded. OPENCODE_TEAM_NO_RELOAD=1 turns it off."""
    import shutil, subprocess
    if os.environ.get("OPENCODE_TEAM_NO_RELOAD"):
        return False
    exe = shutil.which("opencode") or os.path.expanduser("~/.opencode/bin/opencode")
    if not os.path.exists(exe):
        return False
    try:
        ver = subprocess.run([exe, "--version"], capture_output=True, text=True, timeout=20, stdin=subprocess.DEVNULL).stdout
        if not re.search(r"(^|\s)v?2\.\d+", ver.strip().splitlines()[-1] if ver.strip() else ""):
            return False
        return subprocess.run([exe, "reload"], capture_output=True, timeout=30, stdin=subprocess.DEVNULL).returncode == 0
    except Exception:
        return False


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


def opencode_models():
    """Model IDs OpenCode itself lists (`opencode models`): covers models that plugins add and models.dev does not know."""
    import shutil, subprocess
    exe = shutil.which("opencode") or os.path.expanduser("~/.opencode/bin/opencode")
    if not os.path.exists(exe):
        return set()
    try:
        out = subprocess.run([exe, "models"], capture_output=True, text=True, timeout=90, stdin=subprocess.DEVNULL).stdout
    except Exception:
        return set()
    return {l.strip() for l in out.splitlines() if re.match(r"^[A-Za-z0-9_.-]+/\S+$", l.strip())}


def cmd_check(conf):
    cat = fetch_catalog()
    if cat is None:
        print("could not download the models.dev catalog; nothing checked")
        return 2
    bad = 0
    cache = {}
    listed_models = lambda: cache.setdefault("m", opencode_models())
    for value in dict.fromkeys(split(v)[0] for v in conf.values()):
        prov, _, model = value.partition("/")
        models = cat.get(prov, {}).get("models", {})
        if model in models:
            print(f"  OK    {value}")
        elif value in (listed := listed_models()):
            print(f"  OK    {value}  (listed by OpenCode, not on models.dev: a plugin or custom provider)")
        else:
            bad = 1
            stem = "-".join(model.split("-")[:2])
            near = [k for k in models if stem in k][-5:]
            print(f"  FAIL  {value} not found" + (f". Close: {', '.join(near)}" if near else f". Provider '{prov}' unknown or has no such model"))
    return bad


def presets_dir():
    for p in (os.path.join(HERE, "presets"),):
        if os.path.isdir(p):
            return p
    return os.path.join(HERE, "presets")


def list_presets():
    d = presets_dir()
    return sorted(f[:-5] for f in os.listdir(d) if f.endswith(".conf")) if os.path.isdir(d) else []


def load_preset(name):
    path = os.path.join(presets_dir(), name + ".conf")
    if name not in list_presets():
        raise ValueError(f"unknown preset '{name}' (available: {', '.join(list_presets()) or 'none'})")
    return parse_conf(path)


def fetch_catalog():
    try:
        req = urllib.request.Request("https://models.dev/api.json", headers={"User-Agent": "opencode-team-models/1.0"})
        with urllib.request.urlopen(req, timeout=20) as r:  # models.dev answers 403 to the default Python agent
            return json.load(r)
    except Exception:
        return None


def show_lines(conf_path, conf):
    local = local_roles(conf_path)
    w = max(len(r) for r in ROLES)
    lines = [f"{r:<{w}}  {conf[r]:<44}{'*' if r in local else ' '} {', '.join(AGENTS[r])}" for r in ROLES]
    if local:
        lines.append("* = your choice (models.local.conf); `reset` goes back to the default")
    lines += ["WARN  " + m for m in warnings(conf)]
    return lines


def do_set(conf_path, role, value):
    local = local_roles(conf_path)
    local[role] = value
    write_local(conf_path, local)


def cmd_pick(conf_path, d):
    """Interactive: choose a role, then a model (type provider/model, or part of a name to search models.dev)."""
    conf = load_conf(conf_path)
    print("\n".join(show_lines(conf_path, conf)))
    names = [r.lower().replace("_", "-") for r in ROLES]
    for i, n in enumerate(names, 1):
        print(f"  {i}) {n}")
    pick = input("role number (empty = quit): ").strip()
    if not pick:
        return 0
    if not (pick.isdigit() and 1 <= int(pick) <= len(ROLES)):
        print("not a role number"); return 1
    role = ROLES[int(pick) - 1]
    catalog = None
    while True:
        text = input(f"{names[int(pick) - 1]} model (provider/model[#variant], or words to search; empty = cancel): ").strip()
        if not text:
            return 0
        if VALUE.match(text):
            break
        if catalog is None:
            print("loading models.dev ...")
            catalog = fetch_catalog() or {}
        words = text.lower().split()
        hits = [f"{p}/{m}" for p, v in catalog.items() if isinstance(v, dict) for m in v.get("models", {})
                if all(w in f"{p}/{m}".lower() for w in words)][:15]
        if not hits:
            print("no match" if catalog else "models.dev is not reachable; type the full provider/model"); continue
        for i, h in enumerate(hits, 1):
            print(f"  {i}) {h}")
        c = input("number (empty = search again): ").strip()
        if c.isdigit() and 1 <= int(c) <= len(hits):
            text = hits[int(c) - 1]
            variant = input("reasoning variant (e.g. high; empty = none): ").strip()
            if variant:
                text += "#" + variant
            break
    do_set(conf_path, role, text)
    apply_dir(d, load_conf(conf_path))
    print(f"{role} = {text}  (applied{', OpenCode reloaded' if reload_opencode() else ', restart opencode'})")
    return 0


def cmd_cmd(conf_path, d, words):
    """The /model command: short output, for a chat window."""
    # OpenCode may pass everything the user typed as ONE argument ("developer openai/x"): split it again
    words = [w for w in " ".join(words).split() if w not in ("$1", "$2", "$ARGUMENTS")]
    if not words:
        print("\n".join(show_lines(conf_path, load_conf(conf_path))))
        print("Change: /model <role> <provider/model[#variant]>   e.g. /model developer openai/gpt-5.4-nano")
        print("        /model <preset>   presets: " + ", ".join(list_presets()))
        print("        /model reset [role]   roles: " + ", ".join(r.lower().replace("_", "-") for r in ROLES))
        print("This session only: use the built-in /models.")
        return 0
    head = words[0].lower()
    try:
        if head == "reset":
            local = local_roles(conf_path)
            if len(words) > 1:
                local.pop(norm_role(words[1]), None)
            else:
                local = {}
            write_local(conf_path, local)
        elif head in list_presets() and len(words) == 1:
            write_local(conf_path, load_preset(head))
        elif len(words) == 2:
            role = norm_role(words[0])
            if role not in ROLES:
                raise ValueError(f"'{words[0]}' is not a role or preset (roles: {', '.join(r.lower().replace('_', '-') for r in ROLES)}; presets: {', '.join(list_presets())})")
            if not VALUE.match(words[1]):
                raise ValueError(f"'{words[1]}' is not provider/model or provider/model#variant")
            do_set(conf_path, role, words[1])
        else:
            raise ValueError("usage: /model <role> <provider/model[#variant]> | /model <preset> | /model reset [role]")
    except ValueError as e:
        print(f"Not changed: {e}")
        return 1
    conf = load_conf(conf_path)
    apply_dir(d, conf)
    reloaded = reload_opencode()
    print("\n".join(show_lines(conf_path, conf)))
    print("Applied and reloaded: it is active now." if reloaded else "Applied. Restart opencode to use it (OpenCode 1.x does not reload).")
    return 0


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
    ap.add_argument("cmd", nargs="?", choices=["show", "set", "preset", "reset", "apply", "check", "verify", "cmd", "pick"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--dir", default=config_dir())
    ap.add_argument("--conf")
    ap.add_argument("--quiet", action="store_true", help="apply: print nothing but errors")
    a = ap.parse_args(argv)
    conf_path = a.conf or default_conf()
    d = os.path.expanduser(a.dir)
    cmd = a.cmd or ("pick" if sys.stdin.isatty() and sys.stdout.isatty() else "show")
    try:
        if cmd == "cmd":
            return cmd_cmd(conf_path, d, a.args)
        if cmd == "pick":
            return cmd_pick(conf_path, d)
        if cmd == "set":
            if len(a.args) != 2:
                ap.error("usage: models.py set ROLE provider/model[#variant]   (ROLE: " + ", ".join(r.lower().replace("_", "-") for r in ROLES) + ")")
            role = norm_role(a.args[0])
            if role not in ROLES:
                ap.error(f"unknown role '{a.args[0]}'")
            if not VALUE.match(a.args[1]):
                ap.error(f"'{a.args[1]}' is not provider/model or provider/model#variant")
            do_set(conf_path, role, a.args[1])
        elif cmd == "preset":
            if not a.args:
                print("presets: " + ", ".join(list_presets()))
                return 0
            write_local(conf_path, load_preset(a.args[0]))
        elif cmd == "reset":
            local = local_roles(conf_path)
            if a.args:
                local.pop(norm_role(a.args[0]), None)
            else:
                local = {}
            write_local(conf_path, local)
        conf = load_conf(conf_path)
    except ValueError as e:
        sys.exit(f"ERROR {e}")
    if cmd == "show":
        print("\n".join(show_lines(conf_path, conf)))
        return 0
    if cmd == "check":
        return cmd_check(conf)
    if cmd == "verify":
        if len(a.args) != 1:
            ap.error("usage: models.py verify FILE   (FILE = output of: opencode debug agents)")
        return cmd_verify(conf, a.args[0])
    changed = apply_dir(d, conf)  # set, preset, reset, apply
    reloaded = reload_opencode() if changed else False
    if not a.quiet:
        print(f"models from {conf_path}: " + (f"{len(changed)} file(s) updated in {d}" + (" (OpenCode reloaded)" if reloaded else " (restart opencode to use them)") if changed else f"already applied in {d}"))
        for msg in warnings(conf):
            print("WARN  " + msg)
    return 0


if __name__ == "__main__":
    sys.exit(main())
