SHELL   = zsh
COMPOSE = docker compose

.ONESHELL:

all:

start:
	$(COMPOSE) up --detach

restart:
	$(COMPOSE) up --detach

stop:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

pull:
	$(COMPOSE) pull

start-plex:
	sudo systemctl start plexmediaserver.service

stop-plex:
	sudo systemctl stop plexmediaserver.service

stop-plex:

.PHONY: config
config:
	$(COMPOSE) config

.PHONY: services
services:
	$(COMPOSE) config | yq '.services | keys | .[]' | sort

# Quickly start or restart a service with `make <service>`.
%:
	if [[ -n "$$( docker ps --no-trunc --filter name=^$@$$ --quiet )" ]]; then
	  $(COMPOSE) restart $@
	else
	  $(COMPOSE) up --detach $@
	fi
