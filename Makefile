SHELL   = zsh
COMPOSE = docker compose

all:

start:
	$(COMPOSE) up --detach

stop:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

update:
	$(COMPOSE) pull
	@read -r 'REPLY?Restart services? [y/N] '; [[ $${REPLY:l} =~ '^y(es)?' ]]
	$(MAKE) start
	docker image prune

restart-plex:
	$(COMPOSE) restart plex

# Stop containers accessing /media.
stop-media:
	$(COMPOSE) stop calibre homepage plex lidarr radarr readarr sabnzbd sonarr

.PHONY: config
config:
	$(COMPOSE) config

.PHONY: services
services:
	$(COMPOSE) config | yq '.services | keys | .[]' | sort

# Quickly start or restart a service with `make <service>`.
%:
	if [[ -n "$$( docker ps --no-trunc --filter name=^$@$$ --quiet )" ]]; then \
	  $(COMPOSE) restart $@; \
	else \
	  $(COMPOSE) up --detach $@; \
	fi
