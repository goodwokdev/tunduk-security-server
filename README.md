# Tunduk Security Server (X-Road 7.4.2) — Docker Compose

Production single-VM deployment of a **Tunduk / СМЭВ «Түндүк»** security server,
built on the official, production-supported **NIIS X-Road Security Server Sidecar**.

## Two flavors

The same server, two ways to run it. Both share one contract: image
`niis/xroad-security-server-sidecar:7.4.2`, PostgreSQL 12, safe-by-default ports,
persistent state. The registration flow in [SETUP.md](SETUP.md) is identical.

| Flavor | Where | Use it for |
|---|---|---|
| **docker-compose** (root) | single VM | the reference flavor — simplest to read and stand up |
| **Helm chart** ([charts/tunduk-security-server](charts/tunduk-security-server)) | Kubernetes | single-instance, production-faithful deploy in a cluster |

Newcomer guide (RU): [docs/guide-for-newcomers.md](docs/guide-for-newcomers.md).

## Why no custom image

The Tunduk apt repo (`deb.tunduk.kg/ubuntu22.04-7.4.2`) ships **byte-identical
upstream NIIS packages** — same maintainer (`NIIS <info@niis.org>`) and same git
hash (`gita30be58`) across all 28 packages. There is no `tunduk-*` package.

So a server only becomes "Tunduk" through **runtime configuration** — the global
configuration **anchor** that points it at Tunduk's central server — not through
the binary. We therefore consume `niis/xroad-security-server-sidecar:7.4.2`
directly and load the anchor during setup. Less code, no service-mapping to
maintain, upstream security fixes via `docker pull`.

> ⚠️ Use the **full** `7.4.2` tag, never `-slim`: slim drops message logging,
> which Tunduk requires (3-year log retention is a legal obligation).

## Stack

| Service | Image | Purpose |
|---|---|---|
| `security-server` | `niis/xroad-security-server-sidecar:7.4.2` | X-Road SS (supervisord runs proxy, signer, confclient, proxy-ui-api, monitor, opmonitor, messagelog) |
| `db` | `postgres:12` | serverconf + messagelog DB. **PG 12** — must match the image's bundled major or backup/restore breaks. |

State lives in three named volumes: `xroad-config` (`/etc/xroad`),
`xroad-archive` (`/var/lib/xroad`), `pgdata`.

## Quick start

```bash
cp .env.example .env        # then edit: PIN, admin creds, DB password
docker compose up -d
docker compose ps           # wait until both services are healthy
```

Then open the admin UI and complete provisioning — **see [SETUP.md](SETUP.md)**.
The compose stack gives you a *running but unconfigured* server; registration
(anchor, keys, CA-signed certs, subsystem) is a guided sequence in SETUP.md.

UI is bound to loopback by default. Reach it via SSH tunnel:

```bash
ssh -L 4000:127.0.0.1:4000 <vm-host>
# browse https://localhost:4000  (self-signed cert)
```

## Files

```
docker-compose.yml   two-service stack (SS + Postgres 12)
.env.example         secrets/ports template -> copy to .env
backup/backup.sh     pg_dumpall + tar of both xroad volumes (cron-friendly)
SETUP.md             end-to-end provisioning runbook
```

## Prerequisites (host)

- Linux VM **physically located in Kyrgyzstan** (Tunduk requirement).
- Dedicated to X-Road — owns the published ports; do not co-locate another web server.
- Docker Engine + Compose v2.
- Min 4 GB RAM, 100 GB free disk (message-log growth).
- Network: see SETUP.md "Firewall / ports".

## Operations

- **Logs:** `docker compose logs -f security-server`
- **Restart X-Road services:** `docker compose restart security-server`
  (also the fix when OCSP status is stuck on `Unknown`)
- **Backup:** `backup/backup.sh` (schedule via cron) — copy output off-box.
- **Upgrade image:** bump the tag, `docker compose pull && up -d`. The entrypoint
  migrates config on start. Back up first.
