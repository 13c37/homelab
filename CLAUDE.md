# homelab: instructions for claude code

this repo is the source of truth for my proxmox homelab. architecture, design decisions and restore steps are in [README.md](README.md); the agent lxc is described in [hermes/README.md](hermes/README.md).
environment-specific details (ips, backup job, current inventory) are in `CLAUDE.local.md` (gitignored, local only).

## rules

1. **read-only by default.** inspect freely (`pct list`, `pct config`, `docker ps`, logs, `df`, …). ask before every change, however small.
2. **snapshot before changing a ct:** `pct snapshot <id> pre-<task>` (ct rootfs are on `local-lvm` = lvm-thin).
   - **ct 100 cannot be snapshotted** (proxmox doesn't support snapshots with the host bind mount `mp0`). take a fresh backup instead: `vzdump 100 --storage hdd-backups --mode snapshot --compress zstd` (no downtime, ~3.5 gb, ~2 min).
   - snapshots use the small ssd thin pool. delete them after the task (`pct delsnapshot <id> pre-<task>`), but only after i confirm.
   - if neither is possible, say so and give the latest backup: `pvesm list hdd-backups | grep lxc-<id>`.
3. **never without my explicit ok:** reboot/shutdown (host or ct), `pct stop`, deleting volumes/disks/backups/snapshots, `docker volume rm` / `docker system prune`, changes to firewall, network, bridges, dns, tailscale.
4. **ssh keys only.** never type, store, read out or forward passwords. don't print secrets (`.env`, `~/.hermes/.env`, `auth.json`, tailscale keys).
5. **git: commit only as `13c37 <69517127+13c37@users.noreply.github.com>`**, no co-author/claude attribution.
   - **push without asking** when nothing can go down: docs, `.gitignore`, ci, read-only status scripts, small compose changes to non-critical stacks (homepage, uptime-kuma). say afterwards what was pushed.
   - **ask before push** for anything that can take down the server, dns or the network: the adguard stack (every redeploy = short lan dns outage), the site stack (public site), jellyfin/adguard image bumps, network/firewall/tailscale, `deploy/`. never force-push or rewrite history without asking.
   - **delete branches without asking** once their pr is merged into `main` and everything is fine (deploy ran, stack healthy): local and remote. ask before deleting unmerged branches. say afterwards what was deleted.
6. **stacks are gitops.** change compose files here → push/pr → merge to `main`; ct 100 deploys on its own (`deploy/`, timer every 5 min, `git merge --ff-only`). **never edit files in `/opt/homelab` on the server**: that breaks the ff-only deploy. merging to `main` = deploying.
7. **site stack:** always `docker compose up -d --force-recreate` (caddy shares the namespace of the tailscale sidecar).
8. **this repo is public:** never commit ips, hostnames from the lan, tailnet names or secrets. those go in `.env` (server) or `CLAUDE.local.md` (here).

## writing style: lowercase only

everything you write in this repo is lowercase: commit messages, pr titles and bodies, issue and review comments, readmes and other docs, headings, changelog entries.
- this includes names and acronyms: proxmox, docker, github, dns, lxc, ci, pr.
- keep the original case only where changing it would break something: code, identifiers (`homelab-deploy`), file names and paths, commands, env vars, urls, and anything inside `backticks` or code blocks.
- commits: conventional commits, lowercase subject, e.g. `fix(site): recreate caddy with the ts sidecar`.

## access

| target | command |
|---|---|
| proxmox host | `ssh pve` (root) |
| ct 100 `docker` | `ssh pve 'pct exec 100 -- <cmd>'` |
| ct 101 `hermes` | `ssh pve 'pct exec 101 -- <cmd>'` |

## layout on the server

- ct 100: repo checkout at `/opt/homelab`, `/opt/stacks` → `/opt/homelab/stacks`. runtime data (`config/`, `data/`, `conf/`, `work/`, `ts-state/`, `www/`) and `.env` live only on the server.
- deploy logs: `journalctl -u homelab-deploy` (ct 100). agent logs: `journalctl -u hermes-gateway` (ct 101).
- backups: vzdump on `hdd-backups` (`/mnt/hdd/backups/dump`), see `/etc/pve/jobs.cfg`.

## quick status

```bash
ssh pve 'pveversion; pct list; pvesm status; pct exec 100 -- docker ps -a'
ssh pve 'pvesm list hdd-backups | tail -4; lvs pve/data; systemctl --failed --no-legend'
```
