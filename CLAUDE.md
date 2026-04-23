# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository is the **single source of truth** for all homelab devices and configuration. Everything needed to manage, configure, and deploy any device should live here.

Homelab infrastructure managed with **rootless Podman Quadlets** on Fedora. Services are defined as systemd-style `.container` files and orchestrated via `systemctl --user`. The build/deploy tool is **Just**; all deployment and configuration is managed through **Ansible**.

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
just reload               # systemctl --user daemon-reload
just start <service>      # Start a single service
just start-all            # Start all installed services
just stop <service>       # Stop a single service
just restart <service>    # Restart a single service
just logs <service>       # View journalctl logs for a service
just logs <service> -f    # Follow logs
just status <service>     # Check service status
just shell <service>      # Open shell in running container
just verify <service>     # Validate systemd unit file syntax
just list-services        # List all services with descriptions
just debug                # Launch a fedora bash container on the homelab network
```

## Architecture

### Directory Layout

- **`inventory/`** - Ansible inventory (`hosts.yml`)
- **`group_vars/`** - Ansible group variables (including vault-encrypted secrets)
- **`roles/quadlet_host/`** - Ansible role for host OS setup (user, linger, sysctl, firewall, polkit)
- **`roles/quadlets/`** - Ansible role for Podman Quadlet service deployment
  - **`files/system/`** - Quadlet definitions: `.container`, `.volume`, `.network` files, `.env` secrets (gitignored), and `container.d/` drop-in
  - **`files/user/`** - User-level systemd service drop-ins (e.g., `Restart=on-failure`)
  - **`files/config/`** - Version-controlled service configs (Prometheus, Traefik) deployed to `~/.config/<service>/`
  - **`tasks/`** - Deployment tasks (quadlet files, volumes, network, env files, configs, drop-ins)
  - **`templates/`** - Jinja2 templates (environment config, Traefik production config, Pi-hole drop-in)

### How Services Work

Each service is a `.container` file in `roles/quadlets/files/system/` following the [Podman Quadlet spec](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html). Ansible deploys these to `~/.config/containers/systemd/` where Podman's systemd generator converts them into `.service` units.

Key patterns in container files:
- **Systemd specifiers**: `%E` (config dir), `%L` (logs dir), `%C` (cache dir), `%D` (state dir), `%t` (runtime dir), `%N` (unit name)
- **Traefik routing**: Services expose themselves via labels like `traefik.http.routers.<service>.rule=Host('service.${DOMAIN}')`
- **Drop-in overrides**: Per-service overrides go in `files/system/<service>.container.d/` directories
- **Shared defaults**: `files/system/container.d/homelab.conf` applies `AutoUpdate=registry` to all containers

### Environment Variables

Two scopes:
1. **Global** (deployed from a template by Ansible): Available to systemd directives and containers via `~/.config/environment.d/`.
2. **Per-service** (`roles/quadlets/files/system/<service>.env`): Only available inside the running container via `EnvironmentFile=`. These are gitignored and hold secrets/API keys.

### Networking

All services share a bridge network (`homelab.network`, IPv6 enabled). Traefik handles reverse proxying on ports 80/443 with host-based routing. A few services publish additional ports directly (Pi-hole on 53, Plex on multiple ports).
