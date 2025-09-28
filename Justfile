config_dir      := env('XDG_CONFIG_HOME', x"~/.config")
container_dir   := config_dir / 'containers/systemd'
environment_dir := config_dir / 'environment.d'
user_dir        := config_dir / 'systemd/user'

systemctl  := 'systemctl --user'
journalctl := 'journalctl --user'

_all:

@list-services:
  grep '^Description=' system/*.container | sed -e 's,system/,,' -e 's/.container/.service/' -e 's/:Description=/,/' | mlr --c2p --hi label 'Service,Description'

# Symlink service files, environment files, and user files to ~/.config
install: install-services install-environment install-user

install-services:
  mkdir -p '{{ container_dir }}'
  stow --target='{{ container_dir }}' --stow --verbose system

install-environment:
  mkdir -p '{{ environment_dir }}'
  stow --target='{{ environment_dir }}' --stow --verbose environment

install-user:
  mkdir -p '{{ user_dir }}'
  stow --target='{{ user_dir }}' --stow --verbose user

# Remove symlinks for service files, environment files, and user files
uninstall: uninstall-services uninstall-environment uninstall-user

uninstall-services:
  stow --target='{{ container_dir }}' --delete --verbose system

uninstall-environment:
  stow --target='{{ environment_dir }}' --delete --verbose environment

uninstall-user:
  stow --target='{{ user_dir }}' --delete --verbose user

reload:
  {{ systemctl }} daemon-reload

start service:
  {{ systemctl }} start {{ service }}

start-all:
  ls -1 '{{ container_dir }}'/*.container | xargs -I % basename % .container | xargs -I % {{ systemctl }} start %.service

stop service:
  {{ systemctl }} stop {{ service }}

stop-all:
  ls -1 '{{ container_dir }}'/*.container | xargs -I % basename % .container | xargs -I % {{ systemctl }} stop %.service

restart service:
  {{ systemctl }} restart {{ service }}

status service:
  {{ systemctl }} status {{ service }}

logs service *extra:
  {{ journalctl }} --unit {{ service }} {{ extra }}

cat service:
  {{ systemctl }} cat {{ service }}

inspect service:
  podman inspect systemd-{{ service }}

verify service:
  systemd-analyze --user --generators=true verify {{ service }}.service

# Open a shell in a service container
shell service shell='/bin/sh':
  podman exec -it systemd-{{ service }} {{ shell }}

# Launch a bash shell in a fedora container on the homelab network
debug:
  podman run -it --rm --network homelab fedora bash

# Remove dangling symlinks
clean:
  symlinks -d '{{ container_dir }}'
  symlinks -d '{{ environment_dir }}'
  symlinks -d '{{ user_dir }}'

# Create certificates for testing services locally (e.g., localhost)
mkcert domain:
  mkdir -p ~/.config/traefik/certs
  cd ~/.config/traefik/certs && mkcert '{{ domain }}' '*.{{ domain }}'

# Initialize iSponsorBlockTV
initialize-isponsorblocktv:
  mkdir -p '{{ config_dir }}/isponsorblocktv'
  podman run -it --rm --volume '{{ config_dir }}/isponsorblocktv':/app/data:Z ghcr.io/dmunozv04/isponsorblocktv --setup-cli

# Enable automatic updates of containers
enable-auto-update:
  {{ systemctl }} enable podman-auto-update.service
  {{ systemctl }} enable podman-auto-update.timer

# Disable automatic updates of containers
disable-auto-update:
  {{ systemctl }} disable podman-auto-update.service
  {{ systemctl }} disable podman-auto-update.timer

# Install the Jellyfin app on a Samsung TV
install-jellyfin ip:
  podman run --rm --ulimit nofile=1024:65536 ghcr.io/georift/install-jellyfin-tizen {{ ip }}

# Stop any containers that mount the /media volume (e.g., for NAS maintenance)
stop-media:
  podman container ps --format '{{{{ .ID }}' | \
    xargs podman container inspect | \
    jq -r '.[] | { Id, Mounts } | select(.Mounts[].Source == "/media") | .Id' | \
    xargs podman container stop
