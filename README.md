# homelab

My home server: an old desktop PC turned into a small Proxmox host that runs DNS filtering, media streaming, monitoring, a file share, a public website and a private AI agent — without opening a single port on the router.

## Hardware

**Server:** a repurposed office desktop: 2-core Intel CPU with integrated GPU (Quick Sync), 16 GB RAM, an SSD for the system and an HDD for media and backups.

**LLM inference:** my main PC runs LM Studio as the model backend for the agent — the server itself has no GPU worth using for that.

## Architecture

```mermaid
flowchart LR
  internet((Internet)) -->|HTTPS| funnel[Tailscale Funnel]
  phone[Phone / laptop<br>on Tailscale] --> ts[Tailscale]
  lan[LAN clients] -->|DNS :53| adg
  lan -->|SMB| smb

  tgapp[Telegram<br>on phone] <--> tg[(Telegram)]

  subgraph pve[Proxmox VE]
    ts
    subgraph hct[LXC 'hermes' · Debian 13]
      hermes[Hermes Agent<br>gateway]
    end
    subgraph ct[Docker LXC · Debian · unprivileged]
      adg[AdGuard Home]
      jf[Jellyfin<br>iGPU transcoding]
      kuma[Uptime Kuma]
      hp[Homepage]
      smb[Samba share 'media']
      subgraph site[site stack]
        sts[Tailscale sidecar] --> caddy[Caddy]
      end
    end
  end

  funnel --> sts
  adg -->|DNS-over-HTTPS| quad9[(Quad9)]
  hdd[(HDD)] --- jf
  hdd --- smb
  hermes <-->|outbound polling| tg
  hermes -->|OpenAI API, LAN| lms[LM Studio<br>on gaming PC]
```

## Services

| Service | Purpose | Access |
|---|---|---|
| [AdGuard Home](stacks/adguard) | Network-wide ad/tracker/malware blocking; upstream Quad9 via DNS-over-HTTPS | LAN DNS (`:53`), web UI LAN-only |
| [Jellyfin](stacks/jellyfin) | Media server with Intel Quick Sync hardware transcoding | LAN + Tailscale |
| [Uptime Kuma](stacks/uptime-kuma) | Uptime monitoring of all services incl. the public site | `:3001`, LAN + Tailscale |
| [Homepage](stacks/homepage) | Dashboard with links and live status | `:3010`, LAN |
| [site](stacks/site) | Static website, public via Tailscale Funnel, served by Caddy | Internet (HTTPS) |
| [Samba](samba/smb.conf) | `media` share for Windows, dedicated user, no guest access | LAN |
| [Hermes Agent](hermes) | Self-hosted AI agent, local model (Gemma 4 12B QAT) via LM Studio on the gaming PC, chat through a private Telegram bot | Telegram (allowlisted user only) |
| Proxmox backups | Nightly backup of the Docker LXC and the agent LXC to the HDD | — |

## Layout

```
proxmox/docker-lxc.conf LXC definition (unprivileged, nesting, iGPU passthrough, HDD bind mount)
samba/smb.conf          file share config
docker/daemon.json      Docker daemon settings inside the LXC (log rotation)
deploy/                 auto-deploy: script + systemd timer (merge to main = deploy)
status/                 read-only status scripts for the agent's daily report
.github/workflows/      CI: secret scan (gitleaks) + compose file validation
hermes/                 AI agent LXC: setup notes + non-secret config examples
stacks/<service>/       one docker compose stack per service (/opt/stacks/<service> on the server)
```

Runtime data (`config/`, `data/`, `ts-state/`, …), `.env` files and the website content are not part of the repo.

## Design decisions

- **One unprivileged LXC with Docker** instead of a VM per service: far less RAM overhead on a 2-core CPU; `nesting=1` + `keyctl=1` make Docker work inside the container.
- **iGPU passthrough into the LXC** (`dev0: /dev/dri/renderD128`) and `group_add: 992` in the Jellyfin stack → hardware transcoding instead of maxing out the CPU.
- **Host networking** for AdGuard (DNS on port 53 for the whole LAN) and Jellyfin (client auto-discovery); everything else uses normal port mappings.
- **Public website without port forwarding:** a Tailscale container in userspace mode publishes the site through Tailscale Funnel with automatic HTTPS. The home IP stays hidden, it works behind DS-Lite/CGNAT, and the stack is isolated from the other services.
- **Pinned image versions + Renovate PRs** instead of `latest`: no surprise breakage from a random `docker compose pull`, every update is reviewed with its changelog and can be rolled back by reverting one commit.
- **Bounded Docker logs** ([docker/daemon.json](docker/daemon.json)): the default log driver grows without limit and would eventually fill the 30 GB container disk; `local` driver, 3 × 10 MB per container.
- **Media is read-only for Jellyfin**; writes only go through the Samba share.
- **AI agent in its own LXC, model on the gaming PC:** the agent can run commands, so it's isolated from the Docker services; inference runs on the 16 GB GPU over the LAN instead of on the 2-core server. Details in [hermes/](hermes).

## Problems I ran into (and fixed)

**1. DNS loop in the LXC** — Docker could not pull images (`lookup registry-1.docker.io: i/o timeout`).
The LXC inherited the host's resolver, which after installing Tailscale on the host was MagicDNS (`100.100.100.100`) — only reachable on the host itself.
*Fix:* pinned the LXC's DNS to Quad9 via `pct set <id> --nameserver …`, restarted Docker. The server no longer depends on its own AdGuard to resolve names.

**2. Windows 11 refused the SMB share** — "organization's security policies block unauthenticated guest access".
Current Windows 11 blocks guest SMB logons; a wrong username was silently mapped to guest (`map to guest = Bad User`).
*Fix:* proper Samba password for the share user, `map to guest = never`, credentials stored in Windows Credential Manager. No Windows security settings were weakened.

**3. Website unreachable after renaming the node** — Caddy uses `network_mode: service:site-ts`; recreating only the Tailscale container left Caddy attached to the old network namespace.
*Fix:* always recreate the whole stack (`docker compose up -d --force-recreate`).

## Roadmap

- [ ] Vaultwarden (password manager)
- [x] Pin image versions instead of `latest`, update via a reviewed process (Renovate)
- [ ] Internal HTTPS for LAN services through Caddy
- [x] Restrict the LM Studio port on the PC to the agent LXC only (Windows Firewall)
- [x] Docker log rotation, CI secret scan + compose validation, security headers for the site
- [x] Auto-deploy on merge (GitOps via systemd timer)

**Not doing (accepted risk):** off-site copy of the backups. They live on the same machine, so a dead HDD, theft or fire means losing them together with the original.

## Restore

Backups are Proxmox `vzdump` archives. On the Proxmox host:
```bash
pvesm list <backup-storage> --content backup          # find the archive
pct restore <new-id> <backup-storage>:backup/vzdump-lxc-<id>-<date>.tar.zst --storage local-lvm
pct start <new-id>
```
Restoring under a **new** ID first lets me test a backup without touching the running container (`pct destroy <new-id>` afterwards). Worth repeating every few months — an untested backup is only a guess.

## Deployment (GitOps)

The server runs a checkout of this repo at `/opt/homelab` (`/opt/stacks` is a symlink to `stacks/`). A systemd timer ([deploy/](deploy)) checks `main` every 5 minutes and redeploys **only the stacks whose files changed**:

```
Renovate PR → CI (secret scan + compose validation) → I review & merge → server pulls → docker compose up -d
```

- Nothing is merged automatically, so the review step stays the gate; merging *is* deploying.
- `git merge --ff-only`: if a file was edited by hand on the server, the deploy stops instead of overwriting it.
- A failed stack is retried on the next run; logs: `journalctl -u homelab-deploy`.

Server-specific values (Tailscale auth key, node name, allowed hosts) live in each stack's `.env` (see `.env.example`), the website content in `stacks/site/www/` — both stay on the server only.

**Updates:** every image is pinned to an exact version. [Renovate](renovate.json) checks weekly and opens a pull request per update (patch updates grouped).

**New stack / first start:** `cp .env.example .env`, fill it in, `chmod 600 .env`, `docker compose up -d`. For the site stack, enable HTTPS + Funnel in the Tailscale admin console first.
