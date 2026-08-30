# Homelab

## Prerequisites

I run my development and homelab environments on Fedora, so all of my assumptions are based on using
[Podman Quadlets](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) to implement the services.

```
❯ sudo dnf install podman ansible-core ansible-lint
❯ ansible-galaxy collection install -r requirements.yml
❯ git config core.hooksPath .githooks
```

`git config core.hooksPath .githooks` points Git at the `.githooks/` directory so `ansible-lint` runs automatically
before each commit. Run `ansible-lint` to lint on demand.

## Deployment

Everything is deployed with Ansible, run from the laptop with `ansible-playbook` against any target in
`inventory/hosts.yml`. Nothing gets placed on a host by hand — if a file needs to exist on a target, Ansible puts it
there.

### Hosts

| Host | Connection | Role in the homelab |
| --- | --- | --- |
| `laptop` | local | Daily driver. OS baseline and backups, nothing else. |
| `media` | SSH (tailnet) | The homelab box. Runs every container, plus the Git server. |
| `outpost` | SSH (tailnet) | VPS. Runs the Postfix relay. |

Connection details are declared once at the top of `inventory/hosts.yml`. The groups underneath describe what a host
*does* rather than where it sits, so playbooks target a capability instead of a machine name and a host can belong to
several groups:

| Group | Members | Meaning |
| --- | --- | --- |
| `workstations` | `laptop` | Daily drivers — baseline and backups only |
| `quadlet_hosts` | `media` | Runs the Podman Quadlet container stack |
| `git_servers` | `media` | Hosts a bare-repo Git server over `git-shell` |
| `mail_servers` | `outpost` | Runs the Postfix relay |

Adding a second container box is therefore an inventory edit, not a playbook edit.

### Playbooks

Three playbooks, all run from the laptop against `inventory/hosts.yml`.

**`system.yml`** — host OS baseline. Three plays:

| Play | Hosts | Roles | What it does |
| --- | --- | --- | --- |
| System baseline | `all` | `system`, `restic` | Third-party repos, packages, Tailscale, admin user, restic backups |
| Mail server | `mail_servers` | `mail` | Postfix relay with TLS and postgrey |
| Git server | `git_servers` | `git` | `git-shell` user and bare-repo directory |

**`homelab.yml`** — the containers. Two plays, both against `quadlet_hosts`:

| Play | Roles | What it does |
| --- | --- | --- |
| Configure host OS | `quadlet_host` | Creates the `homelab` user, enables linger, sysctl, firewall ports, machinectl Polkit rule, Justfile toolchain |
| Install Podman Quadlets | `quadlets` | Deploys quadlet files, env files and configs, then starts the services |

Both plays connect as root and step down to the `homelab` user with `become_user`, talking to that user's session bus
via `DBUS_SESSION_BUS_ADDRESS` and `XDG_RUNTIME_DIR`.

**`site.yml`** — imports `system.yml` then `homelab.yml`, in that order. The "everything" entry point.

### What applies where

| | `laptop` | `media` | `outpost` |
| --- | :---: | :---: | :---: |
| `system` | ✅ | ✅ | ✅ |
| `restic` | ✅ | ✅ | ✅ |
| `git` | | ✅ | |
| `mail` | | | ✅ |
| `quadlet_host` | | ✅ | |
| `quadlets` | | ✅ | |

### Commands

| Command | What it does | Hosts touched |
| --- | --- | --- |
| `ansible-playbook system.yml` | host OS baseline + backups | all three |
| `ansible-playbook homelab.yml` | host setup + containers | `media` — targets `quadlet_hosts` |
| `ansible-playbook site.yml` | both, in order | all three |
| `ansible-playbook site.yml --check` | dry run | all three |

Add `--limit <host>` to scope any of these to one host; without it the playbook runs against every host it targets.
`homelab.yml` already targets `quadlet_hosts`, so `--limit media` changes nothing there today.

Which containers run on a host comes from `enabled_services` in `host_vars/<host>.yml` — the `quadlets` role only
touches services in that list.

### First-time setup

**1. Prepare the vault password**

Secrets live as inline `!vault` blocks in `group_vars/all/main.yml`. Ansible finds the password via `ansible.cfg`:

```
❯ echo 'yourpassword' > ~/.ansible/vault_pass && chmod 600 ~/.ansible/vault_pass
```

To add or change a secret, encrypt the value and paste the resulting block into `group_vars/all/main.yml`:

```
❯ ansible-vault encrypt_string --stdin-name 'cloudflare_api_key'
```

Type the value, then press Ctrl-D **without** hitting Enter first — a trailing newline gets baked into the encrypted
value and will silently break authentication later.

**2. Provision**

```
❯ ansible-playbook site.yml                 # system + homelab, all hosts
❯ ansible-playbook site.yml --limit media   # single host
```

Or run the halves separately: `ansible-playbook system.yml` (host OS, backups) and `ansible-playbook homelab.yml`
(the quadlets).

### Day-to-day

After changing a `.container` file, a config, or a secret:

```
❯ ansible-playbook homelab.yml
```

### Dry run

```
❯ ansible-playbook site.yml --check --limit media
```

## Configuration

A service that needs a config directory gets one at `~/.config/<service>`, bind-mounted into the container.

Static config files live in `roles/quadlets/files/config/<service>/` and are deployed by Ansible — no manual copying.
Traefik is the exception: its static config is templated from `roles/quadlets/templates/config/traefik/traefik.yaml.j2`.
It requests a wildcard `*.${domain}` certificate from Let's Encrypt via a Cloudflare DNS-01 challenge; the Cloudflare
credentials come from `traefik.env` and the ACME account address from the vaulted `traefik_email`.

When a `.container`, `.env`, drop-in, or config file changes, `ansible-playbook homelab.yml` restarts the affected
service on its own — no manual `just restart` needed. (Changes to the shared network or the shared `container.d` /
`service.d` drop-ins are the exception: they touch every container, so bounce those by hand.)

## Environment Variables

Environment variables are defined in one of two places.

Variables that apply to every container (e.g. `DOMAIN`, device paths) come from
`roles/quadlets/templates/homelab-env.conf.j2`, which Ansible renders to `~/.config/environment.d/homelab.conf`. These
are available to systemd itself, so they can be used in directives that end up in the generated `.service` file.

Variables specific to one container (e.g. API keys) come from `roles/quadlets/templates/env/<service>/<service>.env.j2`,
rendered to `<service>.env` alongside the quadlet and pulled in via `EnvironmentFile=./%N.env`. Each `.container` file
documents the variables it expects, either by using them or in a comment. These are only available inside the running
container.

**Secrets go in the vault, never in a file on disk.** The `.env.j2` templates are committed and contain nothing but
Jinja references to vault-encrypted variables; the rendered `.env` files are never committed. `.gitignore` blocks
`*.env` across the whole repo so a plaintext env file cannot be added by accident.

> I used to keep the real values in unversioned `system/<service>.env` files, reasoning that Podman secrets were more
> machinery than I needed. They turned out not to be unversioned: the `.gitignore` pattern (`system/*.env`) contains a
> slash in the middle, which anchors it to the repository root, so it never matched
> `roles/quadlets/files/system/*.env`. Git had been tracking them the whole time, and they went to a public branch.
> Hence the vault, the blanket `*.env` rule, and the `.env.j2` suffix.

## Backup

A benefit of using rootless containers is that all the data that needs to be backed up exists in the user's home
directory, either in `~/.config` or `~/.local`. For example, the data for Podman volumes can be found in
`~/.local/share/containers/storage/volumes/systemd-<service>/_data`. One method of backing up the volume data is to save
the tarballs created by `podman volume export`. However, for my purposes, I've chosen to just back up `~homelab` and
call it a day. This doesn't account for things like open SQLite databases, but I haven't had any problems backing up and
restoring the data from all of my containers so far (knocking on wood).

I use [Restic](https://restic.net/) to back up to my [Synology NAS](https://www.synology.com/) and
[Backblaze B2](https://www.backblaze.com/cloud-storage).

## Image Updates

The shared `container.d/homelab.conf` drop-in labels every container `AutoUpdate=registry`, but updates are **not**
scheduled: `roles/quadlets/tasks/system.yml` masks `podman-auto-update.timer` so nothing changes on its own. Updates
are pulled by hand from the Ansible-deployed `~homelab/Justfile`:

```
❯ just updates      # show which images have a newer digest
❯ just update <svc> # update one service
❯ just update-all   # update everything
```

Host OS packages are updated by hand too — there is no `dnf-automatic`.

## Miscellanea

The `homelab` user is in the `dialout` group and the zwave-js-ui / home-assistant units get the serial devices via
`AddDevice=` drop-ins plus `SecurityLabelDisable=true`, which is normally enough. If the container still can't open
`/dev/zwave` after a controller reseat (the `/dev/ttyUSB*` node can come back with tighter perms), widen access as a
stopgap:

```
❯ sudo chmod o+rw /dev/ttyUSB?
```

To configure local TLS certificates for use with testing Traefik, on the host as the `homelab` user (`just` recipes
live in the Ansible-deployed `~homelab/Justfile`):

```
❯ just mkcert localhost
```

## iSponsorBlockTV

Note the device code by opening the YouTube app on the TV and navigating to `Settings > Link with TV code`. Then, on the
host running the service and as the `homelab` user, launch the interactive setup:

```
❯ just initialize-isponsorblocktv
```

This writes to `~/.config/isponsorblocktv`, which the container bind-mounts as `/app/data`.

<https://github.com/dmunozv04/iSponsorBlockTV/wiki/Installation>

To install the Jellyfin app on a Samsung TV:

```
❯ just install-jellyfin <ip-of-tv>
```

<https://github.com/Georift/install-jellyfin-tizen>
