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

Since this is rootless Podman, the following commands are needed in order to bind to ports under 1024.

```
❯ sudo sysctl net.ipv4.ip_unprivileged_port_start=53
❯ echo net.ipv4.ip_unprivileged_port_start=53 | sudo tee /etc/sysctl.d/user_priv_ports.conf
```

Docker, being a daemon running as root, mucked around with the firewall when exposing ports. Since Podman is running
rootless (and is more polite), opening ports on the firewall is an exercise left for the reader.

```
# Allow Pi-hole
❯ sudo firewall-cmd --add-port=53/tcp --permanent
❯ sudo firewall-cmd --add-port=53/udp --permanent

# Allow Traefik
❯ sudo firewall-cmd --add-port=80/tcp --permanent
❯ sudo firewall-cmd --add-port=443/tcp --permanent

# Allow Jellyfin
❯ sudo firewall-cmd --add-port=8096/tcp --permanent

# Plex uses a bunch of ports (no idea if they're all necessary)
❯ sudo firewall-cmd --add-port=1900/udp --permanent
❯ sudo firewall-cmd --add-port=3005/tcp --permanent
❯ sudo firewall-cmd --add-port=8324/tcp --permanent
❯ sudo firewall-cmd --add-port=32400/tcp --permanent
❯ sudo firewall-cmd --add-port=32410/udp --permanent
❯ sudo firewall-cmd --add-port=32412/udp --permanent
❯ sudo firewall-cmd --add-port=32413/udp --permanent
❯ sudo firewall-cmd --add-port=32414/udp --permanent
❯ sudo firewall-cmd --add-port=32469/tcp --permanent
```

Now the Quadlets can be set up.

```
❯ sudo useradd homelab
❯ sudo loginctl enable-linger homelab
❯ sudo machinectl shell homelab@
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

ZIGBEE_DEVICE_ID=/dev/null
ZWAVE_DEVICE_ID=/dev/null
```

Files in the `environment` directory are symlinked to `~/.config/environment.d` by the `install-environment` Justfile
target.

For environment variables specific to a container (e.g. API keys), these are expected to be found in files named
`system/<service>.env`. The individual `<service>.container` files define its expected file with the `EnvironmentFile=`
declaration and document the expected variables, either through explicit use or a comment.

Note, `environment/*.conf` files make their environment available to systemd and can be used in directives that end up
in the `.service` file after generation. The variables defined in `<service>.env` files are only available within the
container once it is running.

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

The zwave-js-ui container may not be able to read the `/dev/zwave` device. I solved this by allowing more access to the
devices:

```
❯ sudo chmod o+rw /dev/ttyUSB?
```

To configure local TLS certificates for use with testing Traefik:

```
❯ just mkcert localhost
```

To initialize iSponsorBlockTV, start the service at least once to create the volume. Note the device code by opening the
YouTube app on the TV and navigating to `Settings > Link with TV code`. Then run,

```
❯ just initialize-isponsorblocktv
```

<https://github.com/dmunozv04/iSponsorBlockTV/wiki/Installation>

To install the Jellyfin app on a Samsung TV:

```
❯ just install-jellyfin <ip-of-tv>
```

<https://github.com/Georift/install-jellyfin-tizen>
