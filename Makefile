all:

show-services:
	yq -o json '.services' docker-compose.yml | jq -r '. | keys[]' | sort

ps:
	@docker-compose ps

update: pull reload

pull:
	docker-compose pull

reload:
	docker-compose up --detach
