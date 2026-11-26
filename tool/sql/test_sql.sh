#!/usr/bin/env bash
# Applies every Supabase migration to a scratch Postgres database, then runs
# the SQL tests (Phase 2 commit 2). Locally and in CI — never against the
# real project, which CI updates with `supabase db push` instead.
#
#   tool/sql/test_sql.sh <postgres admin url>
#
# e.g. postgresql://postgres:postgres@localhost:5432/postgres. Creates (and
# drops first) the database `mt_sql_test` on that server.
set -Eeuo pipefail
# Any unexpected failure names its line (an annotation on GitHub Actions).
trap 'status=$?; echo "::error title=SQL runner::line $LINENO failed (exit $status): $BASH_COMMAND"' ERR

admin_url="${1:?usage: test_sql.sh <postgres admin url>}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
db=mt_sql_test
# Only warnings and errors: the idempotent migrations NOTICE every skip.
export PGOPTIONS="-c client_min_messages=warning"
# The SQL files are UTF-8; psql on Windows would otherwise read them in the
# console's code page and mangle every accented letter.
export PGCLIENTENCODING=UTF8

# Same server, other database: replace the path of the admin URL.
test_url="${admin_url%/*}/$db"

# On GitHub Actions a failure is also an annotation (readable without the
# job log's permissions).
fail() {
  echo "$2" >&2
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::error title=SQL $1::$(printf '%s' "$2" | tail -n 4 | tr '\n' ' ')"
  fi
  exit 3
}

run() {
  echo "-- $1"
  local out
  if ! out=$(psql "$test_url" -v ON_ERROR_STOP=1 -q -X -f "$1" 2>&1 >/dev/null); then
    fail "${1##*/}" "$out"
  fi
}

# A fresh Postgres container answers its health check during its first-run
# setup, then restarts: wait for a real connection (up to 60 s).
for attempt in $(seq 1 30); do
  if psql "$admin_url" -q -c 'select 1' >/dev/null 2>&1; then break; fi
  if [ "$attempt" = 30 ]; then
    fail connection "$(psql "$admin_url" -c 'select 1' 2>&1)"
  fi
  sleep 2
done

if ! out=$(psql "$admin_url" -v ON_ERROR_STOP=1 -q \
  -c "drop database if exists $db" -c "create database $db" 2>&1); then
  fail create-database "$out"
fi
run "$root/supabase/tests/00_supabase_stub.sql"
for file in "$root"/supabase/migrations/*.sql; do run "$file"; done
# Twice: every migration must be safe to re-apply (the first ones were run
# by hand before migrations existed).
for file in "$root"/supabase/migrations/*.sql; do run "$file"; done
# Every test file runs, and enough of them (plan v3.8): a file the pattern
# below leaves out would otherwise be skipped while this prints "passed"
# (Phase 7: the duel tests, named a1_…, for six commits). Raise the minimum
# when adding test files; never lower it to pass.
min_sql_tests=23
ran=0
for file in "$root"/supabase/tests/[1-9]*_test.sql; do run "$file"; ran=$((ran + 1)); done
for file in "$root"/supabase/tests/*_test.sql; do
  case "${file##*/}" in
    [1-9]*) ;;
    *) fail skipped "${file##*/} is not run: test files start with a digit 1-9" ;;
  esac
done
if [ "$ran" -lt "$min_sql_tests" ]; then
  fail count "$ran SQL test files ran, fewer than the pinned minimum $min_sql_tests"
fi
echo "$ran SQL test files ran (minimum $min_sql_tests)"
if [ -n "${GITHUB_ACTIONS:-}" ]; then
  echo "::notice title=SQL tests::$ran test files ran (minimum $min_sql_tests)"
fi

# The owner's dashboard script runs on what the tests left (Phase 3a commit
# 6): every command must work against the migrated schema.
dashboard() {
  echo "-- dashboard.sh $*"
  local out
  if ! out=$(DASHBOARD_DB_URL="$test_url" bash "$root/tool/dashboard/dashboard.sh" "$@" 2>&1); then
    fail "dashboard $1" "$out"
  fi
}
dashboard report
dashboard new-code "Zoé's group" 3
dashboard codes
dashboard disable-code dashtest
dashboard approve-name 00000000-0000-0000-0000-0000000000d5
dashboard feedback 5
dashboard data-check
dashboard features
dashboard moderation
dashboard hide 00000000-0000-0000-0000-0000000000d5 "scripted uploads, it's obvious"
dashboard ban 00000000-0000-0000-0000-0000000000d5
dashboard unhide 00000000-0000-0000-0000-0000000000d5
dashboard duels
dashboard review-run 00000000-0000-0000-0000-000000000000 ok
echo "SQL tests passed"
