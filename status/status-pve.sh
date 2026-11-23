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
echo "💾 Devices and drives"
df -P -B1 / | awk 'function f(b,  v,u,s){ v=b/1073741824; u="GB"; if(v>=1000){v/=1024; u="TB"}
  s=sprintf(v>=100?"%.0f":(v>=10?"%.1f":"%.2f"), v); sub(/\./, ",", s); return s " " u }
  NR>1 { p=$5+0; printf "%s Proxmox system (/): %s free of %s\n", (p>=80?"⚠️":"✅"), f($4), f($2) }'
lvs --noheadings --units b --nosuffix -o lv_size,data_percent pve/data | awk 'function f(b,  v,u,s){ v=b/1073741824; u="GB"; if(v>=1000){v/=1024; u="TB"}
  s=sprintf(v>=100?"%.0f":(v>=10?"%.1f":"%.2f"), v); sub(/\./, ",", s); return s " " u }
  { p=$2+0; printf "%s SSD pool (containers): %s free of %s\n", (p>=80?"⚠️":"✅"), f($1*(100-p)/100), f($1) }'
df -P -B1 /mnt/hdd | awk 'function f(b,  v,u,s){ v=b/1073741824; u="GB"; if(v>=1000){v/=1024; u="TB"}
  s=sprintf(v>=100?"%.0f":(v>=10?"%.1f":"%.2f"), v); sub(/\./, ",", s); return s " " u }
  NR>1 { p=$5+0; printf "%s HDD (media + backups): %s free of %s\n", (p>=80?"⚠️":"✅"), f($4), f($2) }'
n=$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l)
echo "📦 Proxmox updates pending: $n"
