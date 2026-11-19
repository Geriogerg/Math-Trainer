#!/usr/bin/env bash
# The owner's dashboard (Phase 3a commit 6): reports and beta chores on the
# live database, from the owner's machine — never from CI (the repository
# and its logs are public; this prints testers' data).
#
#   bash tool/dashboard/dashboard.sh                     the report
#   bash tool/dashboard/dashboard.sh new-code <label> [max uses, default 1]
#   bash tool/dashboard/dashboard.sh codes               codes and their uses
#   bash tool/dashboard/dashboard.sh disable-code <code>
#   bash tool/dashboard/dashboard.sh approve-name <player id>
#   bash tool/dashboard/dashboard.sh clear-name <player id>
#   bash tool/dashboard/dashboard.sh feedback [count, default 50]
#   bash tool/dashboard/dashboard.sh data-check          what Phase 3b needs, stored?
#
# Connection: the environment variable DASHBOARD_DB_URL, else the first
# line of tool/dashboard/connection.txt (git-ignored): Supabase → Connect →
# "Session pooler" string, with the database password filled in. Never
# printed. Needs psql (PostgreSQL client, 15 or newer).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
url="${DASHBOARD_DB_URL:-}"
if [ -z "$url" ] && [ -f "$here/connection.txt" ]; then
  url="$(head -n 1 "$here/connection.txt" | tr -d '\r')"
fi
if [ -z "$url" ]; then
  echo "No connection: set DASHBOARD_DB_URL or write tool/dashboard/connection.txt (see the top of this script)." >&2
  exit 2
fi
command -v psql > /dev/null || { echo "psql not found: install the PostgreSQL client." >&2; exit 2; }

# psql on Windows reads input in the console's code page otherwise.
export PGCLIENTENCODING=UTF8

# SQL goes through stdin, never the command line: Git Bash hands
# non-ASCII arguments to Windows programs in the wrong encoding.
run() { psql "$url" -X -q -v ON_ERROR_STOP=1 -P pager=off -P footer=off; }
literal() { local v="${1//\'/\'\'}"; printf "'%s'" "$v"; }
need() { [ -n "${1:-}" ] || { echo "usage: see the top of $0" >&2; exit 2; }; }

command="${1:-report}"
case "$command" in
  report)
    run < "$here/report.sql"
    ;;
  data-check)
    run < "$here/data_check.sql"
    ;;
  new-code)
    need "${2:-}"
    uses="${3:-1}"
    [[ "$uses" =~ ^[1-9][0-9]*$ ]] || { echo "max uses must be a positive number" >&2; exit 2; }
    echo "select public.create_beta_code($(literal "$2"), $uses) as new_code;" | run
    ;;
  codes)
    echo "select code, label, uses || ' / ' || max_uses as used, case when disabled then 'disabled' else '' end as state, to_char(created_at, 'YYYY-MM-DD') as created from owner_dashboard.codes;" | run
    ;;
  disable-code)
    need "${2:-}"
    echo "update public.beta_codes set disabled = true where code = public.normalize_beta_code($(literal "$2")) returning code, label, 'disabled' as now;" | run
    ;;
  approve-name|clear-name)
    need "${2:-}"
    [[ "$2" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "not a player id: $2" >&2; exit 2; }
    verdict="${command%-name}"
    echo "select owner_dashboard.review_name('$2', '$verdict') as done;" | run
    ;;
  feedback)
    count="${2:-50}"
    [[ "$count" =~ ^[0-9]+$ ]] || { echo "count must be a number" >&2; exit 2; }
    echo "select to_char(created_at, 'YYYY-MM-DD HH24:MI') as at, app_version, player, message from owner_dashboard.recent_feedback limit $count;" | run
    ;;
  *)
    echo "unknown command: $command (see the top of $0)" >&2
    exit 2
    ;;
esac
