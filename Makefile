
.PHONY: all up build down down-volumes ps logs logs-% exec-% shell certs clean fclean start stop

COMPOSE := docker compose -f srcs/docker-compose.yml
DATA_DIR := /home/$(USER)/data
SECRETS_DIR := srcs/requirements/secrets

all: up

up: certs
	$(COMPOSE) up -d --build

build: certs
	$(COMPOSE) build

down:
	$(COMPOSE) down

stop: 
	$(COMPOSE) stop

start:
	$(COMPOSE) start

down-volumes:
	$(COMPOSE) down -v

ps:
	$(COMPOSE) ps

logs:
	$(COMPOSE) logs -f

logs-%:
	$(COMPOSE) logs -f $*

exec-%:
	$(COMPOSE) exec $* sh

shell:
	$(COMPOSE) exec wordpress sh

certs:
	bash srcs/requirements/tools/first_setup.sh

clean:
	$(COMPOSE) down --remove-orphans
	-docker rm -f $$(docker ps -aq)
	-docker rmi -f $$(docker images -aq)

fclean: clean
	-docker volume rm $$(docker volume ls -q)
	-docker network rm $$(docker network ls -q --filter type=custom)
	-docker system prune -af --volumes
	-sudo rm -rf $(DATA_DIR)/mariadb $(DATA_DIR)/wordpress
	-rm -rf $(SECRETS_DIR)


