#!/usr/bin/env bash
# Runs a test suite and checks how many tests it ran (plan v3.8, Phase 7
# outcome): a suite that silently runs nothing must turn red, not report
# "passed" — the duel SQL tests went unrun for six commits that way.
#
#   bash tool/ci/test_count.sh <suite name> <minimum> -- <command…>
#
# The command is a `dart test` or `flutter test` run: its last progress line
# ("01:05 +1112: All tests passed!", "+12 ~1 -2: …") gives the passed count
# (+N; skipped ~N are not counted). Prints the count (an annotation on
# GitHub Actions) and fails if the command failed, if no count is found, or
# if the count is below <minimum>. Raise a minimum when a commit adds many
# tests; never lower one to make CI pass — find what stopped running.
set -uo pipefail

suite="${1:?usage: test_count.sh <suite> <minimum> -- <command…>}"
minimum="${2:?usage: test_count.sh <suite> <minimum> -- <command…>}"
[ "${3:-}" = "--" ] || { echo "usage: test_count.sh <suite> <minimum> -- <command…>" >&2; exit 2; }
shift 3

log="$(mktemp)"
trap 'rm -f "$log"' EXIT
"$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

say() {
  echo "$2"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::$1 title=$suite::$2"; fi
}

# The last "+N" of the run: the passed count. Carriage returns: compact
# reporters redraw one line.
count="$(tr '\r' '\n' < "$log" | grep -oE '(^|[[:space:]])\+[0-9]+' | tail -n 1 | tr -dc '0-9')"
if [ -z "$count" ]; then
  say error "no test count in the output (did the suite run at all?)"
  exit 3
fi
if [ "$status" -ne 0 ]; then
  say error "$count passed, but the suite failed (exit $status)"
  exit "$status"
fi
if [ "$count" -lt "$minimum" ]; then
  say error "$count tests ran, fewer than the pinned minimum $minimum"
  exit 4
fi
say notice "$count tests ran (minimum $minimum)"
