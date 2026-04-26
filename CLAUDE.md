# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is the **single source of truth** for all homelab devices and configuration. Everything needed to manage, configure, and deploy any device should live here.

Homelab infrastructure managed with **rootless Podman Quadlets** on Fedora. Services are defined as systemd-style `.container` files and orchestrated via `systemctl --user`. The build/deploy tool is **Just**; all deployment and configuration is managed through **Ansible**.

## Prerequisites

```bash
sudo dnf install podman just ansible-core
ansible-galaxy collection install -r requirements.yml
echo 'yourpassword' > ~/.ansible/vault_pass && chmod 600 ~/.ansible/vault_pass
```

The vault password file path is `~/.ansible/vault_pass` (configured in `ansible.cfg`).

## Common Commands

```bash
just update               # Run system.yml (all hosts)
just update <host>        # Run system.yml (single host)
just deploy               # Run homelab.yml (all hosts)
just deploy <host>        # Run homelab.yml (single host)
just provision            # Run site.yml — system + homelab (all hosts)
just provision <host>     # Run site.yml — system + homelab (single host)
just check                # Dry-run site.yml (all hosts)
just check <host>         # Dry-run site.yml (single host)
just test-service <svc>   # Deploy a single service to laptop for testing
just test-service <svc> <host>  # Deploy to a specific host

just reload               # systemctl --user daemon-reload
just start <service>      # Start a single service
just start-all            # Start all installed services
just stop <service>       # Stop a single service
just stop-all             # Stop all installed services
just restart <service>    # Restart a single service
just restart-all          # Restart all installed services
just remove <service>     # Stop, disable, and remove quadlet files
just stop-media           # Stop all containers mounting /media (for NAS maintenance)
just logs <service>       # View journalctl logs for a service
just logs <service> -f    # Follow logs
just status <service>     # Check service status
just cat <service>        # Show the generated systemd unit file
just inspect <service>    # podman inspect the running container
just shell <service>      # Open shell in running container
just verify <service>     # Validate systemd unit file syntax
just list-services        # List all services with descriptions
just debug                # Launch a fedora bash container on the homelab network
just mkcert <domain>      # Create local TLS certs for Traefik dev (uses mkcert)
just enable-auto-update   # Enable podman-auto-update timer
just disable-auto-update  # Disable podman-auto-update timer
```

## Architecture

### Playbooks

Three playbooks, all run from the laptop against `inventory/hosts.yml`:

- **`system.yml`** — runs as root (`become: true`) via the `system` and `restic` roles: repos, packages, dnf-automatic, admin user, restic backups.
- **`homelab.yml`** — two-play structure:
  1. Runs `quadlet_host` as root: creates `homelab` user, enables linger, sets sysctl, opens firewall ports, installs the Polkit rule.
  2. Runs `quadlets` as `homelab` user via `machinectl` (rootless): deploys XDG dirs, environment, network, volumes, quadlet files, configs, and starts services.
- **`site.yml`** — imports both in order.

### Roles

- **`roles/system/`** — host OS baseline: third-party repos, packages (zsh, dnf-automatic), admin user, handlers for timer restart.
- **`roles/restic/`** — backup setup: creates `restic` user, installs latest restic binary to `~restic/bin/restic` with `cap_dac_read_search=+ep`, deploys resticprofile config with built-in scheduling.
- **`roles/quadlet_host/`** — host prerequisites for rootless Podman: user, linger, sysctl, firewall, polkit.
- **`roles/quadlets/`** — deploys Podman Quadlet service files and starts services.

### Service Deployment

Each service is a `.container` file in `roles/quadlets/files/system/` following the [Podman Quadlet spec](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html). Ansible deploys these to `~/.config/containers/systemd/` where Podman's systemd generator converts them into `.service` units.

Which services run on a host is controlled by `enabled_services` in `host_vars/<host>.yml`. The `quadlets` role only deploys and starts services in that list.

Key patterns in container files:
- **Systemd specifiers**: `%E` (config dir), `%L` (logs dir), `%C` (cache dir), `%D` (state dir), `%t` (runtime dir), `%N` (unit name)
- **Traefik routing**: Services expose themselves via labels like `traefik.http.routers.<service>.rule=Host('service.${DOMAIN}')`
- **Drop-in overrides**: Per-service overrides go in `files/system/<service>.container.d/` directories (gitignored)
- **Shared defaults**: `files/system/container.d/homelab.conf` applies `AutoUpdate=registry` to all containers

### Variables and Secrets

- **`group_vars/all/main.yml`** — global vars and all vault-encrypted secrets (inline `!vault` blocks). Secrets include restic credentials, B2 credentials, and SSH keys.
- **`host_vars/<host>.yml`** — per-host overrides: `enabled_services`, `domain`, Traefik config variant, any host-specific vault values.
- Edit secrets with `ansible-vault encrypt_string` for new values; view with `ansible-vault decrypt`.

### Environment Variables

Two scopes:
1. **Global** (`environment/homelab.conf`, deployed to `~/.config/environment.d/`): available to systemd directives and containers. Gitignored — contains `DOMAIN` and device paths.
2. **Per-service** (`roles/quadlets/files/system/<service>.env`): only available inside the running container via `EnvironmentFile=`. Gitignored — holds API keys and secrets.

### Networking

All services share a bridge network (`homelab.network`, IPv6 enabled). Traefik handles reverse proxying on ports 80/443 with host-based routing. A few services publish additional ports directly (Pi-hole on 53, Plex on multiple ports).
