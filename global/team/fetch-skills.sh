#!/usr/bin/env bash
# Install the third-party skills listed in skills.lock straight from their git repositories.
#   fetch-skills.sh [--dest DIR]     default DIR: ${XDG_CONFIG_HOME:-~/.config}/opencode/skills
# Each entry is cloned at its pinned ref, the kit's patch is applied (if the entry has one), and the result
# replaces DIR/<name>. An entry already installed from the same url, ref and patch is skipped.
# If git or the network is missing, an installed skill is kept as it is. Plain bash + git (+ patch or git apply);
# works on macOS and Linux. Env: SKILLS_LOCK=<file> and SKILLS_PATCHES=<dir> override the defaults (tests).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK="${SKILLS_LOCK:-$HERE/skills.lock}"
PATCHES="${SKILLS_PATCHES:-$HERE/patches}"
DEST="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/skills"
while [ $# -gt 0 ]; do
  case "$1" in
    --dest) DEST="$2"; shift 2 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "usage: fetch-skills.sh [--dest DIR]" >&2; exit 2 ;;
  esac
done
[ -f "$LOCK" ] || { echo "fetch-skills: $LOCK not found" >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "fetch-skills: git is required to install third-party skills" >&2; exit 1; }
mkdir -p "$DEST"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

apply_patch() { # dir patch
  if command -v patch >/dev/null 2>&1; then patch -s -p1 -d "$1" < "$2"
  else (cd "$1" && git apply -p1 "$2"); fi
}

fail=0
while IFS='|' read -r name url ref subdir pfile || [ -n "${name:-}" ]; do
  case "${name:-}" in ''|'#'*) continue ;; esac
  name="$(echo "$name" | tr -d ' ')"; url="$(echo "$url" | tr -d ' ')"; ref="$(echo "$ref" | tr -d ' ')"
  subdir="$(echo "$subdir" | tr -d ' ')"; pfile="$(echo "${pfile:-}" | tr -d ' ')"
  patch_path=""; sum="nopatch"
  if [ -n "$pfile" ]; then
    patch_path="$PATCHES/$pfile"
    [ -f "$patch_path" ] || { echo "  FAIL  $name: patch $patch_path not found"; fail=1; continue; }
    sum="$(cksum < "$patch_path" | cut -d' ' -f1)"
  fi
  stamp="$url $ref ${subdir:-.} $sum"
  if [ -f "$DEST/$name/.source" ] && [ "$(cat "$DEST/$name/.source")" = "$stamp" ]; then
    echo "  OK    $name already installed ($ref)"; continue
  fi
  work="$TMP/$name"; mkdir -p "$work"
  if ! git clone --quiet --no-checkout "$url" "$work/repo" 2>"$work/err" || ! git -C "$work/repo" checkout --quiet "$ref" 2>>"$work/err"; then
    if [ -f "$DEST/$name/SKILL.md" ]; then echo "  WARN  $name: could not fetch $url ($(head -1 "$work/err")); keeping the installed copy"
    else echo "  FAIL  $name: could not fetch $url at $ref ($(head -1 "$work/err"))"; fail=1; fi
    continue
  fi
  src="$work/repo/${subdir:-.}"
  if [ ! -f "$src/SKILL.md" ]; then echo "  FAIL  $name: no SKILL.md in ${subdir:-the repo root} of $url"; fail=1; continue; fi
  mkdir -p "$work/out"; cp -R "$src/." "$work/out/"; rm -rf "$work/out/.git"
  if [ -n "$patch_path" ] && ! apply_patch "$work/out" "$patch_path" 2>"$work/err"; then
    echo "  FAIL  $name: the kit patch $pfile does not apply to $ref ($(head -1 "$work/err"))"; fail=1; continue
  fi
  printf '%s\n' "$stamp" > "$work/out/.source"
  rm -rf "${DEST:?}/$name"; mv "$work/out" "$DEST/$name"
  echo "  OK    $name installed from $url@$ref${pfile:+ (patched: $pfile)}"
done < "$LOCK"
exit "$fail"
