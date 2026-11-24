# Homelab: instructions for Claude Code

This repo is the source of truth for my Proxmox homelab. Architecture, design decisions and restore steps are in [README.md](README.md); the agent LXC is described in [hermes/README.md](hermes/README.md).
Environment-specific details (IPs, backup job, current inventory) are in `CLAUDE.local.md` (gitignored, local only).

## Rules

1. **Read-only by default.** Inspect freely (`pct list`, `pct config`, `docker ps`, logs, `df`, …). Ask before every change, however small.
2. **Snapshot before changing a CT:** `pct snapshot <id> pre-<task>` (CT rootfs are on `local-lvm` = LVM-thin, so snapshots work).
   - The bind mount `mp0` (media on the HDD) is **not** in the snapshot. Say so if the change touches media.
   - Snapshots use the small SSD thin pool. Delete them after the task (`pct delsnapshot <id> pre-<task>`), but only after I confirm.
   - If a snapshot isn't possible, say so and give the latest backup: `pvesm list hdd-backups | grep lxc-<id>`.
3. **Never without my explicit OK:** reboot/shutdown (host or CT), `pct stop`, deleting volumes/disks/backups/snapshots, `docker volume rm` / `docker system prune`, changes to firewall, network, bridges, DNS, Tailscale.
4. **SSH keys only.** Never type, store, read out or forward passwords. Don't print secrets (`.env`, `~/.hermes/.env`, `auth.json`, Tailscale keys).
5. **Git: commit only as `13c37 <69517127+13c37@users.noreply.github.com>`**, no co-author/Claude attribution. Ask before push.
6. **Stacks are GitOps.** Change compose files here → push/PR → merge to `main`; CT 100 deploys on its own (`deploy/`, timer every 5 min, `git merge --ff-only`). **Never edit files in `/opt/homelab` on the server**: that breaks the ff-only deploy. Merging to `main` = deploying.
7. **Site stack:** always `docker compose up -d --force-recreate` (Caddy shares the namespace of the Tailscale sidecar).
8. **This repo is public:** never commit IPs, hostnames from the LAN, tailnet names or secrets. Those go in `.env` (server) or `CLAUDE.local.md` (here).

## Access

| Target | Command |
|---|---|
| Proxmox host | `ssh pve` (root) |
| CT 100 `docker` | `ssh pve 'pct exec 100 -- <cmd>'` |
| CT 101 `hermes` | `ssh pve 'pct exec 101 -- <cmd>'` |

## Layout on the server

- CT 100: repo checkout at `/opt/homelab`, `/opt/stacks` → `/opt/homelab/stacks`. Runtime data (`config/`, `data/`, `conf/`, `work/`, `ts-state/`, `www/`) and `.env` live only on the server.
- Deploy logs: `journalctl -u homelab-deploy` (CT 100). Agent logs: `journalctl -u hermes-gateway` (CT 101).
- Backups: vzdump on `hdd-backups` (`/mnt/hdd/backups/dump`), see `/etc/pve/jobs.cfg`.

## Quick status

```bash
ssh pve 'pveversion; pct list; pvesm status; pct exec 100 -- docker ps -a'
ssh pve 'pvesm list hdd-backups | tail -4; lvs pve/data; systemctl --failed --no-legend'
```
