#!/bin/sh
# ~/.hermes/scripts/homelab-report.sh: daily status report, delivered to Telegram by a Hermes cron job.
# Pure script, no LLM, so it also runs while the gaming PC (LM Studio) is off.
# The SSH key is restricted to one forced command per host, so this can only READ status.
DOCKER_IP="<docker-ip>"   # fill in
PVE_IP="<pve-ip>"         # fill in
K=/root/.ssh/homelab_status
O="-i $K -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new"
echo "🏠 homelab · $(date '+%a %d.%m. %H:%M')"
echo; echo "— docker —"
ssh $O "root@$DOCKER_IP" 2>/dev/null || echo "⚠️ docker LXC unreachable"
echo; echo "— proxmox —"
ssh $O "root@$PVE_IP" 2>/dev/null || echo "⚠️ Proxmox host unreachable"
echo; n=$(curl -fsS --max-time 10 https://api.github.com/repos/13c37/homelab/pulls | grep -c '"number":')
echo "🔀 open Renovate PRs: ${n:-?}"
