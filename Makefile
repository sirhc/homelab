SHELL = zsh

all:

show-services:
	@yq -o json '.services' docker-compose.yml | jq -r '. | keys[]' | sort

ps:
	@docker-compose ps

update: pull outdated confirm-reload reload clean

pull:
	@docker-compose pull

outdated:
	@printf '\nImages with newer versions:\n'
	@docker images | grep '<none>' | sed -e 's/^/  /' | sort
	@printf '\n'

confirm-reload:
	@read -q 'REPLY?Reload containers? (y/N) '
	@printf '\n'

reload:
	@docker-compose up --detach

clean:
	@docker image prune
