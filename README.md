# Homelab

## Prerequisites

I run my development and homelab environments on Fedora, so all of my assumptions are based on using
[Podman Quadlets](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) to implement the services.

```
❯ sudo dnf install podman just stow
```

## Configuration

For services that use a configuration directory, that directory is created at `~/.config/<service>` and bind mounted to
the appropriate location within the container. There are configuration files for some of the services in the
`config/<service>` directories, intended for initial configuration or configuration that doesn't change and I want to
version control or for development purposes. These need to be manually copied to the expected location in
`~/.config/<service>`.

## Setup

```
# These commands are necessary to allow the rootless containers to bind to ports under 1024.
❯ sudo sysctl net.ipv4.ip_unprivileged_port_start=53
❯ echo net.ipv4.ip_unprivileged_port_start=53 | sudo tee /etc/sysctl.d/user_priv_ports.conf

❯ sudo useradd homelab
❯ sudo loginctl enable-linger homelab
❯ sudo -i -u homelab
❯ git clone https://github.com/sirhc/homelab.git
❯ cd homelab
❯ just install
❯ just start-all  # or, just start <service>
```

## Environment Variables

Environment variables are defined in one of two places.

For environment variables that apply to all containers (e.g., `DOMAIN`), these are defined in the `environment`
directory. In my environment, I use `environment/homelab.conf` (shown here defining my laptop development environment):

```env
DOMAIN=localhost
```

Files in the `environment` directory are symlinked to `~/.config/environment.d` by the `install-environment` Justfile
target.

For environment variables specific to a container (e.g. API keys), these are expected to be found in files named
`system/<service>.env`. The individual `<service>.container` files define its expected file with the `EnvironmentFile=`
declaration and document the expected variables, either through explicit use or a comment.

All environment files ( `environment/*.conf` and `system/*.env`) are ignored by Git.

I experimented with using Podman secrets for sensitive values, but ultimately felt that unversioned environment files
are fine for my use case.

## Backup

A benefit of using rootless containers is that all the data that needs to be backed up exists in the user's home
directory, either in `~/.config` or `~/.local`. For example, the data for Podman volumes can be found in
`~/.local/share/containers/storage/volumes/systemd-<service>/_data`. One method of backing up the volume data is to save
the tarballs created by `podman volume export`. However, for my purposes, I've chosen to just back up back up `~homelab`
and call it a day. This doesn't account for things like open SQLite databases, but I haven't had any problems backing up
and restoring the data from all of my containers so far (knocking on wood).

I use [Restic](https://restic.net/) to back up to my [Synology NAS](https://www.synology.com/) and
[Backblaze B2](https://www.backblaze.com/cloud-storage).

## Miscellanea

To configure local TLS certificates for use with testing Traefik:

```
❯ just mkcert localhost
```

To install the Jellyfin app on a Samsung TV:

```
❯ just install-jellyfin <ip-of-tv>
```

See <https://github.com/Georift/install-jellyfin-tizen>.
