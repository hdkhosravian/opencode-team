#!/usr/bin/env bash
# Prepare the current git project for the OpenCode team. Run via /team-init.
# Safe: never overwrites files, refuses $HOME and /, never runs git init itself.
set -euo pipefail
TEMPLATE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/project-template"

if ! ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  echo "STOP: $(pwd) is not a git repository. Ask the user to run 'git init' here (or open the right folder), then run /team-init again."
  exit 1
fi
case "$ROOT" in
  "$HOME"|"/"|"$HOME/Desktop"|"$HOME/Documents"|"$HOME/Downloads")
    echo "STOP: refusing to bootstrap $ROOT. Open OpenCode inside a specific project folder."; exit 1 ;;
esac
cd "$ROOT"

created=0; skipped_agents=0; differing=""
while IFS= read -r -d '' src; do
  rel="${src#"$TEMPLATE"/}"
  dst="$ROOT/$rel"
  if [ "$rel" = "AGENTS.md" ] && [ ! -e AGENTS.md ] && [ -e CLAUDE.md ]; then
    skipped_agents=1; continue
  fi
  case "$(basename "$rel")" in .DS_Store) continue ;; esac
  if [ ! -e "$dst" ]; then
    mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; created=$((created+1)); echo "created $rel"
  elif [ "$(dirname "$rel")" = "scripts" ] && ! cmp -s "$src" "$dst"; then
    differing="$differing $rel"
  fi
done < <(find "$TEMPLATE" -type f -print0)
chmod +x scripts/check.sh scripts/board.sh 2>/dev/null || true

[ "$skipped_agents" -eq 1 ] && echo "note: CLAUDE.md exists, so AGENTS.md was not created (OpenCode reads CLAUDE.md only when AGENTS.md is absent). Put project facts in CLAUDE.md."
[ -n "$differing" ] && echo "note: these scripts differ from the kit version (kept as is):$differing. To update one, copy it from $TEMPLATE/ yourself."
echo "bootstrap done in $ROOT: $created new files (existing files untouched)"
