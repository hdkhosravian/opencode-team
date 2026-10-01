#!/usr/bin/env bash
# Tests for global/team/fetch-skills.sh with a local git repository standing in for the upstream skill.
# Run from anywhere: bash tests/fetch_skills/run.sh
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FETCH="$HERE/../../global/team/fetch-skills.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
fail=0
check() { if eval "$2"; then echo "  ok   $1"; else echo "  FAIL $1"; fail=1; fi; }

# an "upstream" skill repo with two commits
UP="$TMP/up"; mkdir -p "$UP/skills/demo/scripts" && cd "$UP" && git init -q
printf -- '---\nname: demo\ndescription: a long upstream description that the kit shortens\n---\nstate lives in .claude/loops\n' > skills/demo/SKILL.md
echo 'print("hi")' > skills/demo/scripts/run.py
git add -A && git commit -qm one && C1="$(git rev-parse --short HEAD)"
echo 'second' >> skills/demo/SKILL.md && git add -A && git commit -qm two && C2="$(git rev-parse --short HEAD)"
sed -i.bak 's/state lives in .claude\/loops/state moved somewhere else entirely/' skills/demo/SKILL.md && rm skills/demo/SKILL.md.bak
git add -A && git commit -qm three && C3="$(git rev-parse --short HEAD)"

# the kit's patch: changes the first commit's text
mkdir -p "$TMP/patches" "$TMP/orig" && git -C "$UP" show "$C1:skills/demo/SKILL.md" > "$TMP/orig/SKILL.md"
sed 's/\.claude\/loops/.opencode\/loops/; s/a long upstream description that the kit shortens/short/' "$TMP/orig/SKILL.md" > "$TMP/new.md"
( cd "$TMP" && python3 - <<'PY'
import difflib
a=open('orig/SKILL.md').read().splitlines(True); b=open('new.md').read().splitlines(True)
open('patches/demo.patch','w').write(''.join(difflib.unified_diff(a,b,'a/SKILL.md','b/SKILL.md')))
PY
)
export SKILLS_PATCHES="$TMP/patches"
DEST="$TMP/dest"

printf 'demo|%s|%s|skills/demo|demo.patch\n' "$UP" "$C1" > "$TMP/lock"
out="$(SKILLS_LOCK="$TMP/lock" bash "$FETCH" --dest "$DEST" 2>&1)"; rc=$?
check "installs from git and applies the patch" "[ $rc -eq 0 ] && grep -q 'opencode/loops' '$DEST/demo/SKILL.md' && grep -q 'description: short' '$DEST/demo/SKILL.md'"
check "keeps the skill's other files"           "[ -f '$DEST/demo/scripts/run.py' ]"
check "no git metadata is copied"               "[ ! -e '$DEST/demo/.git' ]"
check "writes a source stamp"                   "grep -q '$C1' '$DEST/demo/.source'"
out="$(SKILLS_LOCK="$TMP/lock" bash "$FETCH" --dest "$DEST" 2>&1)"
check "second run skips (same url, ref, patch)" "echo '$out' | grep -q 'already installed'"

printf 'demo|%s|%s|skills/demo|\n' "$UP" "$C2" > "$TMP/lock2"
SKILLS_LOCK="$TMP/lock2" bash "$FETCH" --dest "$DEST" >/dev/null 2>&1
check "a new pinned ref replaces the install"   "grep -q second '$DEST/demo/SKILL.md' && ! grep -q 'opencode/loops' '$DEST/demo/SKILL.md'"

printf 'demo|%s|%s|skills/demo|demo.patch\n' "$UP" "$C3" > "$TMP/lock3"
out="$(SKILLS_LOCK="$TMP/lock3" bash "$FETCH" --dest "$DEST" 2>&1)"; rc=$?
check "a patch that no longer applies fails"    "[ $rc -ne 0 ] && echo '$out' | grep -q 'does not apply'"
check "...and leaves the installed copy alone"  "grep -q second '$DEST/demo/SKILL.md'"

printf 'demo|%s/nowhere|%s|skills/demo|\n' "$TMP" "$C1" > "$TMP/lock4"
out="$(SKILLS_LOCK="$TMP/lock4" bash "$FETCH" --dest "$DEST" 2>&1)"; rc=$?
check "unreachable repo keeps an installed copy (warning, exit 0)" "[ $rc -eq 0 ] && echo '$out' | grep -q 'keeping the installed copy'"
rm -rf "$DEST"
out="$(SKILLS_LOCK="$TMP/lock4" bash "$FETCH" --dest "$DEST" 2>&1)"; rc=$?
check "unreachable repo with nothing installed fails" "[ $rc -ne 0 ]"

printf 'demo|%s|%s|skills/missing|\n' "$UP" "$C1" > "$TMP/lock5"
out="$(SKILLS_LOCK="$TMP/lock5" bash "$FETCH" --dest "$DEST" 2>&1)"; rc=$?
check "wrong folder in the repo fails"          "[ $rc -ne 0 ] && echo '$out' | grep -q 'no SKILL.md'"
exit $fail
