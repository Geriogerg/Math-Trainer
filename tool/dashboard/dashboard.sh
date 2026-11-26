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
#   bash tool/dashboard/dashboard.sh features            answers by structural feature
#   bash tool/dashboard/dashboard.sh weak-spots          Phase 4: scheduled items, before/after (needs dart)
#   bash tool/dashboard/dashboard.sh duels               Phase 7: duels, ratings, flagged runs, friends
#   bash tool/dashboard/dashboard.sh review-run <run id> ok|reject   a flagged duel run: back in the pool, or out
#   bash tool/dashboard/dashboard.sh usage                          the database against the free plan (alert from 50 %)
#   bash tool/dashboard/dashboard.sh moderation                     who is hidden or banned; who to look at
#   bash tool/dashboard/dashboard.sh hide <player id> [reason]      off the boards, the pool and friend search
#   bash tool/dashboard/dashboard.sh ban <player id> [reason]       hidden, and nothing more accepted from them
#   bash tool/dashboard/dashboard.sh unhide <player id>             lifts either
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

# ...and a Windows console (VS Code's terminal, Windows Terminal) decodes
# psql's UTF-8 output with its own code page (850 or 1252 on a French
# Windows): "—" and accented names come out garbled. Switch the console to
# UTF-8 for this run, then back. No console (mintty, CI): chcp fails, skip.
if command -v chcp.com > /dev/null 2>&1; then
  old_cp="$( (chcp.com 2> /dev/null || true) | tr -dc '0-9')"
  if [ -n "$old_cp" ] && [ "$old_cp" != 65001 ] && chcp.com 65001 > /dev/null 2>&1; then
    trap 'chcp.com "$old_cp" > /dev/null 2>&1 || true' EXIT
  fi
fi

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
  features)
    # Per operation and feature value: answers, % right, median time of the
    # right ones (Phase 5.1 commit 3). Per answer: owner_dashboard.answer_features.
    echo "select operation, feature, value, answers, correct_pct as \"right %\", median_ms_right as \"median ms (right)\" from owner_dashboard.feature_summary;" | run
    ;;
  weak-spots)
    # Phase 4 commit 7: every accepted session's payload, one per line,
    # replayed through the core's scheduler by a Dart tool (no new
    # dependency: psql exports, Dart reads stdin).
    command -v dart > /dev/null || { echo "dart not found: install the Dart SDK." >&2; exit 2; }
    echo "select payload::text from public.uploaded_sessions order by player_id, created_at;"       | psql "$url" -X -q -At -v ON_ERROR_STOP=1       | (cd "$here/../../packages/math_core" && dart run tool/weak_spots_report.dart)
    ;;
  duels)
    run < "$here/duels.sql"
    ;;
  review-run)
    need "${2:-}"
    [[ "$2" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "not a run id: $2" >&2; exit 2; }
    case "${3:-}" in
      ok) verdict=ok ;;
      reject) verdict=rejected ;;
      *) echo "verdict: ok or reject" >&2; exit 2 ;;
    esac
    echo "select owner_dashboard.review_run('$2', '$verdict') as found;" | run
    ;;
  usage)
    # The database against the free plan (Phase 6a commit 5): ALERT from 50 %.
    echo "select case when alert then 'ALERT: ' else '' end || percent || ' % of 500 MB' as used, pg_size_pretty(bytes) as database, pg_size_pretty(session_bytes) as \"stored games\", sessions as games from owner_dashboard.database_usage;" | run
    ;;
  moderation)
    # Who is hidden or banned, then every player with something to look at
    # over the last 30 days (Phase 6a commit 3).
    echo "select player_id, player, state, reason, to_char(decided_at, 'YYYY-MM-DD HH24:MI') as decided from owner_dashboard.moderation order by decided_at desc; select * from owner_dashboard.moderation_evidence limit 50;" | run
    ;;
  hide|ban)
    need "${2:-}"
    [[ "$2" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "not a player id: $2" >&2; exit 2; }
    state=hidden
    [ "$command" = ban ] && state=banned
    echo "select owner_dashboard.moderate('$2', '$state', $(literal "${3:-}")) as done;" | run
    ;;
  unhide)
    need "${2:-}"
    [[ "$2" =~ ^[0-9a-fA-F-]{36}$ ]] || { echo "not a player id: $2" >&2; exit 2; }
    echo "select owner_dashboard.unmoderate('$2') as lifted;" | run
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
