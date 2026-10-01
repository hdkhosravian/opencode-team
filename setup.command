#!/bin/bash
# OpenCode team setup for macOS. Double-click this file, or run:  bash ~/Tools/opencode-team/setup.command
#  1. installs or updates OpenCode with the official prebuilt installer (no Homebrew, no Xcode needed)
#     default: OpenCode 2.x.  For the stable 1.x line instead:  OPENCODE_MAJOR=1 bash setup.command
#  2. backs up any existing ~/.config/opencode, then installs the team globally (config matches the installed major)
#  3. checks model IDs against models.dev
#  4. validates agents, skills, bootstrap, the check script, the task board and the loop-contract gate
# Full log: setup.log next to this file.

KIT="$(cd "$(dirname "$0")" && pwd)"
LOG="$KIT/setup.log"
exec > >(tee "$LOG") 2>&1
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/bin:$PATH"
CFG="$HOME/.config/opencode"
WANT="${OPENCODE_MAJOR:-2}"
WARN=0
ok()   { echo "  OK    $*"; }
warn() { echo "  WARN  $*"; WARN=1; }
hdr()  { echo; echo "== $*"; }
finish() { echo; echo "$1"; echo; read -r -p "Press Enter to close" _ || true; exit "${2:-0}"; }
# run a command with a time limit (macOS has no `timeout`; perl is always there)
tlimit() { local s="$1"; shift; perl -e 'alarm shift; exec @ARGV' "$s" "$@"; }
major() { opencode --version 2>/dev/null | tail -1 | sed -E 's/^[^0-9]*([0-9]+).*/\1/'; }

echo "OpenCode team setup — $(date)"
echo "macOS $(sw_vers -productVersion 2>/dev/null) on $(uname -m); target OpenCode major: $WANT"

# 1) OpenCode ------------------------------------------------------------------------
hdr "1. OpenCode"
if command -v opencode >/dev/null 2>&1; then
  echo "  already installed: $(opencode --version 2>/dev/null | tail -1) ($(command -v opencode))"
fi
if [ "$WANT" = "2" ]; then
  echo "  running the official V2 installer (latest 2.x) ..."
  curl -fsSL https://opencode.ai/v2/install | bash || warn "V2 installer failed"
else
  echo "  running the official installer (latest stable 1.x) ..."
  curl -fsSL https://opencode.ai/install | bash || warn "V1 installer failed"
fi
hash -r
if [ "$WANT" = "2" ] && { ! command -v opencode >/dev/null 2>&1 || [ "$(major)" != "2" ]; }; then
  warn "OpenCode 2.x is not available right now; falling back to the stable 1.x installer"
  WANT=1
  curl -fsSL https://opencode.ai/install | bash || warn "V1 installer failed"
  hash -r
fi
if ! command -v opencode >/dev/null 2>&1; then
  warn "opencode not found on PATH after install"
  finish "SETUP RESULT: FAILED" 1
fi
CUR="$(opencode --version 2>/dev/null | tail -1)"
MAJ="$(major)"
ok "opencode $CUR at $(command -v opencode)"
# another copy earlier in PATH would hide the one we just installed
if [ "$(type -ap opencode | awk '!s[$0]++' | wc -l | tr -d ' ')" -gt 1 ]; then
  warn "more than one opencode on PATH (first one wins):"; type -ap opencode | awk '!s[$0]++' | sed 's/^/        /'
fi
# make sure new terminals find it (the installer normally does this already)
if ! grep -qs '\.opencode/bin' "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile"; then
  printf '\n# opencode\nexport PATH="$HOME/.opencode/bin:$PATH"\n' >> "$HOME/.zshrc" && ok "added ~/.opencode/bin to PATH in ~/.zshrc"
fi

# 2) Team config ---------------------------------------------------------------------
hdr "2. Team config -> $CFG"
if [ -e "$CFG" ]; then
  BK="$CFG.backup-$(date +%Y%m%d-%H%M%S)"
  cp -RL "$CFG" "$BK" && ok "backed up existing config to $BK"
  for k in provider mcp plugin keybinds; do
    if grep -q "\"$k" "$BK/opencode.json" "$BK/opencode.jsonc" 2>/dev/null; then
      warn "your old config had a \"$k\" section; copy it back from $BK into $CFG/opencode.json"
    fi
  done
  [ -e "$CFG/opencode.jsonc" ] && warn "you have $CFG/opencode.jsonc; OpenCode reads it together with the team's opencode.json, so check there are no conflicting settings"
  [ -e "$CFG/AGENTS.md" ] && warn "your own global AGENTS.md was replaced by the team rules; your version is in $BK/AGENTS.md (merge any lines you still want)"
fi
mkdir -p "$CFG/agents" "$CFG/commands"
install_v1() { cp -R "$KIT/global/." "$CFG/"; }
install_v2() { install_v1; cp -R "$KIT/global-v2/." "$CFG/"; }
if [ "$MAJ" = "2" ]; then
  install_v2 && ok "installed team config in V2 format (agents, permissions list, commands) plus skills and AGENTS.md"
  CFGKIND=v2
else
  install_v1 && ok "installed team config in V1 format plus skills and AGENTS.md"
  CFGKIND=v1
fi
chmod +x "$CFG/team/bootstrap.sh" "$CFG/team/project-template/scripts/check.sh"

# 3) Model IDs -----------------------------------------------------------------------
hdr "3. Model IDs"
MJ="${TMPDIR:-/tmp}/opencode-models-$$.json"
if curl -fsSL --max-time 30 https://models.dev/api.json -o "$MJ" 2>/dev/null; then
  MODELS_OUT="$(/usr/bin/osascript -l JavaScript - "$MJ" 2>&1 <<'JXA'
ObjC.import('Foundation');
function run(argv){
  var s=$.NSString.stringWithContentsOfFileEncodingError(argv[0],$.NSUTF8StringEncoding,null);
  var d=JSON.parse(ObjC.unwrap(s));
  var want=[["anthropic","claude-opus-5-5"],["anthropic","claude-sonnet-5-5"],["google","gemini-3.8-flash"]];
  var out=[];
  want.forEach(function(w){
    var p=d[w[0]], ok=p&&p.models&&p.models[w[1]];
    if(ok){ out.push("  OK    "+w[0]+"/"+w[1]); }
    else{
      var keys=p&&p.models?Object.keys(p.models):[];
      var stem=w[1].replace(/[-.]\d+(\.\d+)?$/,"").split("-").slice(0,2).join("-");
      var near=keys.filter(function(k){return k.indexOf(stem)>=0;}).slice(-6);
      out.push("  WARN  "+w[0]+"/"+w[1]+" not found. Candidates: "+near.join(", "));
    }
  });
  return out.join("\n");
}
JXA
)" || MODELS_OUT="  WARN  model ID check could not run: $MODELS_OUT"
  echo "$MODELS_OUT"
  case "$MODELS_OUT" in *WARN*) WARN=1 ;; esac
  rm -f "$MJ"
else
  warn "could not download the models.dev catalog; model IDs not checked"
fi

# 4) Validation ----------------------------------------------------------------------
hdr "4. Validation (opencode $CUR, $CFGKIND config)"
TMP="$(mktemp -d)"
if [ "$MAJ" = "2" ]; then
  # V2: the debug commands are not documented yet, so probe what exists and log it.
  if tlimit 30 opencode debug config > "$TMP/config.out" 2>&1; then
    ok "config resolves (opencode debug config)"
  else
    echo "  ..    V2-format config did not validate; trying the V1-format config (V2 converts it in memory)"
    head -c 1500 "$TMP/config.out" | sed 's/^/        /'
    cp "$CFG/opencode.json" "$TMP/opencode.v2.json"
    install_v1
    if tlimit 30 opencode debug config > "$TMP/config1.out" 2>&1; then
      warn "V2-format config was rejected; using the V1-format config instead (details above). Tell Claude, it can fix the V2 file."
      cp "$TMP/opencode.v2.json" "$KIT/opencode.v2.rejected.json"
      CFGKIND=v1-in-v2
    else
      install_v2
      warn "could not confirm the config with 'opencode debug config' (command may not exist in this 2.x build); keeping the V2-format config. Check it on first run."
      head -c 1500 "$TMP/config1.out" | sed 's/^/        /'
    fi
  fi
  if tlimit 30 opencode debug agents > "$TMP/agents.out" 2>&1; then
    for a in lead tech-lead developer developer-strong reviewer explore; do
      grep -qE "(^|[^a-z-])$a([^a-z-]|$)" "$TMP/agents.out" && echo "  OK    agent $a is registered" || echo "  WARN  agent $a is not in 'opencode debug agents'"
    done
    for a in build plan; do
      grep -qE "(^|[^a-z-])$a([^a-z-]|$)" "$TMP/agents.out" && echo "  INFO  built-in agent $a still listed (the config disables it; check it is hidden in the TUI)"
    done
  else
    echo "  INFO  'opencode debug agents' failed; agents will be checked on first run"
  fi
  echo "  -- V2 diagnostics (for troubleshooting, read by Claude from setup.log) --"
  ( head -60 "$TMP/agents.out" ) | sed 's/^/     /'
  ( tlimit 30 opencode debug config 2>&1 | head -40 ) | sed 's/^/     /'
else
  tlimit 30 opencode debug config >/dev/null 2>&1 && echo "  OK    config resolves" || echo "  WARN  config does not resolve (run: opencode debug config)"
  for a in lead tech-lead developer developer-strong reviewer explore; do
    if tlimit 30 opencode debug agent "$a" > "$TMP/$a.json" 2>&1; then
      m="$(grep -o '"modelID": *"[^"]*"' "$TMP/$a.json" | head -1 | cut -d'"' -f4)"
      v="$(grep -o '"variant": *"[^"]*"' "$TMP/$a.json" | head -1 | cut -d'"' -f4)"
      echo "  OK    agent $a -> ${m:-default}${v:+ (variant $v)}"
    else
      echo "  WARN  agent $a does not resolve (run: opencode debug agent $a)"
    fi
  done
  tlimit 30 opencode debug skill > "$TMP/skills.json" 2>/dev/null   # to a file: a pipe truncates long output at 64 KB
  n="$(grep -oE '"name": *"(product-brief|domain-modeling|architecture-decision|epic-planning|task-card|acceptance-tests|tdd-cycle|clean-code|design-principles|code-review|debug-rootcause|escalation-brief|refactor-safely|loop-contract)"' "$TMP/skills.json" | sort -u | wc -l | tr -d ' ')"
  [ "$n" = "14" ] && echo "  OK    skills: 14 of 14" || echo "  WARN  skills: $n of 14"
fi
# the project-side pieces do not depend on the OpenCode version
(
  cd "$TMP" && git init -q && echo '{"name":"smoke","scripts":{"test":"echo 1 passed"}}' > package.json
  "$CFG/team/bootstrap.sh" | tail -1 | sed 's/^/  /'
  echo true > .opencode/check.cmds
  scripts/check.sh >/dev/null 2>&1 && echo "  OK    check.sh runs" || echo "  WARN  check.sh failed on the smoke project"
  scripts/board.sh verify >/dev/null 2>&1 && [ "$(scripts/board.sh next-id)" = "001" ] && echo "  OK    board.sh runs" || echo "  WARN  board.sh failed on the smoke project"
  GATE="$CFG/skills/loop-contract/scripts/fold_ledger.py"
  if [ "$(command -v python3)" = "/usr/bin/python3" ] && ! xcode-select -p >/dev/null 2>&1; then echo "  WARN  python3 is only the macOS stub (no developer tools installed): the loop-contract gate (large batch jobs only) will not run; normal cards are unaffected"
  elif command -v python3 >/dev/null 2>&1 && tlimit 20 python3 "$GATE" --help >/dev/null 2>&1; then echo "  OK    loop-contract gate runs (python3 $(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null))"
  else echo "  WARN  python3 missing or too old: the loop-contract gate (large batch jobs only) will not run; normal cards are unaffected"; fi
) > "$TMP/project.out" 2>&1
cat "$TMP/project.out"
grep -q WARN "$TMP/project.out" && WARN=1
for s in product-brief domain-modeling architecture-decision epic-planning task-card acceptance-tests tdd-cycle clean-code design-principles code-review debug-rootcause escalation-brief refactor-safely loop-contract; do
  [ -f "$CFG/skills/$s/SKILL.md" ] || { warn "skill file missing: $s"; }
done
ok "skill files present in $CFG/skills"
rm -rf "$TMP"

# 5) Providers -----------------------------------------------------------------------
hdr "5. Providers (connect Anthropic and Google with /connect inside opencode)"
tlimit 20 opencode auth list 2>/dev/null | sed 's/^/  /' | head -15 || true

echo
echo "Last step (yours): open a NEW terminal tab, cd into a project folder (a git repo), run  opencode , type  /connect  for Anthropic and Google, then  /team-init ."
if [ "$WARN" -eq 0 ]; then finish "SETUP RESULT: OK"; else finish "SETUP RESULT: DONE WITH WARNINGS (see WARN lines above)"; fi
