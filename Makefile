
.PHONY: all up build down down-volumes ps logs logs-% exec-% shell certs clean fclean start stop

COMPOSE := docker compose -f srcs/docker-compose.yml

all: up

up:
	$(COMPOSE) up -d --build

build:
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
	$(COMPOSE) down -v --rmi all --remove-orphans

fclean: clean

