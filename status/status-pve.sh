#!/bin/sh
# Read-only status of the Proxmox host for the daily report.
# Only callable through a restricted SSH key (forced command), see hermes/README.md.
DUMP=/mnt/hdd/backups/dump
pct list | awk 'NR>1 { printf "%s CT %s %s: %s\n", ($2=="running"?"✅":"⚠️"), $1, $NF, $2 }'
for id in $(pct list | awk 'NR>1 {print $1}'); do
  if [ -n "$(find "$DUMP" -name "vzdump-lxc-$id-*" -mtime -1 2>/dev/null | head -n1)" ]; then
    echo "✅ backup CT $id: within 24 h"
  else
    echo "⚠️ backup CT $id: none in the last 24 h"
  fi
done
lvs --noheadings -o data_percent pve/data | awk '{ p=$1+0; printf "%s SSD pool: %s%% used\n", (p>=80?"⚠️":"✅"), $1 }'
df -P /mnt/hdd | awk 'NR>1 { p=$5+0; printf "%s HDD: %s used\n", (p>=80?"⚠️":"✅"), $5 }'
n=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
echo "📦 Proxmox updates pending: $n"
