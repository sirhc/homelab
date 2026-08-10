# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is the **single source of truth** for all homelab devices and configuration. Everything needed to manage, configure, and deploy any device should live here.

Homelab infrastructure managed with **rootless Podman Quadlets** on Fedora. Services are defined as systemd-style `.container` files and orchestrated via `systemctl --user`. All deployment and configuration is managed through **Ansible**; **Just** wraps the common invocations.

Nothing is placed on a host by hand. If a file needs to exist on a target, Ansible puts it there.

## Prerequisites

```bash
sudo dnf install podman just ansible-core ansible-lint
ansible-galaxy collection install -r requirements.yml
echo 'yourpassword' > ~/.ansible/vault_pass && chmod 600 ~/.ansible/vault_pass
just install-hooks   # enables the ansible-lint pre-commit hook
```

The vault password file path is `~/.ansible/vault_pass` (configured in `ansible.cfg`).

## Common Commands

```bash
just update <host>        # Run system.yml   (host omitted = all hosts)
just deploy <host>        # Run homelab.yml
just provision <host>     # Run site.yml — system + homelab
just check <host>         # Dry-run site.yml
just lint                 # Run ansible-lint
just list-services        # List all services with descriptions
```

Linting is configured by two files. `.ansible-lint` sets exclusions and the rule skip list; `.yamllint` pins the YAML style. The `.yamllint` file exists so a developer's personal `~/.config/yamllint/config` can't override repo style — without it `ansible-lint` disables `--fix` and rejects `{ port: 80, proto: tcp }`.

The remaining recipes (`start`, `stop`, `restart`, `logs`, `status`, `cat`, `inspect`, `shell`, `verify`, `remove`, `stop-media`, `debug`, `mkcert`, `enable-auto-update`) operate on the **local** machine's user services via `systemctl --user`, so they are run on the host itself, not from the laptop. `just --list` is authoritative.

## Architecture

### Playbooks

Three playbooks, all run from the laptop against `inventory/hosts.yml`.

Inventory groups name a **capability, not a location**: `workstations` (`laptop`), `quadlet_hosts` (`media`), `git_servers` (`media`), `mail_servers` (`outpost`). Hosts belong to several groups, and connection vars are declared once under `all.hosts`. Plays target groups — never a bare hostname — so a new box is an inventory edit. (An earlier inventory used `local`/`remote`/`workstation`; `local` confusingly held only `media`, a remote SSH host.)

- **`system.yml`** — host OS baseline for `all` (`system`, `restic`), plus `mail` on `mail_servers` and `git` on `git_servers`.
- **`homelab.yml`** — two plays against `quadlet_hosts`, both as root:
  1. `quadlet_host` — creates the `homelab` user, enables linger, sets sysctl, opens firewall ports, installs the Polkit rule.
  2. `quadlets` — deploys the quadlet files and starts services. Runs as root and steps down with `become_user: homelab`, talking to the user's session bus via `DBUS_SESSION_BUS_ADDRESS` / `XDG_RUNTIME_DIR`. (An earlier design connected as the `homelab` user over `machinectl`; that is gone.)
- **`site.yml`** — imports both, in order.

### Roles

- **`roles/system/`** — host OS baseline: third-party repos, packages, dnf-automatic, admin user.
- **`roles/restic/`** — backups: `restic` user, restic binary with `cap_dac_read_search=+ep`, resticprofile config and scheduling.
- **`roles/mail/`** — Postfix relay (outpost only).
- **`roles/git/`** — `git-shell` user and bare-repo directory (media only). Authorized keys come from `git_authorized_keys`.
- **`roles/quadlet_host/`** — host prerequisites for rootless Podman: user, linger, sysctl, firewall, polkit.
- **`roles/quadlets/`** — deploys quadlet files, env files, configs, and starts services.

### Service Deployment

Each service owns a directory: `roles/quadlets/files/services/<service>/`. **The directory name, the `.container` filename, and the systemd unit name must all match** — the role copies the directory's contents verbatim into `~homelab/.config/containers/systemd/`, and `%N` inside the unit resolves to that name. Two services whose files share a basename will silently overwrite each other.

A service directory holds its `.container` file and any `.volume` files. Podman's systemd generator turns them into `.service` units at daemon-reload.

Which services run on a host is set by `enabled_services` in `host_vars/<host>.yml`. The `quadlets` role only touches services in that list.

Key patterns:
- **Systemd specifiers**: `%E` (config dir), `%L` (logs), `%C` (cache), `%D` (state), `%t` (runtime dir), `%N` (unit name)
- **Traefik routing**: services expose themselves via labels, e.g. ``traefik.http.routers.%N.rule=Host(`service.${DOMAIN}`)``
- **Shared defaults**: `files/shared/container.d/homelab.conf` applies `AutoUpdate=registry` to every container; `files/shared/service.d/homelab.conf` sets `Restart=on-failure`
- **Pruning**: `tasks/prune.yml` removes quadlet files the repo no longer defines, so a rename or deletion doesn't leave an old unit running. It always *reports* stale entries but only deletes when `quadlet_prune: true` (default off). Scope is the quadlet dir only — service data in `~homelab/.config/<service>` and Podman volumes are never touched.
- **Per-unit drop-ins** are *generated* by Ansible, not committed. See `tasks/pihole_dropin.yml`, which writes each Pi-hole's `PublishPort` lines from a template.

Quadlet units are generated, so they cannot be `systemctl enable`d — Ansible only starts them. Boot-time start comes from `[Install] WantedBy=default.target` in the unit plus linger on the `homelab` user.

### Variables and Secrets

- **`group_vars/all/main.yml`** — global vars and all vault-encrypted secrets as inline `!vault` blocks (Cloudflare, Pi-hole, zwave, SolarEdge, OpenWeather, restic, B2, SSH).
- **`host_vars/<host>.yml`** — per-host: `enabled_services`, firewall ports, Pi-hole IPs, `traefik_env`, host-specific vault values.
- **`roles/quadlets/defaults/main.yml`** — paths (`homelab_*`) and non-secret service config.
- Add a secret with `ansible-vault encrypt_string --stdin-name '<var>'` and paste the block into `group_vars/all/main.yml`.

**Never commit a plaintext secret.** Public SSH keys are not secrets and do not need vaulting.

### Environment Variables

Two scopes:

1. **Global** — `templates/homelab-env.conf.j2`, rendered to `~homelab/.config/environment.d/homelab.conf`. Available to systemd directives (so usable in `.container` files, e.g. `${DOMAIN}`) and to containers.
2. **Per-service** — `templates/env/<service>/<service>.env.j2`, rendered to `~homelab/.config/containers/systemd/<service>.env` and pulled in by `EnvironmentFile=./%N.env`. Only visible inside the running container.

Per-service env files hold live secrets, so the **templates** are committed and reference vault vars; the **rendered** `.env` files never are. `.gitignore` blocks `*.env` repo-wide to enforce this.

> Historical note: these files were once committed as plaintext `.env` files, protected by a `.gitignore` pattern (`system/*.env`) that — because it contains a mid-pattern slash — was anchored to the repo root and never actually matched them. Real credentials were pushed to a public branch. Hence the blanket `*.env` rule and the `.env.j2` naming.

### Networking

All services share a bridge network (`files/shared/homelab.network`, IPv6 enabled). Traefik reverse-proxies ports 80/443 with host-based routing; its static config is templated from `templates/config/traefik/traefik.yaml.j2` and switches on `traefik_env` (`prd` enables the Let's Encrypt DNS-01 resolver via Cloudflare).

Two Pi-hole instances run side by side — `pihole-local` and `pihole-tailnet` — routed as `dns.` and `dnsts.` respectively. Each binds `:53` to a *specific* host address via its generated drop-in; binding `0.0.0.0` would hijack the Podman network's internal DNS and break container-name resolution.
