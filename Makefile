all:

show-services:
	yq -o json '.services' docker-compose.yml | jq -r '. | keys[]' | sort

ps:
	@docker-compose ps

update:
	docker-compose pull
	docker-compose up --detach

reload:
	docker-compose up --detach
