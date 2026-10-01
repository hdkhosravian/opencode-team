#!/usr/bin/env bash
# Tests for global/team/route.sh (the router behind /team). Run from anywhere: bash tests/route/run.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEAM="$HERE/../../global/team"
FIXTURE="$HERE/../board/fixture"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
fail=0
n=0
# route <dir> <args...>  -> prints the route.sh output
route() { local d="$1"; shift; ( cd "$d" && bash "$TEAM/route.sh" "$@" ); }
check() { # name dir expect-regex args...
  local name="$1" d="$2" want="$3"; shift 3
  n=$((n+1)); out="$(route "$d" "$@")"
  if printf '%s\n' "$out" | grep -Eq "$want"; then echo "  ok   $name"; else echo "  FAIL $name"; printf '%s\n' "$out" | sed 's/^/        /'; fail=1; fi
}
mkproj() { # name -> a git repo initialized for the team
  local d="$TMP/$1"; mkdir -p "$d"; ( cd "$d" && git init -q && git commit -q --allow-empty -m init && bash "$TEAM/bootstrap.sh" >/dev/null ); echo "$d"
}

NOGIT="$TMP/nogit"; mkdir -p "$NOGIT"
check "not a git repository stops"             "$NOGIT" '^ROUTE: STOP' build a todo app

RAW="$TMP/raw"; mkdir -p "$RAW"; ( cd "$RAW" && git init -q && git commit -q --allow-empty -m init )
check "uninitialized project: init first"      "$RAW" '^ROUTE: INIT' 
check "uninitialized + a request: init first"  "$RAW" '^ROUTE: INIT' build a todo app
check "init keyword"                           "$RAW" '^ROUTE: INIT' init

P1="$(mkproj empty)"
check "initialized, nothing planned: tells you" "$P1" '^ROUTE: REPLY' 
check "...with a clear reply"                   "$P1" 'Nothing is planned yet'
check "new idea in an empty project: kickoff"   "$P1" '^ROUTE: KICKOFF  build a todo app' build a todo app
check "all/auto with nothing planned"           "$P1" 'auto: yes' all
check "status keyword is answered by the script" "$P1" 'REPLY-BEGIN' status
check "review keyword keeps the range"          "$P1" '^ROUTE: REVIEW  HEAD~1..HEAD' review HEAD~1..HEAD
check "models keyword is a script answer"       "$P1" '^ROUTE: REPLY' models

P2="$(mkproj product)"; echo "# brief" > "$P2/docs/product/brief.md"
check "product docs but no epics: kickoff"      "$P2" '^ROUTE: KICKOFF'

P3="$(mkproj epic)"; mkdir -p "$P3/.opencode/work/epics"
printf '# EPIC-01 orders\nSlices-frozen: 2\n- [ ] S1 a\n- [ ] S2 b\n' > "$P3/.opencode/work/epics/EPIC-01-orders.md"
check "epic with open slices, no cards: epic"   "$P3" '^ROUTE: EPIC  .opencode/work/epics/EPIC-01-orders.md'
check "free text with a plan present: work"     "$P3" '^ROUTE: WORK  fix the typo in the header' fix the typo in the header
check "EPIC-01 id"                              "$P3" '^ROUTE: EPIC  .opencode/work/epics/EPIC-01-orders.md' EPIC-01
check "epic path"                               "$P3" '^ROUTE: EPIC' .opencode/work/epics/EPIC-01-orders.md

# a board with a doing card and todo cards (the verify fixture)
P4="$(mkproj board)"; cp -R "$FIXTURE/.opencode/work/." "$P4/.opencode/work/"
check "a doing card: resume"                    "$P4" '^ROUTE: RESUME  .opencode/work/tasks/003-refund.md'
check "card number"                             "$P4" '^ROUTE: CARD  .opencode/work/tasks/003-refund.md' 3
check "card path"                               "$P4" '^ROUTE: CARD  .opencode/work/tasks/004-list.md' .opencode/work/tasks/004-list.md
check "status shows the board"                  "$P4" 'BOARD cards 6' status
check "state block has the board"               "$P4" '^ +003 doing'
sed -i.bak 's/^Status: doing/Status: todo/' "$P4/.opencode/work/tasks/003-refund.md"; rm -f "$P4/.opencode/work/tasks/003-refund.md.bak"
check "nothing doing, a ready card: next card"  "$P4" '^ROUTE: NEXT-CARD  .opencode/work/tasks/00[0-9]-'
check "auto resumes the same way"               "$P4" 'auto: yes' go

# the typed text is data: it is never executed or expanded
touch "$P4/sentinel"
check "metacharacters are not executed"         "$P4" '^ROUTE: WORK' '; rm sentinel; echo $(id)'
n=$((n+1)); if [ -e "$P4/sentinel" ]; then echo "  ok   ...and the sentinel file is still there"; else echo "  FAIL sentinel was removed"; fail=1; fi
check "a glob is not expanded"                  "$P4" '^ROUTE: WORK  \*' '*'

echo "$n cases"
exit $fail
