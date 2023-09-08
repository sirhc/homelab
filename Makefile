SHELL   = zsh
COMPOSE = docker compose

.ONESHELL:

all:

start:
	$(COMPOSE) up --detach

stop:
	$(COMPOSE) down

ps:
	$(COMPOSE) ps

update:
	$(COMPOSE) pull

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
