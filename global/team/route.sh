#!/usr/bin/env bash
# route.sh - what should /team do now? Facts and a route, computed by a script (zero model tokens).
#   route.sh [what the user typed after /team ...]
# Run inside the project. With no argument (what /team does: typed text never goes into a shell line, because OpenCode 2.x
# pastes it in raw and a quote or a backtick would break or run it) it prints the state and the ROUTE for "continue".
# With an argument it also classifies what was typed (used by tests and other hosts). Output: a STATE block and one ROUTE line:
#   STOP | INIT | RESUME | NEXT-CARD | EPIC | CARD | WORK | KICKOFF | REVIEW | BLOCKED | DONE | REPLY
# ROUTE is a fact derived from the files, never a guess about the text: free text is always WORK
# (or KICKOFF when nothing is planned yet), and the tech lead decides the lane from there.
# Plain bash + git + awk: macOS and Linux. The typed text is data: it is printed, never executed.

set -u
ARGS="$*"
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
IS_GIT=1; [ -n "$ROOT" ] || { IS_GIT=0; ROOT="$(pwd)"; }
cd "$ROOT" || exit 0
TEAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }
first_word() { printf '%s' "$1" | awk '{print $1}'; }
rest_words() { printf '%s' "$1" | awk '{$1=""; sub(/^ /,""); print}'; }
count_files() { # dir [glob]  -> number of real files (not .gitkeep)
  [ -d "$1" ] || { echo 0; return; }
  find "$1" -type f ! -name '.gitkeep' ${2:+-name "$2"} 2>/dev/null | wc -l | tr -d ' '
}

INIT=0; [ -f PROGRESS.md ] && [ -f scripts/board.sh ] && INIT=1
CMDS=0
if [ -f .opencode/check.cmds ]; then CMDS="$(grep -cvE '^[[:space:]]*(#|$)' .opencode/check.cmds || true)"; fi
PRODUCT="$(count_files docs/product)"
EPICS_N="$(count_files .opencode/work/epics 'EPIC-*.md')"
CARDS_N="$(count_files .opencode/work/tasks '*.md')"
FILES=0; [ "$IS_GIT" = 1 ] && FILES="$(git ls-files 2>/dev/null | wc -l | tr -d ' ')"
BOARD=""; NEXT=""
if [ "$INIT" = 1 ]; then
  BOARD="$(bash scripts/board.sh 2>&1 | head -14)"
  NEXT="$(bash scripts/board.sh next 2>&1 | head -1)"
fi
# first epic that still has an unticked slice
OPEN_EPIC=""; OPEN_SLICES=0
for e in .opencode/work/epics/EPIC-*.md; do
  [ -f "$e" ] || continue
  n="$(grep -Ec '^- \[ \] ' "$e" || true)"
  if [ "${n:-0}" -gt 0 ]; then OPEN_EPIC="$e"; OPEN_SLICES="$n"; break; fi
done
BLOCKED_N=0; [ "$INIT" = 1 ] && BLOCKED_N="$(printf '%s\n' "$BOARD" | grep -c ' blocked ' || true)"

ROUTE=""; ARG=""; REPLY=""; AUTO=no
word="$(lower "$(first_word "$ARGS")")"
rest="$(rest_words "$ARGS")"

resume_route() { # nothing typed: continue where the board says
  case "$NEXT" in
    RESUME*) ROUTE=RESUME; ARG="$(printf '%s' "$NEXT" | awk '{print $3}')" ;;
    NEXT*)   ROUTE=NEXT-CARD; ARG="$(printf '%s' "$NEXT" | awk '{print $3}')" ;;
    "none ready"*) ROUTE=BLOCKED ;;
    *)
      if [ -n "$OPEN_EPIC" ]; then ROUTE=EPIC; ARG="$OPEN_EPIC"
      elif [ "$BLOCKED_N" -gt 0 ]; then ROUTE=BLOCKED
      elif [ "$EPICS_N" -gt 0 ]; then ROUTE=DONE
      elif [ "$PRODUCT" -gt 0 ]; then ROUTE=KICKOFF
      else ROUTE=REPLY; REPLY="Nothing is planned yet. Say what to build: /team <idea or task>"; fi ;;
  esac
}

if [ "$IS_GIT" = 0 ]; then
  ROUTE=STOP; REPLY="$ROOT is not a git repository. Run 'git init' here (or open the project folder), then run /team again."
else
  case "$ROOT" in "$HOME"|"/"|"$HOME/Desktop"|"$HOME/Documents"|"$HOME/Downloads")
    ROUTE=STOP; REPLY="Refusing to work in $ROOT. Open OpenCode inside a specific project folder." ;; esac
fi

if [ -z "$ROUTE" ]; then
  case "$word" in
    models|model)  # changing models needs no model at all
      if command -v python3 >/dev/null 2>&1 && [ -f "$TEAM_DIR/models.py" ]; then
        ROUTE=REPLY; REPLY="$(python3 "$TEAM_DIR/models.py" cmd $rest 2>&1)"
      else ROUTE=REPLY; REPLY="python3 (3.8+) is needed to change models: install it, then run /team model again."; fi ;;
    status|board)
      if [ "$INIT" = 1 ]; then
        ROUTE=REPLY
        REPLY="$BOARD
$(awk '/^## (Now|Open decisions)/{p=1} /^## Lessons/{p=0} p' PROGRESS.md 2>/dev/null | head -16)"
      else ROUTE=REPLY; REPLY="This project is not initialized yet. Run /team (it initializes the project)."; fi ;;
    init|setup)    ROUTE=INIT ;;
    review)        ROUTE=REVIEW; ARG="$rest" ;;
    all|auto|continue|go)
      AUTO=yes
      if [ "$INIT" = 1 ]; then resume_route; else ROUTE=INIT; fi ;;
  esac
fi

if [ -z "$ROUTE" ]; then
  if [ "$INIT" = 0 ]; then
    ROUTE=INIT                                   # first use in this project; the typed text (if any) follows after init
  elif [ -z "$ARGS" ]; then
    resume_route
  else
    # a path or an id the user typed
    if [ -f "$ARGS" ]; then
      case "$ARGS" in
        *.opencode/work/epics/*|.opencode/work/epics/*) ROUTE=EPIC; ARG="$ARGS" ;;
        *.opencode/work/tasks/*|.opencode/work/tasks/*) ROUTE=CARD; ARG="$ARGS" ;;
      esac
    elif printf '%s' "$ARGS" | grep -Eq '^EPIC-[0-9]+$'; then
      f="$(ls .opencode/work/epics/"$ARGS"*.md 2>/dev/null | head -1)"
      [ -n "$f" ] && { ROUTE=EPIC; ARG="$f"; }
    elif printf '%s' "$ARGS" | grep -Eq '^[0-9]{1,4}$'; then
      f="$(ls .opencode/work/tasks/"$(printf '%03d' "$((10#$ARGS))")"-*.md 2>/dev/null | head -1)"
      [ -n "$f" ] && { ROUTE=CARD; ARG="$f"; }
    fi
    if [ -z "$ROUTE" ]; then
      ROUTE=WORK; ARG="$ARGS"
      # nothing planned and no product docs: probably a new product (the tech lead confirms)
      if [ "$EPICS_N" = 0 ] && [ "$CARDS_N" = 0 ] && [ "$PRODUCT" = 0 ]; then ROUTE=KICKOFF; ARG="$ARGS"; fi
    fi
  fi
fi

echo "== /team state =="
echo "project: $ROOT"
if [ "$IS_GIT" = 1 ]; then
  echo "git: yes, branch $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-'), $(git rev-list --count HEAD 2>/dev/null || echo 0) commits, $(git status --porcelain 2>/dev/null | wc -l | tr -d ' ') uncommitted files, $FILES tracked files"
else
  echo "git: NO"
fi
echo "initialized: $([ "$INIT" = 1 ] && echo yes || echo no) (PROGRESS.md and scripts/board.sh)"
echo "gate: $CMDS command(s) in .opencode/check.cmds"
echo "product docs: $PRODUCT | epics: $EPICS_N | cards: $CARDS_N | epic with open slices: ${OPEN_EPIC:-none}$([ "${OPEN_SLICES:-0}" -gt 0 ] && echo " ($OPEN_SLICES open)")"
echo "planned: $([ "$EPICS_N" = 0 ] && [ "$CARDS_N" = 0 ] && [ "$PRODUCT" = 0 ] && echo no || echo yes)"
[ "$EPICS_N" -gt 0 ] && echo "epic files: $(ls .opencode/work/epics/EPIC-*.md 2>/dev/null | head -12 | tr '\n' ' ')"
[ "$CARDS_N" -gt 0 ] && echo "card files: $(ls .opencode/work/tasks/*.md 2>/dev/null | sed 's#.*/##; s#\.md$##' | head -40 | tr '\n' ' ')(in .opencode/work/tasks/)"
[ -n "$BOARD" ] && { echo "board:"; printf '%s\n' "$BOARD" | sed 's/^/  /'; echo "next: $NEXT"; }
echo "input: ${ARGS:-(none)}"
[ -z "$ARGS" ] && echo "note: the ROUTE below is what an EMPTY /team does; a typed request is classified by the rules that follow"
echo "auto: $AUTO"
echo "ROUTE: $ROUTE${ARG:+  $ARG}"
if [ -n "$REPLY" ]; then echo "REPLY-BEGIN"; printf '%s\n' "$REPLY"; echo "REPLY-END"; fi
exit 0
