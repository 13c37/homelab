#!/usr/bin/env bash
# Pull main and redeploy every stack whose files changed since the last successful deploy.
# Runs every 5 minutes via homelab-deploy.timer. Logs: journalctl -u homelab-deploy
set -euo pipefail

REPO=/opt/homelab
STATE=/var/lib/homelab-deploy/deployed     # last commit that deployed without errors
mkdir -p "$(dirname "$STATE")"
cd "$REPO"

git fetch -q origin main
git merge -q --ff-only origin/main         # refuses if someone edited files on the server
NEW=$(git rev-parse HEAD)
LAST=$(cat "$STATE" 2>/dev/null || echo "$NEW")
[ "$LAST" = "$NEW" ] && { echo "$NEW" > "$STATE"; exit 0; }

fail=0
for s in $(git diff --name-only "$LAST" "$NEW" -- stacks/ | cut -d/ -f2 | sort -u); do
  [ -f "stacks/$s/compose.yaml" ] || continue
  echo "deploying $s ($LAST -> $NEW)"
  extra=""
  [ "$s" = site ] && extra="--force-recreate"   # Caddy shares the sidecar's network namespace
  if ! (cd "stacks/$s" && docker compose pull -q && docker compose up -d --remove-orphans $extra); then
    echo "FAILED: $s" >&2; fail=1
  fi
done

# only remember the commit if everything came up; otherwise retry on the next run
[ "$fail" = 0 ] && echo "$NEW" > "$STATE"
exit "$fail"
