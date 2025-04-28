set shell := ["zsh", "-cu"]

_all:

# Start a service (all services if not specified)
start service="":
  docker compose up --detach {{ service }}

# Stop a service (all services if not specified)
stop service="":
  docker compose down {{ service }}

# Restart a Docker container and follow its logs
restart service:
  docker compose restart {{ service }}
  docker compose logs -f {{ service }}

# Pull updated Docker images and restart affected containers
update: && prune
  docker compose pull
  docker compose up --detach

# Prune unused Docker images
prune:
  docker image prune --force

# This stops any containers with a volume override, since the only reason for the override is to include the mount to
# the media volume.
#
# Stop containers that access the /media volume (for NAS maintenance)
stop-media:
  docker compose stop $( yq e '.services | to_entries | map(select(.value.volumes)) | map(.key) | .[]' compose.override.yaml )
