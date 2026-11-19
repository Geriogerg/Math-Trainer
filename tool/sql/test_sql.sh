#!/usr/bin/env bash
# Applies every Supabase migration to a scratch Postgres database, then runs
# the SQL tests (Phase 2 commit 2). Locally and in CI — never against the
# real project, which CI updates with `supabase db push` instead.
#
#   tool/sql/test_sql.sh <postgres admin url>
#
# e.g. postgresql://postgres:postgres@localhost:5432/postgres. Creates (and
# drops first) the database `mt_sql_test` on that server.
set -euo pipefail

admin_url="${1:?usage: test_sql.sh <postgres admin url>}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
db=mt_sql_test
# Only warnings and errors: the idempotent migrations NOTICE every skip.
export PGOPTIONS="-c client_min_messages=warning"

psql "$admin_url" -v ON_ERROR_STOP=1 -q -c "drop database if exists $db" \
  -c "create database $db"
# Same server, other database: replace the path of the admin URL.
test_url="${admin_url%/*}/$db"

run() {
  echo "-- $1"
  psql "$test_url" -v ON_ERROR_STOP=1 -q -X -f "$1" >/dev/null
}

run "$root/supabase/tests/00_supabase_stub.sql"
for file in "$root"/supabase/migrations/*.sql; do run "$file"; done
# Twice: every migration must be safe to re-apply (the first ones were run
# by hand before migrations existed).
for file in "$root"/supabase/migrations/*.sql; do run "$file"; done
for file in "$root"/supabase/tests/[1-9]*_test.sql; do run "$file"; done
echo "SQL tests passed"
