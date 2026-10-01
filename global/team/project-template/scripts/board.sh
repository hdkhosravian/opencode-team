#!/usr/bin/env bash
# scripts/board.sh - the task board, derived from the cards. The cards are the only source of truth;
# this script costs zero model tokens and cannot be talked into agreeing with a claim.
#
#   board.sh            summary: epics, counts, open cards (about 20 lines)
#   board.sh all        every card, one line each
#   board.sh next       the card to work on next (a 'doing' card is resumed first)
#   board.sh next-id    next free card number
#   board.sh verify     consistency and proof checks; exit 1 on any problem
#
# Cards:  .opencode/work/tasks/NNN-slug.md   (header fields: Epic Risk Depends Dev Status Attempts Review Note)
# Epics:  .opencode/work/epics/EPIC-NN-slug.md   (Slices-frozen: N, then "- [ ] S1 ..." lines)
# Plain bash + awk + git + grep: no Python, no GNU-only options (works with macOS defaults).

set -u
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT" || exit 2
TASKS=.opencode/work/tasks
EPICS=.opencode/work/epics
TAB="$(printf '\t')"

# One line per card: id file risk status attempts review dev deps epic note title  (tab separated, "?" = missing)
cards_tsv() {
  [ -d "$TASKS" ] || return 0
  for f in "$TASKS"/*.md; do
    [ -f "$f" ] || continue
    awk -v F="$f" '
      function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
      function val(line, key,   v) { v = trim(substr(line, length(key) + 2)); return v }
      NR > 20 { exit }
      /^# /       { if (title == "") { t = $0; sub(/^# +/, "", t); title = trim(t) } next }
      /^Epic:/     { epic = val($0, "Epic");         next }
      /^Risk:/     { risk = val($0, "Risk");         next }
      /^Depends:/  { deps = val($0, "Depends");      next }
      /^Dev:/      { dev = val($0, "Dev");           next }
      /^Status:/   { status = val($0, "Status");     next }
      /^Attempts:/ { attempts = val($0, "Attempts"); next }
      /^Review:/   { review = val($0, "Review");     next }
      /^Note:/     { note = val($0, "Note");         next }
      END {
        n = split(F, p, "/"); b = p[n]
        id = "?"; if (match(b, /^[0-9]+/)) id = substr(b, 1, RLENGTH)
        if (title == "") title = b
        sub(/^[0-9]+[ -]*/, "", title)
        if (epic == "") epic = "?"; if (risk == "") risk = "?"; if (deps == "") deps = "?"
        if (dev == "") dev = "?"; if (status == "") status = "?"; if (attempts == "") attempts = "?"
        if (review == "") review = "?"; if (note == "") note = "?"; if (title == "") title = "?"
        gsub(/\t/, " ", title); gsub(/\t/, " ", note)
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, F, risk, status, attempts, review, dev, deps, epic, note, title
      }' "$f"
  done
}

epic_files() { [ -d "$EPICS" ] && ls "$EPICS"/EPIC-*.md 2>/dev/null; }
epic_id()    { basename "$1" | sed -E 's/^(EPIC-[0-9]+).*/\1/'; }
epic_title() { awk 'NR <= 5 && /^# / { t = $0; sub(/^# +EPIC-[0-9]+ */, "", t); print t; exit }' "$1"; }
slices_total() { grep -Ec '^- \[[ xX]\] ' "$1" 2>/dev/null || true; }
slices_done()  { grep -Ec '^- \[[xX]\] ' "$1" 2>/dev/null || true; }
frozen_n()     { awk '/^Slices-frozen:/ { v = $0; sub(/^Slices-frozen:[ \t]*/, "", v); sub(/[ \t\r]+$/, "", v); print v; exit }' "$1"; }

cmd_summary() {
  local all="${1:-}" tsv total done_n doing todo blocked
  tsv="$(cards_tsv)"
  if [ -z "$tsv" ] && [ -z "$(epic_files)" ]; then echo "BOARD empty: no epics, no cards."; return 0; fi
  total=0; done_n=0; doing=0; todo=0; blocked=0
  if [ -n "$tsv" ]; then
    total="$(printf '%s\n' "$tsv" | wc -l | tr -d ' ')"
    done_n="$(printf '%s\n' "$tsv" | awk -F'\t' '$4=="done"' | wc -l | tr -d ' ')"
    doing="$(printf '%s\n' "$tsv" | awk -F'\t' '$4=="doing"' | wc -l | tr -d ' ')"
    todo="$(printf '%s\n' "$tsv" | awk -F'\t' '$4=="todo"' | wc -l | tr -d ' ')"
    blocked="$(printf '%s\n' "$tsv" | awk -F'\t' '$4=="blocked"' | wc -l | tr -d ' ')"
  fi
  echo "BOARD cards $total: done $done_n, doing $doing, todo $todo, blocked $blocked"
  for e in $(epic_files); do
    local id st sd cdn ct
    id="$(epic_id "$e")"; st="$(slices_total "$e")"; sd="$(slices_done "$e")"
    ct=0; cdn=0
    if [ -n "$tsv" ]; then
      ct="$(printf '%s\n' "$tsv" | awk -F'\t' -v e="$id" '$9==e' | wc -l | tr -d ' ')"
      cdn="$(printf '%s\n' "$tsv" | awk -F'\t' -v e="$id" '$9==e && $4=="done"' | wc -l | tr -d ' ')"
    fi
    echo "$id $(epic_title "$e")  slices $sd/$st  cards $cdn/$ct"
  done
  [ -n "$tsv" ] || return 0
  # priority: doing, blocked, todo (done only with "all")
  printf '%s\n' "$tsv" | awk -F'\t' -v all="$all" '
    $4=="done" && all != "all" { next }
    { pr = ($4=="doing") ? 1 : ($4=="blocked") ? 2 : ($4=="todo") ? 3 : 4
      dev = ($7=="developer-strong") ? "strong" : "dev"
      extra = ""
      if ($4=="blocked") extra = "  note: " $10
      else if ($8 != "none" && $8 != "?" && $4=="todo") extra = "  after " $8
      printf "%d\t%s %-7s %s %-6s try %s  rev %s  %s%s\n", pr, $1, $4, $3, dev, $5, $6, $11, extra }' |
    sort -s -t "$TAB" -k1,1n | cut -f2- | awk -v all="$all" '
      { n++; if (all != "all" && n > 15) { more++; next } print " " $0 }
      END { if (more > 0) print " +" more " more (board.sh all)" }'
}

cmd_next() {
  local tsv ids first
  tsv="$(cards_tsv)"
  [ -n "$tsv" ] || { echo "none (no cards)"; return 0; }
  first="$(printf '%s\n' "$tsv" | awk -F'\t' '$4=="doing" { print; exit }')"
  if [ -n "$first" ]; then
    printf '%s\n' "$first" | awk -F'\t' '{ print "RESUME " $1 "  " $2 "  (" $3 ", " $7 ", try " $5 ")  - unfinished: check git log and scripts/check.sh before delegating" }'
    return 0
  fi
  ids="$(printf '%s\n' "$tsv" | awk -F'\t' '$4=="done" { print $1 }' | tr '\n' ' ')"
  first="$(printf '%s\n' "$tsv" | awk -F'\t' -v done_ids=" $ids" '
    $4 != "todo" { next }
    { ok = 1
      if ($8 != "none" && $8 != "?") {
        n = split($8, d, /[ ,]+/)
        for (i = 1; i <= n; i++) if (d[i] != "" && index(done_ids, " " d[i] " ") == 0) ok = 0
      }
      if (ok) { print; exit } }')"
  if [ -n "$first" ]; then
    printf '%s\n' "$first" | awk -F'\t' '{ print "NEXT " $1 "  " $2 "  (" $3 ", " $7 ")" }'
  elif printf '%s\n' "$tsv" | awk -F'\t' '$4=="todo" { f = 1 } END { exit !f }'; then
    echo "none ready: todo cards wait on unfinished or blocked dependencies (board.sh)"
  else
    echo "none (nothing todo)"
  fi
}

cmd_next_id() {
  cards_tsv | awk -F'\t' 'BEGIN { m = 0 } $1 ~ /^[0-9]+$/ { if ($1 + 0 > m) m = $1 + 0 } END { printf "%03d\n", m + 1 }'
}

ERRS=0
err() { ERRS=$((ERRS + 1)); [ "$ERRS" -le 20 ] && echo "ERROR: $*"; return 0; }

cmd_verify() {
  local tsv ncards=0 nepics=0 subjects doing=0
  tsv="$(cards_tsv)"
  subjects=""
  git rev-parse --git-dir >/dev/null 2>&1 && subjects="$(git log --format=%s 2>/dev/null)"
  status_of() { printf '%s\n' "$tsv" | awk -F'\t' -v i="$1" '$1==i { print $4; exit }'; }
  if [ -n "$tsv" ]; then
    while IFS="$TAB" read -r id file risk status attempts review dev deps epic note title; do
      ncards=$((ncards + 1))
      local k v
      for k in risk status attempts review dev deps epic note; do
        eval "v=\$$k"
        [ "$v" = "?" ] && err "$id: header field '$k' is missing in $file"
      done
      case "$status" in todo|doing|done|blocked|"?") ;; *) err "$id: Status '$status' is not todo|doing|done|blocked" ;; esac
      case "$risk" in T0|T1|T2|T3|"?") ;; *) err "$id: Risk '$risk' is not T0|T1|T2|T3" ;; esac
      case "$dev" in developer|developer-strong|"?") ;; *) err "$id: Dev '$dev' is not developer|developer-strong" ;; esac
      case "$review" in -|PASS|"PASS WITH NOTES"|BLOCK|"?") ;; *) err "$id: Review '$review' is not -|PASS|PASS WITH NOTES|BLOCK" ;; esac
      case "$attempts" in
        ''|*[!0-9]*) [ "$attempts" = "?" ] || err "$id: Attempts '$attempts' is not a number" ;;
        *) if [ "$dev" = "developer-strong" ] && [ "$attempts" -gt 2 ]; then err "$id: Attempts $attempts exceeds 2 for developer-strong"
           elif [ "$dev" = "developer" ] && [ "$attempts" -gt 3 ]; then err "$id: Attempts $attempts exceeds 3 for developer"; fi ;;
      esac
      if [ "$deps" != "none" ] && [ "$deps" != "?" ]; then
        local d
        for d in $(printf '%s' "$deps" | tr ',' ' '); do
          if [ -z "$(status_of "$d")" ]; then err "$id: depends on $d, which is not a card"
          elif [ "$status" = "done" ] && [ "$(status_of "$d")" != "done" ]; then err "$id: is done but its dependency $d is not"; fi
        done
      fi
      [ "$status" = "doing" ] && doing=$((doing + 1))
      if [ "$status" = "blocked" ] && { [ "$note" = "-" ] || [ "$note" = "?" ]; }; then err "$id: blocked without a Note (the reason)"; fi
      if [ "$status" = "done" ]; then
        case "$attempts" in 0) err "$id: done with Attempts 0 (no developer run was recorded)" ;; esac
        if [ -n "$subjects" ]; then
          printf '%s\n' "$subjects" | grep -Eq "^(feat|fix|refactor|perf|chore)\($id\)" || err "$id: done, but no feat|fix|refactor|perf|chore($id) commit exists (test($id) and docs($id) do not count)"
        fi
        if [ "$risk" != "T0" ] && [ "$risk" != "?" ]; then
          case "$review" in PASS|"PASS WITH NOTES") ;; *) err "$id: $risk card is done but Review is '$review' (needs PASS or PASS WITH NOTES)" ;; esac
          local tests t found=0
          tests="$(awk '/^## /{ in_sec = ($0 ~ /^## Acceptance tests/) } in_sec' "$file" 2>/dev/null | grep -Eo 'tests/acceptance/[A-Za-z0-9_./*-]+' | sed -E 's/[.,;:]+$//' | grep -v '/$' | grep -v '\*' | sort -u)"
          for t in $tests; do
            found=1
            [ -e "$t" ] || err "$id: acceptance test '$t' listed in the card does not exist"
          done
          [ "$found" -eq 1 ] || err "$id: $risk card lists no tests/acceptance/... file"
        fi
      fi
    done <<EOF
$tsv
EOF
  fi
  [ "$doing" -gt 1 ] && err "$doing cards are 'doing' at once (writers are single-threaded: finish or block one first)"
  local e id n frozen sd open
  for e in $(epic_files); do
    nepics=$((nepics + 1)); id="$(epic_id "$e")"; n="$(slices_total "$e")"; sd="$(slices_done "$e")"; frozen="$(frozen_n "$e")"
    if [ -z "$frozen" ]; then err "$id: header 'Slices-frozen: N' is missing"
    elif ! printf '%s' "$frozen" | grep -Eq '^[0-9]+$'; then err "$id: Slices-frozen '$frozen' is not a number"
    elif [ "$n" -ne "$frozen" ]; then err "$id: has $n slice lines but Slices-frozen is $frozen (slices added or removed without the lead)"; fi
    if [ "$n" -gt 0 ] && [ "$sd" -eq "$n" ] && [ -n "$tsv" ]; then
      open="$(printf '%s\n' "$tsv" | awk -F'\t' -v e="$id" '$9==e && $4!="done" { printf "%s ", $1 }')"
      [ -n "$open" ] && err "$id: all slices are ticked but these cards are not done: $open"
    fi
  done
  if [ "$ERRS" -gt 0 ]; then
    [ "$ERRS" -gt 20 ] && echo "... and $((ERRS - 20)) more"
    echo "BOARD FAILED ($ERRS problems)"
    return 1
  fi
  echo "BOARD OK ($ncards cards, $nepics epics)"
}

case "${1:-}" in
  ""|summary) cmd_summary ;;
  all)        cmd_summary all ;;
  next)       cmd_next ;;
  next-id)    cmd_next_id ;;
  verify)     cmd_verify ;;
  *) echo "usage: scripts/board.sh [all|next|next-id|verify]"; exit 2 ;;
esac
