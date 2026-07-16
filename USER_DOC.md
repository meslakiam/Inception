# USER_DOC.md

> User documentation for the Inception project.

This document explains how to install, configure, run, and manage the Inception infrastructure.

Unlike **DEV_DOC.md**, which focuses on implementation details and architecture, this guide is intended for users and administrators who simply want to deploy and use the project.

For implementation details and architectural decisions, refer to **DEV_DOC.md**.

---

# 1. Introduction

## Overview

Inception is a complete containerized web infrastructure built with Docker Compose.

Instead of installing every application directly on the operating system, each service runs inside its own Docker container.

The infrastructure includes:

- NGINX (Reverse Proxy)
- WordPress
- MariaDB
- Redis
- Adminer
- FTP Server
- Portfolio (.NET)
- Netdata

All services are automatically built and configured through Docker Compose.

---

## Features

The project provides:

- HTTPS using TLS
- WordPress website
- MariaDB database
- Redis object caching
- FTP access
- Database administration through Adminer
- Personal portfolio website
- Infrastructure monitoring using Netdata
- Persistent storage using Docker Volumes
- Secure credential management using Docker Secrets

---

# 2. Prerequisites

Before running the project, ensure the following software is installed.

## Required

- Linux (or Linux Virtual Machine)
- Docker Engine
- Docker Compose
- GNU Make

Verify the installation.

```bash
docker --version

docker compose version

make --version
```

---

## Optional

The setup script can automatically generate TLS certificates.

The following tools may also be useful.

- curl
- openssl

---

# 3. Repository Structure

The repository is organized as follows.

```text
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs
    ├── docker-compose.yml
    ├── .env
    ├── secrets/
    └── requirements/
```

Most users only need to interact with:

| File | Purpose |
|------|---------|
| Makefile | Build and manage the project |
| docker-compose.yml | Infrastructure definition |
| .env | Configuration |
| secrets/ | Automatically generated credentials |

---

# 4. Initial Setup

Clone the repository.

```bash
git clone <repository-url>

cd Inception
```

---

## Configure Local DNS

The project uses a local domain.

Add it to your hosts file.

```bash
echo "127.0.0.1 <your_login>.42.fr" | sudo tee -a /etc/hosts
```

Example:

```bash
echo "127.0.0.1 imeslaki.42.fr" | sudo tee -a /etc/hosts
```

---

## Verify Configuration

Open:

```
srcs/.env
```

Verify the values match your environment.

Typical configuration includes:

- domain name
- ports
- usernames
- database name

Passwords are **not** stored in this file.

---

# 5. Building the Infrastructure

The recommended way to build the project is:

```bash
make
```

This command automatically performs the following operations.

1. Generates Docker Secrets.
2. Generates TLS certificates.
3. Creates required host directories.
4. Builds every Docker image.
5. Creates Docker volumes.
6. Creates the Docker network.
7. Starts all containers.

The first build may take several minutes depending on your Internet connection.

---

## Verify Containers

After the build finishes, check that every service is running.

```bash
docker compose -f srcs/docker-compose.yml ps
```

Example output:

```text
NAME          STATUS
nginx         Up
wordpress     Up
mariadb       Up
redis         Up
ftp           Up
adminer       Up
portfolio     Up
netdata       Up
```

If every service is marked as **Up**, the infrastructure is ready to use.


---

# 6. Accessing the Services

Once all containers are running, every service can be accessed through its designated endpoint.

## WordPress

Open your browser and navigate to:

```
https://<your_login>.42.fr
```

Example:

```
https://imeslaki.42.fr
```

From here you can:

- Browse the website
- Log in to the administration dashboard
- Create posts and pages
- Install themes and plugins
- Manage media files

The administrator credentials are generated during the initial setup and stored as Docker Secrets.

---

## Portfolio

The portfolio website is available through NGINX.

```
https://<your_login>.42.fr/portfolio/
```

The portfolio is an independent ASP.NET application that showcases personal information and projects.

---

## Adminer

Adminer provides a web interface for managing the MariaDB database.

Open:

```
https://<your_login>.42.fr/adminer/
```

Use the following information to connect.

| Setting | Value |
|----------|-------|
| System | MariaDB |
| Server | mariadb |
| Username | WordPress database user |
| Password | Stored in Docker Secrets |
| Database | WordPress database |

Once connected you can:

- Browse tables
- Execute SQL queries
- Export the database
- Import SQL dumps

---

## Netdata

Infrastructure monitoring is available at:

```
https://<your_login>.42.fr/netdata/
```

The dashboard provides real-time information including:

- CPU usage
- Memory usage
- Disk activity
- Network traffic
- Docker container statistics

---

## FTP Server

FTP allows direct access to the WordPress files.

Typical connection settings:

| Setting | Value |
|----------|-------|
| Host | `<your_login>.42.fr` |
| Port | 21 (or configured FTP port) |
| Username | FTP user |
| Password | Stored in Docker Secrets |

After connecting, uploaded files become immediately available to both WordPress and NGINX because they share the same persistent volume.

---

# 7. Managing the Infrastructure

The project is managed through the provided Makefile.

## Start

If the containers already exist but are stopped:

```bash
make start
```

---

## Stop

To stop all containers without removing them:

```bash
make stop
```

Persistent data remains intact.

---

## Restart

Restart the infrastructure by stopping and starting the containers.

```bash
make stop

make start
```

---

## Rebuild

To rebuild every Docker image:

```bash
make re
```

This command rebuilds the infrastructure while preserving persistent data.

---

## Remove Containers and Images

```bash
make clean
```

This removes:

- Containers
- Images
- Networks

Persistent volumes are preserved.

---

## Complete Reset

```bash
make fclean
```

This removes:

- Containers
- Images
- Networks
- Docker Volumes
- Generated Secrets

Running `make` after `make fclean` performs a completely fresh installation.

---

# 8. Docker Compose Commands

Advanced users may prefer interacting directly with Docker Compose.

## View Running Containers

```bash
docker compose -f srcs/docker-compose.yml ps
```

---

## Follow Logs

```bash
docker compose -f srcs/docker-compose.yml logs -f
```

Specific service:

```bash
docker compose -f srcs/docker-compose.yml logs -f wordpress
```

---

## Restart a Service

```bash
docker compose -f srcs/docker-compose.yml restart nginx
```

---

## Stop a Service

```bash
docker compose -f srcs/docker-compose.yml stop redis
```

---

## Build a Single Service

```bash
docker compose -f srcs/docker-compose.yml build wordpress
```

---

## Open a Shell

Example:

```bash
docker exec -it wordpress sh

docker exec -it mariadb sh

docker exec -it nginx sh
```

This is useful for debugging or inspecting container contents.

---

# 9. Persistent Data

The infrastructure stores application data in Docker named volumes.

| Volume | Stores |
|----------|--------|
| `wordpress_data` | WordPress files, uploads, themes, plugins |
| `mariadb_data` | MariaDB database |

These volumes survive:

- Container removal
- Image rebuilds
- Infrastructure updates

They are removed only after executing:

```bash
make fclean
```

---
---

# 10. Using the Services

This section describes the basic usage of each service after the infrastructure has been deployed.

---

## WordPress

WordPress is the main application of the infrastructure.

### Logging In

Open:

```
https://<your_login>.42.fr/wp-admin
```

Authenticate using the administrator credentials generated during the initial setup.

After logging in you can:

- Create and edit pages
- Publish blog posts
- Upload media
- Install plugins
- Install themes
- Manage users
- Configure WordPress settings

---

### Media Uploads

Media files uploaded through the WordPress dashboard are stored inside the shared `wordpress_data` volume.

Because NGINX, WordPress, and FTP all mount the same volume, uploaded files are immediately available across all services.

---

### Redis Cache

Redis is configured automatically during the installation.

To verify that the cache is active:

1. Log in to the WordPress dashboard.
2. Navigate to the Redis plugin page.
3. Confirm that the cache status is **Connected**.

No manual Redis configuration is required.

---

## Adminer

Adminer is a lightweight database management interface.

It can be used to:

- Browse tables
- Execute SQL queries
- Import SQL dumps
- Export databases
- Inspect table structures

Typical login parameters:

| Field | Value |
|--------|-------|
| System | MariaDB |
| Server | mariadb |
| Username | WordPress database user |
| Password | Generated during setup |
| Database | WordPress database |

Adminer should only be used for database administration and debugging.

---

## FTP

The FTP service provides direct access to the WordPress files.

Typical operations include:

- Upload themes
- Upload plugins
- Download backups
- Modify website files
- Remove unused content

Any modification performed through FTP becomes immediately visible because the FTP container shares the same persistent volume with WordPress and NGINX.

---

## Portfolio

The Portfolio service hosts an independent ASP.NET application.

It is available at:

```
https://<your_login>.42.fr/portfolio/
```

Since it is independent from WordPress, updating the portfolio does not affect the main website.

---

## Netdata

Netdata provides real-time monitoring of the infrastructure.

Available information includes:

- CPU usage
- Memory usage
- Network activity
- Disk I/O
- Running processes
- Docker container statistics

Netdata is useful for observing resource usage while testing the infrastructure.

---

# 11. Common Maintenance Tasks

## View Running Containers

```bash
docker compose -f srcs/docker-compose.yml ps
```

---

## View Logs

All services:

```bash
docker compose -f srcs/docker-compose.yml logs
```

Specific service:

```bash
docker compose -f srcs/docker-compose.yml logs -f wordpress
```

---

## Restart a Service

Example:

```bash
docker compose -f srcs/docker-compose.yml restart nginx
```

---

## Rebuild a Service

```bash
docker compose -f srcs/docker-compose.yml build wordpress

docker compose -f srcs/docker-compose.yml up -d wordpress
```

---

## Access a Container

```bash
docker exec -it wordpress sh

docker exec -it mariadb sh

docker exec -it nginx sh
```

---

## Inspect Volumes

```bash
docker volume ls

docker volume inspect wordpress_data

docker volume inspect mariadb_data
```

---

## Inspect Network

```bash
docker network ls

docker network inspect inception_network
```

---

# 12. Troubleshooting

The following table lists common problems and their solutions.

| Problem | Possible Cause | Solution |
|----------|----------------|----------|
| Website unavailable | NGINX not running | Check `docker compose ps` and restart NGINX |
| 502 Bad Gateway | PHP-FPM unavailable | Verify the WordPress container is running |
| Database connection error | MariaDB unavailable | Check MariaDB logs and restart the service |
| Redis cache disabled | Plugin not enabled | Verify Redis plugin status in WordPress |
| FTP connection refused | FTP container stopped | Restart the FTP service |
| Adminer cannot connect | Incorrect database credentials | Verify the database username and password |
| HTTPS certificate warning | Self-signed certificate | Accept the certificate or regenerate it |
| Uploaded files disappear | Persistent volume removed | Restore the Docker volume or recreate the infrastructure |

---

## Viewing Logs

The first step when troubleshooting should always be checking the logs.

Example:

```bash
docker compose -f srcs/docker-compose.yml logs -f nginx

docker compose -f srcs/docker-compose.yml logs -f wordpress

docker compose -f srcs/docker-compose.yml logs -f mariadb
```

Most startup and configuration issues can be identified from the container logs.

---

## Resetting the Infrastructure

If the infrastructure becomes inconsistent, perform a complete reset.

```bash
make fclean

make
```

This removes all generated data and performs a fresh installation.

> **Warning:** This operation permanently deletes the database, uploaded files, Docker volumes, and generated secrets.

---

# 13. Frequently Asked Questions

### Why are there multiple containers?

Each container has a single responsibility. This separation improves modularity, simplifies maintenance, and follows Docker best practices.

---

### Why is only NGINX exposed to the Internet?

NGINX acts as the reverse proxy and central entry point for web traffic. Keeping backend services private reduces the attack surface and improves security.

---

### What happens if a container is removed?

Containers are **temporary**. Removing a container does not affect persistent data stored in Docker volumes.

---

### Where is the website stored?

The website files are stored in the `wordpress_data` Docker volume.

---

### Where is the database stored?

The MariaDB database is stored in the `mariadb_data` Docker volume.

---

### What does `make fclean` remove?

It removes:

- All containers
- All images
- Docker volumes
- Docker network
- Generated secrets

The next execution of `make` recreates the infrastructure from scratch.

---

# 14. Additional Resources

For a high-level overview of the project, installation instructions, and design decisions, refer to:

- **README.md**

For implementation details, architecture diagrams, and developer-oriented documentation, refer to:

- **DEV_DOC.md**

Official documentation:

- Docker Engine Documentation
- Docker Compose Documentation
- NGINX Documentation
- WordPress Documentation
- MariaDB Documentation
- Redis Documentation
- ASP.NET Documentation
- Netdata Documentation