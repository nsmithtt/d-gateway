# IT hosting request — Gateway

Draft content for the application hosting request at
<https://tenstorrent.atlassian.net/servicedesk/customer/portal/95/group/105/create/353>.
Review and adjust the access lists before filing.

## Application

**Name:** gateway
**Repository:** git@github.com:nsmithtt/d-gateway.git
**Owner:** Nicholas Smith (nsmith@tenstorrent.com)

A persistent workbench for long-running orchestration agents that drive other
agents across hosts. It is **not a web application** — there is no HTTP surface,
so it needs no Entra application, no oauth2-proxy, and no TLS certificate.
Access is SSH over Tailscale, into a long-lived tmux session.

## Access controls

**Application users / SSH maintainers:** <names or AD group>

Everyone who can SSH to the VM can drive the agents, so these are the same
list. Keep it small.

## Tailscale

This is the one unusual ask. The workbench runs its **own tailnet node** inside
the compose project rather than relying on the VM host's Tailscale, so the
agents get an ACL-taggable identity distinct from the VM.

Needed:

- A **reusable, pre-approved, non-ephemeral** auth key, delivered via the
  Terraform/Ansible env file as `TS_AUTHKEY`.
- An ACL tag (e.g. `tag:gateway`) granting reachability to the network segments
  the agents must manage: <list the segments/hosts here>.
- `--accept-routes` is set, so any subnet routers covering those segments need
  to permit this tag.

## Persistent storage

Single persistent volume, path provided as `DATA_DIR`. Suggested **100 GB** to
start — mostly git checkouts and agent logs, which grow steadily over months.

```
$DATA_DIR/tailscale   # node identity  (tiny, but losing it re-auths the node)
$DATA_DIR/home        # agent credentials, ssh keys, config
$DATA_DIR/workspace   # git checkouts
```

**Backup:** `$DATA_DIR/home` and `$DATA_DIR/workspace` should be backed up.
The image and the repo are disposable.

## Resourcing

| | |
|---|---|
| CPU | 8 vCPU (agent fleets are bursty; mostly idle, spiky under load) |
| Memory | 16 GB VM; the workbench container is capped at 8 GB via `MEMORY_LIMIT` |
| Disk | 40 GB root + 100 GB persistent volume |
| Network | Modest bandwidth, but many long-lived outbound connections |
| Mounted filesystems | None required |

## Environment variables needed from IT

| Variable | Purpose |
|---|---|
| `TS_AUTHKEY` | Tagged Tailscale auth key (from 1Password) |
| `TS_HOSTNAME` | Tailnet node name; align with the VM hostname |
| `DATA_DIR` | Path to the persistent volume |
| `FQDN` | Assigned hostname (informational only) |
| `APP_UID` / `APP_GID` | uid/gid of the application account owning `/srv/gateway` |
| `ANTHROPIC_API_KEY` | Agent API credential (from 1Password) |

`APP_UID`/`APP_GID` matter: the container runs as a non-root `agent` user and
writes to bind-mounted state, so they must match the application account.

## Other notes

- No DNS or TLS requirements beyond the standard VM registration.
- Long-running processes are expected to persist across SSH disconnects; please
  don't configure anything that reaps idle user processes.
- Standard Zabbix monitoring is fine. Best-effort support is fine.
