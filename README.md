*This project has been created as part of the 42 curriculum by **Ilyas Meslakiam**.*

# Inception

## Description

**Inception** is a system administration and containerization project that focuses on designing, building, and deploying a complete multi-service web infrastructure using **Docker** and **Docker Compose**.

Rather than installing applications directly on the operating system, every service runs inside its own isolated container with a single responsibility. The entire infrastructure is built from custom Docker images and orchestrated through Docker Compose, allowing every component to communicate securely over a private Docker network while remaining isolated from the host system.

The project introduces the core concepts behind modern infrastructure deployment, including containerization, reverse proxying, persistent storage, service orchestration, TLS encryption, Docker networking, and secret management.

Unlike a traditional deployment where all applications share the same environment, each service in this project is completely independent, making the infrastructure modular, reproducible, portable, and easier to maintain.

---

## Mandatory Services

The mandatory infrastructure consists of three services:

- **NGINX**
  - HTTPS reverse proxy
  - TLS 1.2 / TLS 1.3 termination
  - Single public entry point

- **WordPress + PHP-FPM**
  - Dynamic web application
  - Executes PHP code
  - Connects to MariaDB

- **MariaDB**
  - Persistent relational database
  - Stores all WordPress data

These services communicate exclusively through a dedicated Docker bridge network and persist their data using Docker named volumes.

---

## Bonus Services

This repository extends the mandatory infrastructure with additional production-oriented services:

| Service | Purpose |
|----------|----------|
| Redis | WordPress object caching |
| Adminer | Database administration |
| FTP | Remote management of WordPress files |
| Portfolio (.NET) | Personal portfolio website |
| Netdata | Infrastructure monitoring |

Together these services demonstrate how multiple independent applications can cooperate inside a single containerized environment while preserving isolation and maintainability.

---

# Features

## Infrastructure

- Multi-container architecture
- Docker Compose orchestration
- Custom Docker images
- Service isolation
- Automatic service discovery
- Persistent Docker volumes
- Docker secrets
- Environment-based configuration
- TLS secured communication
- Internal DNS resolution

---

## Web Stack

- NGINX reverse proxy
- WordPress with PHP-FPM
- MariaDB database
- Redis object cache

---

## Administration

- Browser-based database management
- FTP access to WordPress files
- Real-time infrastructure monitoring

---

## Development

- Automated setup using Make
- One-command deployment
- Reproducible builds
- Modular directory structure

---

# Instructions

## Prerequisites

Before deploying the infrastructure, ensure the following software is installed:

- Linux Host or Virtual Machine
- Docker Engine
- Docker Compose
- GNU Make
- OpenSSL

Configure your local DNS by adding the project domain to your hosts file:

```bash
echo "127.0.0.1 imeslaki.42.fr" | sudo tee -a /etc/hosts
```

---

## Build & Run

Start the complete infrastructure:

```bash
make
```

The Makefile automatically:

- Creates Docker secrets
- Generates TLS certificates
- Creates persistent storage directories
- Builds every Docker image
- Creates Docker volumes
- Creates the Docker network
- Starts every container

Once the deployment finishes, open:

```
https://imeslaki.42.fr
```

Accept the locally generated certificate if your browser displays a security warning.

---

## Make Targets

```bash
make            # Build images and start every service
make start      # Start existing containers
make stop       # Stop all running containers
make clean      # Remove containers and images
make fclean     # Remove containers, images, volumes and secrets
make re         # Full rebuild
```

---

For detailed usage instructions, refer to **USER_DOC.md**.

For implementation details, architecture, networking, and development internals, refer to **DEV_DOC.md**.

---

# Project Overview

The infrastructure follows a **service-oriented architecture**, where every application executes inside an independent Docker container.

Each container performs a single responsibility and communicates with the others through Docker's internal networking.

The infrastructure is composed of:

- Two public entry points
- Seven internal application containers
- Two persistent storage volumes
- One private Docker bridge network
- Docker secrets
- Environment configuration
- Automated initialization scripts

This architecture closely resembles a simplified production deployment while remaining lightweight enough to run on a single virtual machine.


# Infrastructure Architecture

The project follows a **layered service-oriented architecture** where each application is deployed in its own Docker container and performs a single responsibility. Services communicate through a private Docker bridge network using Docker's embedded DNS, while only selected entry points are exposed to the outside world.

The infrastructure is composed of three logical layers:

- **Public Access Layer**
  - Receives incoming client connections.
  - Exposes HTTPS and FTP services.
  - Acts as the boundary between the Internet and the internal infrastructure.

- **Application Layer**
  - Hosts all business logic and application services.
  - Contains WordPress, Portfolio, Adminer and Netdata.
  - Accessible only through the reverse proxy.

- **Data Layer**
  - Stores and manages application data.
  - Contains MariaDB and Redis.
  - Never directly accessible from outside the Docker network.

This separation keeps every service isolated while allowing controlled communication between containers.

---

## High-Level Architecture

```text
                                    Host Machine
══════════════════════════════════════════════════════════════════════════════════════

                               Docker Engine / Docker Compose

               Internet                                     Internet
                   │                                             │
          HTTPS :443                                     FTP :21 / Passive Ports
                   │                                             │
             ┌─────▼─────┐                                 ┌─────▼─────┐
             │   NGINX   │                                 │    FTP    │
             │ Reverse   │                                 │  Server   │
             │  Proxy    │                                 └─────┬─────┘
             └─────┬─────┘                                       │
                   │                                             │
═══════════════════╪══════════════ inception_network ════════════╪══════════════════
                   │                                             │
                   │                                             │
        ┌──────────┼───────────────┬──────────────┬───────────────┐
        │          │               │              │               │
        ▼          ▼               ▼              ▼               ▼
 ┌────────────┐ ┌──────────┐ ┌──────────┐ ┌────────────┐ ┌────────────┐
 │ WordPress  │ │Portfolio │ │ Adminer  │ │  Netdata   │ │   Redis    │
 │  PHP-FPM   │ │  (.NET)  │ │          │ │ Monitoring │ │ ObjectCache│
 └─────┬──────┘ └──────────┘ └──────────┘ └────────────┘ └─────┬──────┘
       │                                                       │
       │ SQL                                                   │
       │                                                       │
       ▼                                                       │
 ┌────────────┐                                                │
 │  MariaDB   │◄───────────────────────────────────────────────┘
 └─────┬──────┘
       │
       │
       ▼
 ┌───────────────┐
 │ mariadb_data  │
 └───────────────┘


 Shared Persistent Volume

 ┌──────────────────────────────────────────────────────────────┐
 │                     wordpress_data                           │
 └───────────────┬───────────────────────────────┬──────────────┘
                 │                               │
                 ▼                               ▼
           WordPress                        NGINX
                 ▲
                 │
                FTP
```

---

## Network Architecture

The infrastructure relies on a **user-defined Docker bridge network** that enables secure communication between containers while isolating internal services from the host machine.

Docker automatically provides:

- Internal DNS resolution.
- Automatic IP allocation.
- Service discovery using container names.
- Network isolation.
- Secure inter-container communication.

Instead of using static IP addresses, services communicate using their Compose service names.

For example:

| Source | Destination |
|----------|-------------|
| NGINX | WordPress |
| NGINX | Portfolio |
| NGINX | Adminer |
| NGINX | Netdata |
| WordPress | MariaDB |
| WordPress | Redis |

This approach eliminates manual network configuration and makes the infrastructure portable across different environments.

---

## Public Entry Points

Only two services expose ports to the host machine.

| Service | Purpose | Public Access |
|----------|----------|---------------|
| **NGINX** | HTTPS Reverse Proxy | Yes |
| **FTP** | File Transfer | Yes |

Every other container remains private inside the Docker network.

This significantly reduces the attack surface by ensuring that databases, caches, monitoring tools, and application servers cannot be accessed directly from outside the infrastructure.

---

## Persistent Storage

Application data is stored in Docker **named volumes**, allowing information to survive container recreation or image updates.

| Volume | Mounted By | Purpose |
|----------|------------|----------|
| **wordpress_data** | WordPress, NGINX, FTP | Website files |
| **mariadb_data** | MariaDB | Database files |

The `wordpress_data` volume is shared between three containers:

- WordPress updates the website files.
- NGINX serves static assets directly from the same filesystem.
- FTP provides remote access for file management.

The `mariadb_data` volume stores all database files independently of the MariaDB container lifecycle.

---

## Secrets Management

Sensitive information is managed through **Docker Secrets** instead of hardcoding credentials into Docker images or environment variables.

Secrets include:

- MariaDB root password.
- MariaDB user password.
- WordPress administrator password.
- FTP credentials.
- TLS certificate.
- TLS private key.

Each secret is mounted inside the appropriate container at runtime under:

```text
/run/secrets/
```

This approach improves security by keeping confidential information outside the source code and Docker images.

---

## Service Responsibilities

| Service | Responsibility |
|----------|----------------|
| **NGINX** | Reverse proxy, HTTPS termination, request routing |
| **WordPress** | Website application and PHP execution |
| **MariaDB** | Persistent relational database |
| **Redis** | WordPress object cache |
| **Adminer** | Database administration interface |
| **Portfolio** | Personal portfolio application |
| **FTP** | Remote management of website files |
| **Netdata** | Infrastructure monitoring |

Each service follows the **single responsibility principle**, making the infrastructure modular, maintainable, and easy to extend.

---

For a detailed explanation of the infrastructure design, networking model, startup sequence, request lifecycle, storage architecture, security considerations, and implementation details, see **DEV_DOC.md**.



# Repository Structure

The project is organized to separate infrastructure orchestration from service implementations. Each service resides in its own directory, containing everything required to build and initialize its Docker image.

```text
.
├── Makefile
├── README.md
├── DEV_DOC.md
├── USER_DOC.md
└── srcs
    ├── docker-compose.yml          # Infrastructure definition
    ├── .env                        # Non-sensitive configuration
    ├── secrets/                    # Docker secrets (git ignored)
    └── requirements
        ├── nginx/
        ├── wordpress/
        ├── mariadb/
        ├── tools/
        └── bonus/
            ├── redis/
            ├── adminer/
            ├── ftp/
            ├── portfolio/
            └── netdata/
```

Each service directory contains its own source code, Dockerfile, configuration files, and initialization scripts, making every container independent and self-contained.

---

# Technologies

| Category | Technologies |
|-----------|--------------|
| Containerization | Docker |
| Orchestration | Docker Compose |
| Reverse Proxy | NGINX |
| Web Application | WordPress + PHP-FPM |
| Database | MariaDB |
| Cache | Redis |
| Database Administration | Adminer |
| File Transfer | vsftpd |
| Portfolio | ASP.NET |
| Monitoring | Netdata |
| Operating System | Debian |

---

# Project Highlights

The project demonstrates several core infrastructure concepts commonly found in modern production environments.

### Containerization

Every application runs inside its own isolated Docker container with a single responsibility.

### Reverse Proxy

NGINX acts as the single HTTPS gateway, routing requests to the appropriate backend service.

### Service Isolation

Application services communicate exclusively through Docker's private bridge network, preventing direct external access.

### Persistent Storage

Named Docker volumes preserve website files and database data independently of the container lifecycle.

### Secure Configuration

Sensitive information is managed using Docker Secrets, while non-sensitive configuration is provided through environment variables.

### Automated Deployment

The entire infrastructure can be built and deployed using a single command.

---

# Documentation

This repository includes dedicated documentation for both users and developers.

| Document | Description |
|-----------|-------------|
| **README.md** | High-level overview of the project, architecture, installation, and repository organization. |
| **USER_DOC.md** | Installation guide, deployment instructions, administration tasks, troubleshooting, and day-to-day usage. |
| **DEV_DOC.md** | Complete technical documentation covering architecture, Docker networking, volumes, secrets, request flow, startup sequence, service implementation, and development workflow. |

If you are evaluating or using the project, begin with **USER_DOC.md**.

If you want to understand how the infrastructure is designed or contribute to the project, continue with **DEV_DOC.md**.

---

# Learning Objectives

This project was developed to gain practical experience with:

- Linux system administration
- Docker image creation
- Multi-container orchestration
- Docker Compose
- Reverse proxies
- HTTPS and TLS
- Docker networking
- Persistent storage
- Docker volumes
- Docker secrets
- Environment configuration
- Infrastructure automation
- Production-oriented deployment practices

---

# Resources

The following resources were used throughout the development of this project.

## Docker

- Docker Documentation
- Docker Compose Documentation
- Docker Networking
- Docker Volumes
- Docker Secrets

## Official Documentation

- NGINX
- WordPress
- PHP-FPM
- MariaDB
- Redis
- Adminer
- ASP.NET
- Netdata

These resources were used to understand each technology and implement the infrastructure according to Docker best practices and the requirements of the 42 Inception project.

---

# Acknowledgements

This project was completed as part of the **42 School** curriculum.

It represents a practical introduction to containerized infrastructure by combining multiple independent services into a reproducible, secure, and maintainable deployment using Docker Compose.

---

# Additional Documentation

The README intentionally provides a high-level overview of the project.

For more detailed information, consult the accompanying documentation:

- 📘 **USER_DOC.md** — Complete user guide, installation, configuration, maintenance, and troubleshooting.
- 🛠️ **DEV_DOC.md** — Technical reference covering the internal architecture, networking, Docker Compose configuration, service interactions, storage model, security considerations, and implementation details.

Together, these documents provide comprehensive documentation for both users and developers.

---

# License

This repository is distributed for educational purposes as part of the **42 School** curriculum.

The project may be used as a learning resource, but all technologies, trademarks, and third-party software remain the property of their respective owners.