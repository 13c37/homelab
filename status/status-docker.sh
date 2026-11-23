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
echo "💾 Devices and drives"
df -P -B1 / | awk 'function f(b,  v,u,s){ v=b/1073741824; u="GB"; if(v>=1000){v/=1024; u="TB"}
  s=sprintf(v>=100?"%.0f":(v>=10?"%.1f":"%.2f"), v); sub(/\./, ",", s); return s " " u }
  NR>1 { p=$5+0; printf "%s Docker LXC (/): %s free of %s\n", (p>=80?"⚠️":"✅"), f($4), f($2) }'
if systemctl is-failed -q homelab-deploy.service; then
  echo "⚠️ auto-deploy: FAILED (journalctl -u homelab-deploy)"
else
  echo "✅ auto-deploy: $(git -C /opt/homelab log -1 --format='%h %s')"
fi
n=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
echo "📦 OS updates pending: $n"
