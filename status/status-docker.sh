#!/bin/sh
# Read-only status of the Docker LXC for the daily report.
# Only callable through a restricted SSH key (forced command), see hermes/README.md.
docker ps -a --format '{{.Names}}|{{.Status}}' | sort | while IFS='|' read -r n s; do
  case "$s" in
    *unhealthy*|Exited*|Restarting*|Dead*|Created*|Paused*) m="⚠️" ;;
    Up*) m="✅" ;;
    *) m="⚠️" ;;
  esac
  echo "$m $n: $s"
done
df -P / /media | awk 'NR>1 { p=$5+0; printf "%s disk %s: %s used\n", (p>=80?"⚠️":"✅"), $6, $5 }'
if systemctl is-failed -q homelab-deploy.service; then
  echo "⚠️ auto-deploy: FAILED (journalctl -u homelab-deploy)"
else
  echo "✅ auto-deploy: $(git -C /opt/homelab log -1 --format='%h %s')"
fi
n=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
echo "📦 OS updates pending: $n"
