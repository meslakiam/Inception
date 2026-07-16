# User documentation

This project is a Docker-based web stack. Run the commands below from the repository root.

## Services provided

| Service | Purpose | How it is reached |
| --- | --- | --- |
| Nginx | Public HTTPS entry point and reverse proxy | Port `443` |
| WordPress | Main website and content-management system | `/` |
| MariaDB | Database used by WordPress | Internal only |
| Redis | WordPress object cache | Internal only |
| Adminer | Browser-based MariaDB administration tool | `/adminer` |
| FTP server | File access to the WordPress files | FTP and passive ports configured in `srcs/.env` |
| Portfolio | Additional web application | `/portfolio/` |
| Netdata | Service and host monitoring dashboard | `/netdata/` |

## Start and stop the stack

Start everything:

```bash
make up
```

On its first run, the project creates the data directories, generates password files when they are missing, and creates a local TLS certificate. `mkcert` is used when available; otherwise the setup script downloads it, so internet access is needed for that first certificate setup.

Other lifecycle commands:

```bash
make stop          # stop containers but keep them and their data
make start         # restart previously stopped containers
make down          # stop and remove containers; keep persistent data
make down-volumes  # stop, remove containers and declared Docker volumes
```

## Open the website and panels

The hostname is the value of `DOMAIN_NAME` in `srcs/.env`; the setup script also creates a certificate for `${USER}.42.fr`, `localhost`, and `127.0.0.1`.

For a local installation without DNS, map the configured hostname to your machine in `/etc/hosts`, for example:

```text
127.0.0.1 your-login.42.fr
```

Use HTTPS in a browser:

```text
https://<DOMAIN_NAME>/              Main WordPress website
https://<DOMAIN_NAME>/wp-admin/     WordPress administration panel
https://<DOMAIN_NAME>/adminer       Adminer database panel
https://<DOMAIN_NAME>/portfolio/    Portfolio application
https://<DOMAIN_NAME>/netdata/      Netdata monitoring dashboard
```

The local certificate may need to be trusted by the browser or operating system before it is shown as trusted.

## Credentials and accounts

Do not put passwords in `srcs/.env`. Usernames and non-secret settings are kept there; passwords are separate files in `srcs/secrets/`:

| Account or service | Username source | Password file |
| --- | --- | --- |
| WordPress administrator | `WORDPRESS_ADMIN_USER` | `wordpress_admin_password` |
| WordPress author | `WORDPRESS_USER` | `wordpress_user_password` |
| MariaDB application user | `DB_USER` | `db_user_password` |
| MariaDB root user | `DB_ROOT_USER` | `db_root_password` |
| FTP user | `FTP_USER` | `ftp_password` |

TLS certificate files are `srcs/secrets/nginx.crt` and `srcs/secrets/nginx.key`.

To sign in to Adminer, choose **MariaDB**, use `mariadb` as the server, then enter `DB_USER`, the contents of `db_user_password`, and `DB_NAME_IN_MARIADB` from `srcs/.env`.

To change a password, update its file without adding a trailing value on a second line, then recreate the affected account using its service's own administration interface or database commands. Merely restarting the stack does not change already-created WordPress, MariaDB, or FTP accounts. Keep `srcs/secrets/` private and out of source control.

## Check that the stack is healthy

Check the container state:

```bash
make ps
```

All listed services should be running. Follow their logs if one is restarting or unavailable:

```bash
make logs
```

A successful site response and reachable `/wp-admin/`, `/adminer`, `/portfolio/`, and `/netdata/` routes confirm the corresponding web-facing services. For a single service's logs, use `docker compose -f srcs/docker-compose.yml logs -f <service>`.
