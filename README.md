# Gateway

A persistent, reproducible home for long-running agents that drive other agents
across hosts. Built to fit Tenstorrent IT's [on-premises Docker Compose hosting
model](https://tenstorrent.atlassian.net/wiki/spaces/IT/pages/1676378152/),
so IT's Terraform/Ansible can stand it up and we keep SSH self-serve access
afterwards.

## What's in the box

| Tool | Version | Why |
|---|---|---|
| Python | 3.13 (+ `uv`) | Agent runtime and scripting |
| git | Debian stable | Checkouts the agents operate on |
| tmux | Debian stable | Sessions that outlive our SSH connections |
| neovim | v0.12.5 (upstream tarball) | Editing on the box |
| herdr | v0.9.3 (pinned release) | Driving the agent fleet |
| tailscale | v1.90.8 | The agents' own tagged tailnet node |

Plus `ripgrep`, `fd`, `jq`, `rsync` and `openssh-client`, which anything doing
cross-host work needs anyway.

## Shape of the deployment

Two services:

- **`tailscale`** joins the tailnet as its own node, with state on the
  persistent volume so it keeps its identity across restarts.
- **`workbench`** runs a detached tmux server as PID-1-adjacent work under
  `tini`, and shares the tailscale container's network namespace.

That netns sharing is the important bit: every agent process inherits tailnet
DNS and the advertised subnet routes directly, so reachability doesn't depend on
how the VM host happens to be routing. It also means the agents get their own
ACL-taggable identity in the tailnet, separate from the VM.

One consequence worth knowing: because `workbench` lives in the `tailscale`
container's network namespace, restarting `tailscale` alone leaves the
workbench with a dead netns. Restart both together (`make restart`) rather than
the tailscale service by itself.

Nothing is exposed over HTTP — there's no nginx or oauth2-proxy here. Access is
Tailscale + Active Directory SSH to the VM, then `make attach`. If we ever want
a status dashboard, that's when the auth-proxy trio from the IT example repo
gets added.

## Persistence

All state lives under `$DATA_DIR` (IT provides the path on the VM's persistent
volume):

```
$DATA_DIR/tailscale   # tailnet node identity
$DATA_DIR/home        # agent credentials, ssh keys, shell + nvim config
$DATA_DIR/workspace   # git checkouts the agents work in
```

The image is disposable; this directory is not. It's what needs backing up.

## Local use

```sh
make setup        # writes .env from env.example
make local-build
make local-up
make local-attach # detach with the tmux prefix, then d
```

Local mode skips the tailnet node entirely, so no auth key is needed.

## On the VM

```sh
ssh <hostname>.<site>.tenstorrent.com
cd /srv/gateway
sudo git config --global --add safe.directory /srv/gateway   # one time
sudo git pull
sudo make build && sudo make up
make attach
```

`make doctor` prints the version of every tool in the image, which is the
quickest way to confirm a rebuild actually took.

## Reproducibility notes

Every third-party artifact is pinned by version and verified by SHA-256 at
build time. In particular, herdr is installed by fetching the pinned release
asset directly rather than piping `herdr.dev/install.sh` into a shell — that
installer always resolves "latest", which would make the image un-rebuildable.
`herdr update` still works inside the container for ad-hoc upgrades; bump
`HERDR_VERSION` and `HERDR_SHA256_*` in the Dockerfile to make one permanent.

To bump versions, the sources of truth are:

- herdr: `https://herdr.dev/latest.json` (carries both URL and sha256)
- neovim: GitHub releases, alongside each tarball's `.sha256sum`
