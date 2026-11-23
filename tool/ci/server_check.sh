#!/usr/bin/env bash
# Is <server> up to date with this checkout? (Levels close-out, step 2: after
# every push that changes the server or the core.) Read-only: one GET of
# /health, nothing written anywhere.
#
#   bash tool/ci/server_check.sh <server url>
#
# Up to date = the server's commit (/health `version`) has the same server/
# and packages/math_core/ as HEAD — what tool/ci/render_deploy.sh deploys on
# — and its `rules` list the rules new games are played under
# (`RulesVersion.current`). Otherwise: exit 1 and the owner's action. Until
# the server lists the current rules the app holds new games, pending, on
# the devices (nothing lost, nothing ranked).
set -euo pipefail

server="${1:?usage: server_check.sh <server url>}"
server="${server%/}"
root="$(git rev-parse --show-toplevel)"

if ! health="$(curl -fsS --max-time 120 "$server/health")"; then
  echo "$server/health did not answer (a free instance can take a minute to wake: retry)."
  exit 1
fi
version="$(sed -n 's/.*"version":"\([^"]*\)".*/\1/p' <<< "$health")"
rules="$(sed -n 's/.*"rules":\[\([^]]*\)\].*/\1/p' <<< "$health")"
current="$(sed -n 's/.*static const current = v\([0-9]*\);.*/\1/p' \
  "$root/packages/math_core/lib/leveling/rules_version.dart")"

echo "$server runs ${version:-?}, rules [${rules}]; HEAD $(git rev-parse --short=7 HEAD) plays rules v${current:-?}"
up_to_date=1
if [ -z "$version" ] || ! git cat-file -e "$version^{commit}" 2>/dev/null; then
  echo "- its commit is unknown here (fetch, or an old server without a version)"
  up_to_date=0
elif ! git diff --quiet "$version" HEAD -- server packages/math_core; then
  echo "- server/ or packages/math_core/ changed since $version: it needs a deploy"
  up_to_date=0
fi
case ",${rules// /}," in
  *",$current,"*) ;;
  *)
    echo "- rules v$current missing: new games stay pending on the devices, unranked"
    up_to_date=0
    ;;
esac

if [ "$up_to_date" = 1 ]; then
  echo "up to date"
  exit 0
fi
echo "OWNER ACTION: Render, the service, Manual Deploy, Deploy latest commit — or set the"
echo "deploy hook secret so CI deploys it (doc/plan.md section 10, doc/online.md)."
exit 1
