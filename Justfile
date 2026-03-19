config_dir      := env('XDG_CONFIG_HOME', x"~/.config")
container_dir   := config_dir / 'containers/systemd'
environment_dir := config_dir / 'environment.d'
user_dir        := config_dir / 'systemd/user'

systemctl  := 'systemctl --user'
journalctl := 'journalctl --user'

_all:

@list-services:
  grep '^Description=' roles/quadlets/files/system/*.container | sed -e 's,roles/quadlets/files/system/,,' -e 's/.container/.service/' -e 's/:Description=/,/' | mlr --c2p --hi label 'Service,Description'

# Run system baseline (package updates, restic user)
update host='':
  ansible-playbook baseline.yml{{ if host != '' { ' --limit ' + host } else { '' } }}

# Run full provisioning (common role + quadlets)
provision host='':
  ansible-playbook site.yml{{ if host != '' { ' --limit ' + host } else { '' } }}

# Dry-run full provisioning
check host='':
  ansible-playbook site.yml --check{{ if host != '' { ' --limit ' + host } else { '' } }}

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

restart-all:
  ls -1 '{{ container_dir }}'/*.container | xargs -I % basename % .container | xargs -I % {{ systemctl }} restart %.service

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
