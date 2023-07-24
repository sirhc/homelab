SHELL = zsh

all:

show-services:
	@yq -o json '.services' docker-compose.yml | jq -r '. | keys[]' | sort

ps:
	@docker compose ps

update: pull outdated confirm-reload reload clean

pull:
	@docker compose pull

outdated:
	@printf '\nImages with newer versions:\n'
	@docker images | sort | grep -B1 '<none>' | grep -v '^-' | sed -e '/<none>/s/^/\x1b[31m/' -e '/<none>/s/$$/\x1b[0m/' -e 's/^/  /'
	@printf '\n'

confirm-reload:
	@read -r 'REPLY?Reload containers? [y/N] ' && [[ $$REPLY =~ '^[Yy]$$' ]]
	@printf '\n'

reload:
	@docker compose up --detach

clean:
	@docker image prune

restart-dns:
	@docker compose restart pihole
