all: db wp nginx

rm : rm_db rm_wp rm_nginx

# NGINX
nginx: build_nginx run_nginx

build_nginx:
	docker build -t nginximg NGINX/

run_nginx:
	docker run -d -p 80:80 -p 443:443 -v wp_vol:/var/www/  --network wpnet --name nginx nginximg

show_nginx:
	docker volume ls
	docker network ls
	docker images
	docker ps -a

stop_nginx:
	-docker stop nginx

rm_nginx: stop_nginx
	-docker rm nginx
	-docker image rm nginximg:latest

re_nginx: rm_nginx all


# MARIADB
db: build_db run_db

build_db:
	docker build -t dbimg MariaDB/

run_db:
	-docker network create wpnet
	docker run -d --env-file .env -p 3306:3306 -v db_vol:/var/lib/mysql --network wpnet --name db dbimg

show_db:
	docker volume ls
	docker network ls
	docker images
	docker ps -a

stop_db:
	-docker stop db

rm_db: stop_db
	-docker rm db
	-docker image rm dbimg:latest

re_db: rm_db all

# WORDPRESS
wp: build_wp run_wp

build_wp:
	docker build -t wpimg WordPress/

run_wp:
	docker run -d --env-file .env -p 9000:9000 -v wp_vol:/var/www/ --network wpnet --name wp wpimg 

show_wp:
	docker volume ls
	docker network ls
	docker images
	docker ps -a

stop_wp:
	-docker stop wp

rm_wp: stop_wp
	-docker rm wp
	-docker image rm wpimg:latest

re_wp: rm_db all
