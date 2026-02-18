# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Homelab infrastructure managed with **rootless Podman Quadlets** on Fedora. Services are defined as systemd-style `.container` files and orchestrated via `systemctl --user`. The build/deploy tool is **Just**; deployment uses **Ansible** (two playbooks: `configure-host.yml` and `install-quadlets.yml`). GNU stow is retained for local dev iteration.

## Common Commands

```bash
just configure-host       # Run configure-host.yml (all hosts)
just configure-host <h>   # Run configure-host.yml (single host)
just deploy               # Run install-quadlets.yml (all hosts)
just deploy <host>        # Run install-quadlets.yml (single host)
just provision            # configure-host + deploy (all hosts)
just check-configure-host # Dry-run configure-host.yml
just check-deploy         # Dry-run install-quadlets.yml
just install              # Symlink all service/env/user files to ~/.config (legacy stow)
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
just clean                # Remove dangling symlinks
just debug                # Launch a fedora bash container on the homelab network
```

## Architecture

### Directory Layout

- **`system/`** - Podman Quadlet definitions: `.container` files (service definitions), `.volume` files, `.network` file, `.env` files (secrets, gitignored), and `container.d/` drop-in for shared defaults
- **`environment/`** - Global environment variables (e.g., `DOMAIN`), symlinked to `~/.config/environment.d/`
- **`user/`** - User-level systemd service drop-ins (e.g., `Restart=on-failure`), symlinked to `~/.config/systemd/user/`
- **`config/`** - Version-controlled service configs (Prometheus scrape config, Traefik routing rules) deployed by Ansible to `~/.config/<service>/`

### How Services Work

Each service is a `.container` file in `system/` following the [Podman Quadlet spec](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html). When installed via `stow`, these are symlinked to `~/.config/containers/systemd/` where Podman's systemd generator converts them into `.service` units.

Key patterns in container files:
- **Systemd specifiers**: `%E` (config dir), `%L` (logs dir), `%C` (cache dir), `%D` (state dir), `%t` (runtime dir), `%N` (unit name)
- **Traefik routing**: Services expose themselves via labels like `traefik.http.routers.<service>.rule=Host('service.${DOMAIN}')`
- **Drop-in overrides**: Per-service overrides go in `system/<service>.container.d/` directories
- **Shared defaults**: `system/container.d/homelab.conf` applies `AutoUpdate=registry` to all containers

### Environment Variables

Two scopes:
1. **Global** (`environment/*.conf`): Available to systemd directives and containers. Symlinked to `~/.config/environment.d/`.
2. **Per-service** (`system/<service>.env`): Only available inside the running container via `EnvironmentFile=`. These are gitignored and hold secrets/API keys.

### Networking

All services share a bridge network (`homelab.network`, IPv6 enabled). Traefik handles reverse proxying on ports 80/443 with host-based routing. A few services publish additional ports directly (Pi-hole on 53, Plex on multiple ports).
