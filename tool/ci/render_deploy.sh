#!/usr/bin/env bash
# Deploys one Render service at this commit, then waits until it runs it
# (Phase 5.2 commit 1). CI calls it for staging, then — after the staging
# smoke test — for production.
#
#   RENDER_DEPLOY_HOOK=<secret hook url> tool/ci/render_deploy.sh <server url> <sha>
#
# - The server's /health names the commit it runs (Phase 5.1): when neither
#   server/ nor packages/math_core/ changed since that commit, nothing is
#   deployed (the Docker build takes minutes).
# - Otherwise the deploy hook is called with `ref=<sha>` (that commit, not
#   whatever main is by then), and /health is polled until it answers with
#   it — at most 20 minutes (a free instance builds slowly, wakes slowly).
# - No hook while a deploy is needed: a warning, and nothing deployed (the
#   services do not deploy by themselves any more: render.yaml, autoDeploy
#   false) — the owner adds the hooks with staging (doc/online.md).
# The hook URL is a secret: never printed (GitHub masks it too).
set -euo pipefail

server="${1:?usage: render_deploy.sh <server url> <sha>}"
sha="${2:?usage: render_deploy.sh <server url> <sha>}"
short="${sha::7}"
server="${server%/}"

running() {
  curl -fsS --max-time 120 "$server/health" 2>/dev/null \
    | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' || true
}

current="$(running)"
echo "server $server runs: ${current:-unknown}; this commit: $short"
if [ "$current" = "$short" ]; then
  echo "already running this commit"
  exit 0
fi
if [ -n "$current" ] && git cat-file -e "$current^{commit}" 2>/dev/null \
  && git diff --quiet "$current" "$sha" -- server packages/math_core; then
  echo "server and core unchanged since $current: no deploy"
  exit 0
fi

if [ -z "${RENDER_DEPLOY_HOOK:-}" ]; then
  # A warning, not a failure: until the owner adds the hook, the site still
  # deploys (the server keeps its previous commit, or Render's own deploy).
  echo "::warning title=Render deploy::$server should run $short, but its deploy hook secret is not set: not deployed (doc/online.md, Staging)."
  exit 0
fi
case "$RENDER_DEPLOY_HOOK" in
  *\?*) hook="$RENDER_DEPLOY_HOOK&ref=$sha" ;;
  *) hook="$RENDER_DEPLOY_HOOK?ref=$sha" ;;
esac
if ! curl -fsS -X POST --max-time 60 "$hook" > /dev/null; then
  echo "::error title=Render deploy::the deploy hook for $server was refused (check the secret)."
  exit 1
fi
echo "deploy of $short requested"

for _ in $(seq 1 60); do
  sleep 20
  now="$(running)"
  if [ "$now" = "$short" ]; then
    echo "$server runs $short"
    exit 0
  fi
done
echo "::error title=Render deploy::$server still runs ${now:-nothing} 20 minutes after the deploy of $short was requested."
exit 1
