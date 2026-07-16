# DEV_DOC.md — Developer documentation

Internals and workflow for developing, building, and maintaining the Inception stack. For end-user usage see [USER_DOC.md](USER_DOC.md); for the broader project context see [README.md](README.md).

---

## 1. Architecture overview

```text
                         host : 443 (TLS)
                              │
                        ┌─────┴─────┐
internet  ────────────► │   nginx   │
                        └─────┬─────┘
        ┌─────────────────────┼─────────────────────┬─────────────────────┐
        │                     │                     │                     │
      `/`                  `/adminer`           `/portfolio/`          `/netdata/`
        │                     │                     │                     │
   ┌────┴────┐           ┌────┴────┐           ┌────┴────┐           ┌────┴────┐
   │wordpress│           │ adminer │           │portfolio│           │ netdata │
   │ php-fpm │           │ php-fpm │           │  app    │           │ monitor │
   └──┬───┬──┘           └────┬────┘           └─────────┘           └─────────┘
      │   │                  │
      │   │                  │ queries
      │   │                  ▼
      │   │              ┌─────────┐
      │   │              │ mariadb │
      │   │              └────┬────┘
      │   │                   │
      │   │                   │ database files
      │   │                   ▼
      │   │             mariadb_data
      │   │
      │   │ reads/writes WordPress files
      │   ▼
      │ wordpress_data
      │
      ▼
   ┌───────┐
   │ redis │
   └───────┘

                         host : 21 (+30000-30010 PASV)
                              │
                        ┌─────┴─────┐
internet  ────────────► │   ftp     │
                        └─────┬─────┘
                              │ writes the same WordPress files
                              ▼
                         wordpress_data

   nginx also reads wordpress_data read-only and adminer_data read-only.
   adminer_data is used only by adminer to store its downloaded PHP file.
   All containers run on the user-defined bridge network: inception_network.
```

- `nginx` is the only public HTTP(S) entry point. It terminates TLS and routes traffic by path.
- `wordpress` serves the site and uses `mariadb` for data and `redis` for cache.
- `adminer` connects to `mariadb` and is exposed through the same nginx endpoint.
- `portfolio` is a separate app container exposed through nginx.
- `ftp` shares the WordPress data volume with WordPress and nginx.
- `netdata` reads Docker and host metrics; it does not participate in the app data path.

---

## 2. Repository layout

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── docker-compose.yml
    ├── .env
    ├── secrets/
    └── requirements/
        ├── tools/
        │   └── first_setup.sh
        ├── nginx/
        │   ├── Dockerfile
        │   └── conf/nginx.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   └── tools/setup.sh
        ├── mariadb/
        │   ├── Dockerfile
        │   └── tools/setup.sh
        └── bonus/
            ├── redis/
            ├── FTP_server/
            ├── adminer/
            ├── portfolio/
            └── netdata/
```

The important split is between build-time files (`Dockerfile`) and runtime bootstrap files (`tools/setup.sh` or `conf/*.sh`). Most of the actual project behavior is implemented in those startup scripts.

---

## 3. Set up the environment from scratch

### Prerequisites

- Linux host or VM with Docker Engine and the Compose plugin.
- `make`, `bash`, `curl`, and `openssl`.
- Permission to create `/home/$USER/data`.
- Permission to remove Docker resources when running cleanup targets.
- Optional: `mkcert`. If it is missing, the setup script downloads a local binary.

### Configuration files

- `srcs/.env` holds non-secret runtime settings.
- `srcs/secrets/` is generated on first bootstrap and contains password files plus TLS material.

The project uses these `.env` values directly:

```text
DB_PORT
NGINX_PORT
REDIS_PORT
FTP_PORT
PASV_MIN_PORT
PASV_MAX_PORT
DB_USER
DB_ROOT_USER
WORDPRESS_USER
WORDPRESS_ADMIN_USER
FTP_USER
DOMAIN_NAME
WORDPRESS_DB_HOST
DB_NAME_IN_MARIADB
WORDPRESS_TITLE
WORDPRESS_ADMIN_EMAIL
WORDPRESS_USER_EMAIL
```

### What `first_setup.sh` does

`make build` and `make up` both run `srcs/requirements/tools/first_setup.sh` before Compose starts the stack. That script:

1. Creates `srcs/secrets/`.
2. Creates `/home/$USER/data/mariadb` and `/home/$USER/data/wordpress`.
3. Generates missing password files:
   - `db_root_password`
   - `db_user_password`
   - `wordpress_admin_password`
   - `wordpress_user_password`
   - `ftp_password`
4. Creates `nginx.crt` and `nginx.key` with `mkcert`.

The script is idempotent. Existing secrets are preserved.

### Local hostname

The browser hostname must match `DOMAIN_NAME` in `srcs/.env`, and that name should resolve to `127.0.0.1` in `/etc/hosts` for local development.

The certificate generation script currently uses the local user-derived domain as the certificate subject. That is acceptable as long as the local hostname and the certificate trust chain are consistent for your machine.

---

## 4. Build and launch

The Makefile is the normal entry point.

| Target | Effect |
| --- | --- |
| `make` | Alias for `make up` |
| `make up` | Run bootstrap, build images if needed, and start the stack detached |
| `make build` | Run bootstrap and build images only |
| `make stop` | Stop running containers |
| `make start` | Start existing stopped containers |
| `make down` | Remove containers and the default network |
| `make down-volumes` | Remove containers, network, and Compose volumes |
| `make ps` | Show container status |
| `make logs` | Follow combined logs |
| `make clean` | Stop the stack, remove all local Docker containers, and remove all local Docker images |
| `make fclean` | `clean` plus Docker volumes, custom networks, system prune, host data, and secrets |
| `make re` | `clean` then `make` |
| `make fre` | `fclean` then `make` |

Direct Compose commands:

```bash
docker compose -f srcs/docker-compose.yml build
docker compose -f srcs/docker-compose.yml up -d --build
docker compose -f srcs/docker-compose.yml down
docker compose -f srcs/docker-compose.yml config
```

---

## 5. Managing containers and volumes

```bash
CF="-f srcs/docker-compose.yml"

docker compose $CF ps
docker compose $CF logs -f
docker compose $CF logs -f wordpress
docker compose $CF restart nginx
docker compose $CF stop wordpress
docker compose $CF down

docker exec -it wordpress sh
docker exec -it mariadb sh
docker exec -it ftp sh

docker volume ls
docker volume inspect inception_mariadb_data
docker volume inspect inception_wordpress_data
docker network inspect inception_network
```

Useful service-level checks:

```bash
docker exec wordpress wp plugin list --allow-root --path=/var/www/html
docker exec wordpress wp user list --allow-root --path=/var/www/html
docker exec wordpress wp redis status --allow-root --path=/var/www/html

docker exec mariadb mariadb-admin ping -u root -p"$(cat srcs/secrets/db_root_password)"
docker exec mariadb mariadb -u root -p"$(cat srcs/secrets/db_root_password)" -e "SHOW DATABASES;"
```

`depends_on` in Compose controls start order only. Readiness is handled by the service scripts themselves, especially the WordPress wait loop against MariaDB.

---

## 6. Where data is stored and how it persists

The stack uses two host-backed data directories and one Docker-managed volume:

| Volume | Mounted in | Host backing path | Contents |
| --- | --- | --- | --- |
| `mariadb_data` | `mariadb:/var/lib/mysql` | `/home/$USER/data/mariadb` | Database files and InnoDB state |
| `wordpress_data` | `wordpress:/var/www/html`, `nginx:/var/www/html:ro`, `ftp:/var/www/html:rw` | `/home/$USER/data/wordpress` | WordPress core, config, uploads, plugins, themes |
| `adminer_data` | `adminer:/var/www/adminer` | Docker-managed local volume | Downloaded Adminer PHP file |

Persistence behavior:

- `make stop`, `make start`, and `make down` keep the host data directories intact.
- Rebuilding images does not erase `mariadb_data` or `wordpress_data`.
- `make down-volumes` removes Compose volumes, but the two bind-mounted host directories still exist on disk.
- `make fclean` removes the host data directories and `srcs/secrets/`, so the next `make up` recreates the stack from scratch.

WordPress and MariaDB initialize their state only on first creation. If `.env` or a secret file changes later, existing persisted state will not be rewritten automatically.

---

## 7. Service start order and readiness

The practical startup chain is:

1. `first_setup.sh` prepares secrets, data directories, and TLS material.
2. `mariadb` starts and initializes its database files.
3. `wordpress` waits for MariaDB, then downloads and configures WordPress.
4. `adminer` starts and downloads its `index.php`.
5. `redis` starts as the cache backend.
6. `portfolio` starts as an independent application.
7. `netdata` starts with access to the Docker socket and host mounts.
8. `ftp` starts and exposes the WordPress volume over FTP.
9. `nginx` starts last and exposes the complete stack on HTTPS.

Readiness is implemented in code, not only in Compose:

- MariaDB is initialized through a temporary local server, then restarted in normal mode.
- WordPress explicitly waits for MariaDB before running `wp core install`.
- Each long-running entrypoint ends with `exec <daemon>` so the daemon becomes PID 1.
- `init: true` gives each container a minimal init process for signal forwarding and zombie reaping.

---

## 8. Conventions and gotchas

- All images are tagged as `<service>:Inception`.
- `nginx` is the only container that publishes a public port.
- `ftp` publishes the control port and the configured passive range from `.env`.
- `redis` is internal-only and has no persistent volume.
- `adminer` is reached through nginx at `/adminer`, not through a separate host port.
- `portfolio` is served through nginx at `/portfolio/`.
- `netdata` is exposed through nginx at `/netdata/` and needs access to `/var/run/docker.sock`, `/proc`, and `/sys`.
- Passwords are stored in `srcs/secrets/` and read through Docker secrets at runtime.
- Do not place credentials directly in Dockerfiles or `.env`.
- `srcs/requirements/tools/first_setup.sh` is the host bootstrap step, not a container entrypoint.

One important project-specific detail: the host paths are pinned under `/home/$USER/data`, so the stack is intentionally tied to the current login user. If you change the user or move the repository, review the data paths, `.env`, and certificate subject together.
