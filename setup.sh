#!/usr/bin/env bash
# OpenCode team setup for macOS and Linux:  bash setup.sh   (macOS: double-click setup.sh)
#  1. installs or updates OpenCode with the official prebuilt installer (no Homebrew, no Xcode needed)
#     default: OpenCode 2.x.  For the stable 1.x line instead:  OPENCODE_MAJOR=1 bash setup.sh
#  2. backs up any existing OpenCode config, installs the team globally (config matches the installed major),
#     applies models.conf, and installs the third-party skills from their git repositories (skills.lock)
#  3. checks model IDs against models.dev
#  4. validates agents, models, permissions, skills, bootstrap, the check script, the task board and the loop-contract gate
# Needs: bash, curl, git, and perl or timeout. python3 (3.8+) adds the model and permission checks and models.py.
# Full log: setup.log next to this file.

KIT="$(cd "$(dirname "$0")" && pwd)"
LOG="$KIT/setup.log"
exec > >(tee "$LOG") 2>&1
export PATH="$HOME/.opencode/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$HOME/bin:$PATH"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
WANT="${OPENCODE_MAJOR:-2}"
WARN=0
ok()   { echo "  OK    $*"; }
warn() { echo "  WARN  $*"; WARN=1; }
hdr()  { echo; echo "== $*"; }
# SETUP_PAUSE=1 (set by setup.sh) keeps a double-clicked Terminal window open
finish() { echo; echo "$1"; echo; if [ "${SETUP_PAUSE:-0}" = 1 ]; then read -r -p "Press Enter to close" _ || true; fi; exit "${2:-0}"; }
# run a command with a time limit: GNU timeout (Linux), gtimeout (Homebrew coreutils), or perl (every Mac has it)
tlimit() {
  local s="$1"; shift
  if command -v timeout >/dev/null 2>&1; then timeout "$s" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$s" "$@"
  elif command -v perl >/dev/null 2>&1; then perl -e 'alarm shift; exec @ARGV' "$s" "$@"
  else "$@"; fi
}
# the file where new terminals get their PATH from
rcfile() {
  case "${SHELL:-}" in
    */zsh) echo "$HOME/.zshrc" ;;
    */bash) if [ "$(uname -s)" = Darwin ]; then echo "$HOME/.bash_profile"; else echo "$HOME/.bashrc"; fi ;;
    *) echo "$HOME/.profile" ;;
  esac
}
# a real python3 (not the macOS stub that opens the Xcode installer), 3.8 or newer
have_python() {
  command -v python3 >/dev/null 2>&1 || return 1
  # on a Mac without developer tools /usr/bin/python3 is a stub that opens the Xcode installer
  if [ "$(uname -s)" = Darwin ] && [ "$(command -v python3)" = "/usr/bin/python3" ] && ! xcode-select -p >/dev/null 2>&1; then return 1; fi
  python3 -c 'import sys; sys.exit(sys.version_info < (3, 8))' 2>/dev/null
}
major() { opencode --version 2>/dev/null | tail -1 | sed -E 's/^[^0-9]*([0-9]+).*/\1/'; }

echo "OpenCode team setup — $(date)"
if [ "$(uname -s)" = Darwin ]; then OSNAME="macOS $(sw_vers -productVersion 2>/dev/null)"
else OSNAME="$( . /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-Linux}" || echo Linux)"; fi
echo "$OSNAME on $(uname -m); target OpenCode major: $WANT"
for tool in curl git; do command -v "$tool" >/dev/null 2>&1 || { warn "$tool is required and was not found"; finish "SETUP RESULT: FAILED" 1; }; done

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
if ! grep -qs '\.opencode/bin' "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile"; then
  RC="$(rcfile)"
  printf '\n# opencode\nexport PATH="$HOME/.opencode/bin:$PATH"\n' >> "$RC" && ok "added ~/.opencode/bin to PATH in $RC"
fi

# 2) Team config ---------------------------------------------------------------------
TMPDIR_SK="$(mktemp)"
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
  # only a global AGENTS.md that is not the team's own (it starts with "# Team rules") is worth a warning
  [ -e "$CFG/AGENTS.md" ] && ! head -1 "$CFG/AGENTS.md" | grep -q '^# Team rules' && warn "your own global AGENTS.md was replaced by the team rules; your version is in $BK/AGENTS.md (merge any lines you still want)"
fi
mkdir -p "$CFG/agents" "$CFG/commands"
# models.conf in the kit holds the default model of each role. Choices made with /model or models.py set live in
# team/models.local.conf, which this script never touches, so they survive an update.
apply_models() {
  cp "$KIT/models.conf" "$CFG/team/models.conf"
  if have_python; then
    python3 "$CFG/team/models.py" apply --dir "$CFG" --quiet 2>&1 | sed 's/^/  /'
  elif [ -f "$CFG/team/models.local.conf" ] || ! git -C "$KIT" diff --quiet -- models.conf 2>/dev/null; then
    warn "models.conf (or models.local.conf) was changed but python3 is missing, so it was not applied (the default models are installed). Install python3 and run this again."
  fi
}
install_v1() { cp -R "$KIT/global/." "$CFG/"; apply_models; }
install_v2() { cp -R "$KIT/global/." "$CFG/"; cp -R "$KIT/global-v2/." "$CFG/"; apply_models; }
if [ "$MAJ" = "2" ]; then
  install_v2 && ok "installed team config in V2 format (agents, permissions list, commands) plus skills and AGENTS.md"
  CFGKIND=v2
else
  install_v1 && ok "installed team config in V1 format plus skills and AGENTS.md"
  CFGKIND=v1
fi
# a running OpenCode 2.x service keeps the old agent files in memory until it is told to reload
[ "$MAJ" = "2" ] && tlimit 30 opencode reload >/dev/null 2>&1
if [ -f "$CFG/team/models.local.conf" ]; then echo "  INFO  keeping your model choices from $CFG/team/models.local.conf (/model reset removes them)"; fi
if have_python; then
  ok "models: $(python3 "$CFG/team/models.py" show | awk '/^(LEAD|TECH_LEAD|REVIEWER|DEVELOPER|DEVELOPER_STRONG|BACKGROUND) /{printf "%s=%s ", tolower($1), $2}')"
  python3 "$CFG/team/models.py" show | sed -n 's/^WARN  /  INFO  /p'
fi
chmod +x "$CFG/team/bootstrap.sh" "$CFG/team/fetch-skills.sh" "$CFG/team/project-template/scripts/check.sh" "$CFG/team/project-template/scripts/board.sh" "$CFG/team/models.py"
# third-party skills (skills.lock) come straight from their git repositories, pinned and patched for OpenCode
bash "$CFG/team/fetch-skills.sh" --dest "$CFG/skills" 2>&1 | tee "$TMPDIR_SK"
grep -qE '^  (FAIL|WARN)' "$TMPDIR_SK" && WARN=1

# 3) Model IDs -----------------------------------------------------------------------
hdr "3. Model IDs"
if have_python; then
  python3 "$CFG/team/models.py" check > "$TMPDIR_SK" 2>&1; rc=$?
  cat "$TMPDIR_SK"
  [ "$rc" = 1 ] && WARN=1
else
  echo "  INFO  model IDs not checked (needs python3)"
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
  # a cold 2.x service first answers with an empty list, then with the built-in agents only, until its catalog and
  # the team config have loaded: retry until the team's own agent shows up
  for _try in 1 2 3 4 5 6 7 8; do
    tlimit 30 opencode debug agents > "$TMP/agents.out" 2>&1 && grep -q '"id": "tech-lead"' "$TMP/agents.out" && break
    sleep 3
  done
  if grep -q '"id"' "$TMP/agents.out"; then
    if have_python; then
      python3 "$CFG/team/models.py" verify "$TMP/agents.out" > "$TMP/verify.out" 2>&1
      cat "$TMP/verify.out"
      grep -q FAIL "$TMP/verify.out" && WARN=1
    else
      for a in lead tech-lead developer developer-strong reviewer explore reporter; do
        grep -q "\"id\": \"$a\"" "$TMP/agents.out" && echo "  OK    agent $a is registered" || { warn "agent $a is not in 'opencode debug agents'"; WARN=1; }
      done
    fi
  else
    echo "  INFO  'opencode debug agents' failed; agents will be checked on first run"
  fi
  if have_python && [ -f "$KIT/tests/perm_check.py" ] && [ -s "$TMP/agents.out" ]; then
    python3 "$KIT/tests/perm_check.py" "$TMP/agents.out" > "$TMP/perm.out" 2>&1
    sed 's/^/  /' "$TMP/perm.out" | head -25
    grep -q FAIL "$TMP/perm.out" && WARN=1
  else
    echo "  INFO  permission spot checks skipped (need python3 and the kit's tests/ folder)"
  fi
  echo "  -- V2 diagnostics (for troubleshooting, read by Claude from setup.log) --"
  grep -E '"(id|providerID|variant)"' "$TMP/agents.out" | head -40 | sed 's/^/     /'
  ( tlimit 30 opencode debug config 2>&1 | grep -E '"(type|path)"' | head -10 ) | sed 's/^/     /'
else
  tlimit 30 opencode debug config >/dev/null 2>&1 && echo "  OK    config resolves" || warn "config does not resolve (run: opencode debug config)"
  mkdir -p "$TMP/agents1"
  for a in lead tech-lead developer developer-strong reviewer explore reporter; do
    if tlimit 30 opencode debug agent "$a" > "$TMP/agents1/$a.json" 2>&1; then
      m="$(grep -o '"modelID": *"[^"]*"' "$TMP/agents1/$a.json" | head -1 | cut -d'"' -f4)"
      v="$(grep -o '"variant": *"[^"]*"' "$TMP/agents1/$a.json" | head -1 | cut -d'"' -f4)"
      echo "  OK    agent $a -> ${m:-default}${v:+ (variant $v)}"
    else
      warn "agent $a does not resolve (run: opencode debug agent $a)"
    fi
  done
  if have_python && [ -f "$KIT/tests/perm_check.py" ]; then
    python3 "$KIT/tests/perm_check.py" --v1 "$TMP/agents1" > "$TMP/perm.out" 2>&1
    sed 's/^/  /' "$TMP/perm.out" | head -25
    grep -q FAIL "$TMP/perm.out" && WARN=1
  else
    echo "  INFO  permission spot checks skipped (need python3 and the kit's tests/ folder)"
  fi
  tlimit 30 opencode debug skill > "$TMP/skills.json" 2>/dev/null   # to a file: a pipe truncates long output at 64 KB
  n="$(grep -oE '"name": *"(product-brief|domain-modeling|architecture-decision|epic-planning|task-card|acceptance-tests|tdd-cycle|clean-code|design-principles|code-review|debug-rootcause|escalation-brief|refactor-safely|loop-contract)"' "$TMP/skills.json" | sort -u | wc -l | tr -d ' ')"
  [ "$n" = "14" ] && echo "  OK    skills: 14 of 14" || warn "skills: $n of 14"
fi
# the project-side pieces do not depend on the OpenCode version
(
  cd "$TMP" && git init -q && echo '{"name":"smoke","scripts":{"test":"echo 1 passed"}}' > package.json
  "$CFG/team/bootstrap.sh" | tail -1 | sed 's/^/  /'
  echo true > .opencode/check.cmds
  scripts/check.sh >/dev/null 2>&1 && echo "  OK    check.sh runs" || warn "check.sh failed on the smoke project"
  scripts/board.sh verify >/dev/null 2>&1 && [ "$(scripts/board.sh next-id)" = "001" ] && echo "  OK    board.sh runs" || warn "board.sh failed on the smoke project"
  GATE="$CFG/skills/loop-contract/scripts/fold_ledger.py"
  if ! have_python; then warn "python3 (3.8+) is missing or only the macOS stub: the loop-contract gate (large batch jobs only) will not run; normal cards are unaffected"
  elif tlimit 20 python3 "$GATE" --help >/dev/null 2>&1; then echo "  OK    loop-contract gate runs (python3 $(python3 -c 'import sys;print("%d.%d"%sys.version_info[:2])' 2>/dev/null))"
  else warn "the loop-contract gate failed to run (python3 $GATE --help); batch jobs will fall back to the card lane"; fi
) > "$TMP/project.out" 2>&1
cat "$TMP/project.out"
grep -q WARN "$TMP/project.out" && WARN=1
for s in product-brief domain-modeling architecture-decision epic-planning task-card acceptance-tests tdd-cycle clean-code design-principles code-review debug-rootcause escalation-brief refactor-safely loop-contract; do
  [ -f "$CFG/skills/$s/SKILL.md" ] || { warn "skill file missing: $s"; }
done
ok "skill files present in $CFG/skills"
rm -rf "$TMP" "$TMPDIR_SK"

# 5) Providers -----------------------------------------------------------------------
hdr "5. Providers (connect Anthropic and Google with /connect inside opencode)"
tlimit 20 opencode auth list 2>/dev/null | sed 's/^/  /' | head -15 || true

echo
echo "Models: edit $KIT/models.conf and run this script again, or change one role at once:"
echo "  python3 ~/.config/opencode/team/models.py set developer google/gemini-3.8-flash#high   (show | check also work)"
echo "Last step (yours): open a NEW terminal tab, cd into a project folder (a git repo), run  opencode , type  /connect  for Anthropic and Google, then  /team-init ."
if [ "$WARN" -eq 0 ]; then finish "SETUP RESULT: OK"; else finish "SETUP RESULT: DONE WITH WARNINGS (see WARN lines above)"; fi
