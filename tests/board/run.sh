#!/usr/bin/env bash
# Negative tests for scripts/board.sh verify: each case breaks a clean board in one way
# and expects verify to fail with the right message. Run from anywhere: bash tests/board/run.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../../global/team/project-template/scripts"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
BASE="$TMP/base"; W="$TMP/w"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# GNU and BSD sed differ on -i, so every case uses sed -i.bak (works on both)
# a clean project: 6 cards, one epic, two real commits
mkdir -p "$BASE" && cp -R "$HERE/fixture/." "$BASE/" && mkdir -p "$BASE/scripts" && cp "$SCRIPTS"/*.sh "$BASE/scripts/"
( cd "$BASE" && git init -q && git add -A && git commit -qm 'chore(001): scaffold' && git commit -qm 'feat(002): place order' --allow-empty )

fail=0
run() { # name expect-regex mutation-cmd
  rm -rf "$W"; cp -R "$BASE" "$W"; cd "$W"
  eval "$3" >/dev/null 2>&1
  out="$(bash scripts/board.sh verify 2>&1)"; rc=$?
  if printf '%s' "$out" | grep -Eq "$2" && [ $rc -eq 1 ]; then echo "  ok   $1"; else echo "  FAIL $1 (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/        /'; fail=1; fi
}
S=.opencode/work/tasks
run "done without commit"           "004: done, but no feat"          "sed -i.bak 's/^Status: todo/Status: done/;s/^Review: -/Review: PASS/' $S/004-list.md; echo '- tests/acceptance/order.test.ts :: x' >> $S/004-list.md"
run "T1 done without review"        "004: T1 card is done but Review"   "sed -i.bak 's/^Status: todo/Status: done/' $S/004-list.md; git commit -qm 'feat(004): x' --allow-empty"
run "T1 done, no acceptance listed" "004: T1 card lists no tests"       "sed -i.bak 's/^Status: todo/Status: done/;s/^Review: -/Review: PASS/;/placeholder/d' $S/004-list.md; git commit -qm 'feat(004): x' --allow-empty"
run "acceptance file missing"       "does not exist"                    "sed -i.bak 's/^Status: todo/Status: done/;s/^Review: -/Review: PASS/' $S/004-list.md; git commit -qm 'feat(004): x' --allow-empty"
run "attempts over cap"             "Attempts 4 exceeds 3"              "sed -i.bak 's/^Attempts: 0/Attempts: 4/' $S/004-list.md"
run "strong attempts over cap"      "exceeds 2 for developer-strong"    "sed -i.bak 's/^Attempts: 1/Attempts: 3/' $S/003-refund.md"
run "two doing"                     "2 cards are 'doing'"               "sed -i.bak 's/^Status: todo/Status: doing/' $S/004-list.md"
run "blocked without note"          "006: blocked without a Note"       "sed -i.bak 's/^Note: Gemini.*/Note: -/' $S/006-export.md"
run "missing header field"          "header field 'risk' is missing"    "sed -i.bak '/^Risk:/d' $S/004-list.md"
run "bad status"                    "Status 'finished'"                 "sed -i.bak 's/^Status: todo/Status: finished/' $S/004-list.md"
run "bad review value"              "Review 'GOOD'"                     "sed -i.bak 's/^Review: -/Review: GOOD/' $S/004-list.md"
run "dependency not a card"         "depends on 099"                    "sed -i.bak 's/^Depends: 002/Depends: 099/' $S/004-list.md"
run "done but dep not done"         "is done but its dependency 003"    "sed -i.bak 's/^Status: todo/Status: done/;s/^Review: -/Review: PASS/' $S/005-notify.md; git commit -qm 'feat(005): x' --allow-empty"
run "frozen mismatch"               "has 3 slice lines but Slices-frozen is 5" "sed -i.bak 's/^Slices-frozen: 3/Slices-frozen: 5/' .opencode/work/epics/EPIC-01-orders.md"
run "frozen missing"                "Slices-frozen: N' is missing"      "sed -i.bak '/^Slices-frozen/d' .opencode/work/epics/EPIC-01-orders.md"
run "slices removed"                "has 2 slice lines"                 "sed -i.bak '/S3 third/d' .opencode/work/epics/EPIC-01-orders.md"
run "all ticked, cards open"        "all slices are ticked but these cards" "sed -i.bak 's/^- \[ \]/- [x]/' .opencode/work/epics/EPIC-01-orders.md"
run "commit without card scope"     "004: done, but no feat"          "sed -i.bak 's/^Status: todo/Status: done/;s/^Review: -/Review: PASS/' $S/004-list.md; git commit -qm 'feat: x' --allow-empty"
run "test commit does not count"    "004: done, but no feat"          "sed -i.bak 's/^Status: todo/Status: done/;s/^Review: -/Review: PASS/' $S/004-list.md; git commit -qm 'test(004): x' --allow-empty"
run "done in a repo with no commits" "004: done, but no feat"       "sed -i.bak 's/^Status: todo/Status: done/;s/^Review: -/Review: PASS/' $S/004-list.md; rm -rf .git; git init -q"
run "done with Attempts 0"          "Attempts 0"                      "sed -i.bak 's/^Status: todo/Status: done/;s/^Review: -/Review: PASS/' $S/004-list.md; git commit -qm 'feat(004): x' --allow-empty"
# positive: clean board
rm -rf "$W"; cp -R "$BASE" "$W"; cd "$W"; out="$(bash scripts/board.sh verify 2>&1)"; rc=$?
[ $rc -eq 0 ] && echo "$out" | grep -q "BOARD OK" && echo "  ok   clean board passes" || { echo "  FAIL clean board: $out"; fail=1; }
# empty project
rm -rf "$W"; mkdir -p "$W"; cd "$W"; git init -q; mkdir -p scripts; cp "$BASE/scripts/board.sh" scripts/
for c in "" next next-id verify; do echo "   empty[$c]: $(bash scripts/board.sh $c 2>&1 | head -2 | tr '\n' '|')"; done
exit $fail
