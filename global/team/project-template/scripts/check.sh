#!/usr/bin/env bash
# Deterministic quality gate for the team.
# Source of truth: .opencode/check.cmds (one shell command per line, # for comments).
# Without it, the stack is auto-detected. Only failing steps print output (last N lines).
# Fails if tests/acceptance/ contains tests that no step runs.
set -u
cd "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

TAIL_LINES="${CHECK_TAIL_LINES:-40}"
fail=0; ran=0; steps=""

step() {
  local name="$1"; shift
  ran=$((ran+1)); steps="$steps
$name"
  local out
  if out=$("$@" 2>&1 </dev/null); then
    echo "PASS  $name"
  else
    fail=1
    echo "FAIL  $name"
    echo "----- last ${TAIL_LINES} lines -----"
    echo "$out" | tail -n "$TAIL_LINES"
    echo "-----"
  fi
}
has_npm_script() { [ -f package.json ] && grep -q "\"$1\"[[:space:]]*:" package.json; }
have() { command -v "$1" >/dev/null 2>&1; }

if [ -f .opencode/check.cmds ] && grep -qvE '^[[:space:]]*(#|$)' .opencode/check.cmds; then
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in ''|'#'*) continue ;; esac
    step "$line" bash -c "$line"
  done < .opencode/check.cmds
else
  if [ -f package.json ]; then
    pm=npm
    [ -f pnpm-lock.yaml ] && pm=pnpm
    [ -f yarn.lock ] && pm=yarn
    { [ -f bun.lockb ] || [ -f bun.lock ]; } && pm=bun
    has_npm_script lint      && step "$pm run lint"      $pm run lint
    has_npm_script typecheck && step "$pm run typecheck" $pm run typecheck
    has_npm_script test      && step "$pm test"          $pm test
  fi
  if [ -f pyproject.toml ] || [ -f setup.cfg ] || [ -f requirements.txt ]; then
    have ruff   && step "ruff check ." ruff check .
    have mypy   && [ -f pyproject.toml ] && grep -q mypy pyproject.toml && step "mypy ." mypy .
    have pytest && step "pytest -q" pytest -q
  fi
  if [ -f go.mod ]; then
    step "go vet ./..."  go vet ./...
    step "go test ./..." go test ./...
  fi
  if [ -f Cargo.toml ]; then
    step "cargo clippy" cargo clippy --all-targets -- -D warnings
    step "cargo test"   cargo test
  fi
  if [ -f Gemfile ]; then
    grep -q rubocop Gemfile && step "rubocop" bundle exec rubocop
    if [ -d spec ]; then step "rspec" bundle exec rspec
    elif [ -d test ]; then step "rails test" bundle exec rails test; fi
  fi
fi

if [ "$ran" -eq 0 ]; then
  echo "NO CHECKS RAN: no stack detected. Write the commands into .opencode/check.cmds (tech-lead)."
  exit 2
fi

# Guard: acceptance tests must be wired into the gate.
if [ -d tests/acceptance ] && [ -n "$(find tests/acceptance -type f ! -name '.gitkeep' 2>/dev/null | head -1)" ]; then
  # a step that merely mentions the folder in --ignore/--exclude/--deselect does not run it
  if ! printf '%s' "$steps" | grep -v -E -- '--(ignore|exclude|deselect)([= ]+)[^ ]*tests/acceptance' | grep -q "tests/acceptance"; then
    echo "FAIL  acceptance tests exist but no step runs tests/acceptance"
    echo "      Add an explicit command to .opencode/check.cmds, e.g.:"
    echo "      npx vitest run tests/acceptance | pytest -q tests/acceptance | bundle exec rspec tests/acceptance | go test ./tests/acceptance/..."
    fail=1
  fi
fi

if [ "$fail" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "$fail"
