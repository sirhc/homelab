all:

show-services:
	@yq -o json '.services' docker-compose.yml | jq -r '. | keys[]' | sort

ps:
	@docker-compose ps

update: pull outdated reload

pull:
	@docker-compose pull

outdated:
	@printf '\nImages with newer versions:\n'
	@docker images | grep '<none>' | sed -e 's/^/  /' | sort
	@printf '\n'

reload:
	@docker-compose up --detach
