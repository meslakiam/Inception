# DEV_DOC.md

> Internal technical documentation for the Inception infrastructure.

This document describes the internal architecture, implementation details, and engineering decisions behind the project. It is intended for developers who want to understand, maintain, extend, or troubleshoot the infrastructure.

Unlike **README.md**, which provides a high-level overview, this document focuses on how the infrastructure is designed, how each service interacts with the others, and why specific architectural decisions were made.

For installation, deployment, and day-to-day administration, refer to **USER_DOC.md**.

---

# 1. Introduction

## Purpose

The goal of this project is to design and deploy a complete containerized web infrastructure while following the architectural constraints defined by the 42 Inception subject.

Instead of relying on pre-built application images, every service is built from a custom Docker image and deployed through Docker Compose.

The project demonstrates the fundamental concepts behind production infrastructure, including:

- Container isolation
- Reverse proxying
- Service orchestration
- Persistent storage
- Secure configuration management
- Internal service discovery
- HTTPS termination
- Infrastructure monitoring

Although the deployment runs on a single virtual machine, the architecture intentionally follows the same separation of responsibilities used in larger production environments.

---

## Design Goals

Several design principles guided the implementation of this infrastructure.

### Service Isolation

Each container performs a single responsibility.

Rather than combining multiple applications into a single container, every major component is isolated into its own runtime environment.

Examples:

- NGINX only proxies requests.
- WordPress only executes PHP.
- MariaDB only stores relational data.
- Redis only provides caching.
- FTP only manages files.

This separation simplifies maintenance, improves security, and makes each component independently replaceable.

---

### Modular Architecture

Every service is completely self-contained.

Each directory contains everything required to build that service:

- Dockerfile
- Configuration
- Startup scripts
- Runtime assets

As a result, modifying one service has little or no impact on the rest of the infrastructure.

---

### Reproducibility

Infrastructure should be reproducible from source.

Running

```bash
make
```

must always produce the same deployment regardless of the host machine (assuming Docker is installed).

No manual configuration should be required after cloning the repository.

---

### Persistent State

Containers are intentionally treated as disposable.

Destroying or recreating a container should never result in data loss.

Persistent information is therefore stored outside containers using Docker named volumes.

This allows:

- rebuilding images,
- updating services,
- recreating containers,

without affecting website content or database data.

---

### Secure Configuration

Configuration is divided into two categories.

Non-sensitive configuration is stored in:

```
.env
```

Sensitive information is stored separately as Docker Secrets.

Examples include:

- database passwords,
- WordPress administrator password,
- TLS certificate,
- TLS private key.

This prevents confidential information from becoming part of Docker images or the Git repository.

---

# 2. Architecture Overview

## System Architecture

The infrastructure follows a layered, service-oriented architecture deployed entirely through Docker Compose.

Rather than exposing every application directly to the Internet, all backend services are isolated inside a private Docker bridge network.

Only the services that must communicate with external clients expose ports on the host machine.

This creates two security boundaries:

1. **External Boundary**

   Services reachable directly from outside the host.

2. **Internal Boundary**

   Services accessible only through Docker networking.

The result is an architecture where every service has a clearly defined role, communication path, and trust boundary.

---

## Logical Layers

The infrastructure can be divided into four logical layers.

```text
                        +--------------------------------+
                        |        External Clients         |
                        +---------------+----------------+
                                        |
                 HTTPS                  |                  FTP
                                        |
        +-------------------------------+------------------------------+
        |                      Public Access Layer                     |
        +------------------------+-------------------+-----------------+
                                 |                   |
                              NGINX                FTP
                                 |
═════════════════════════════════╪═══════════════════════════════════════════
                                 |       Docker Bridge Network
                                 |
        +---------------------------------------------------------------+
        |                    Application Layer                          |
        +------------+--------------+--------------+---------------------+
                     |              |              |
                WordPress      Portfolio      Adminer
                     |
                     |
                  Netdata
                     |
        +---------------------------------------------------------------+
        |                       Data Layer                              |
        +----------------------------+----------------------------------+
                                     |
                             +-------+--------+
                             |                |
                          MariaDB          Redis
```

Each layer has a specific responsibility.

| Layer | Responsibility |
|--------|----------------|
| External | User interaction through HTTPS and FTP |
| Public Access | Controls every incoming connection |
| Application | Executes application logic |
| Data | Stores and caches persistent information |

This separation minimizes coupling between components while simplifying maintenance and troubleshooting.

---

# 3. High-Level Infrastructure

The complete deployment consists of nine independent services.

```text
                                         Host Machine

                             Docker Engine / Docker Compose

     Internet                                                     Internet
        │                                                             │
        │ HTTPS :443                                                  │ FTP :21
        ▼                                                             ▼
 ┌────────────────┐                                         ┌────────────────┐
 │     NGINX      │                                         │      FTP       │
 │ Reverse Proxy  │                                         │ File Transfer  │
 └────────┬───────┘                                         └───────┬────────┘
          │                                                         │
══════════╪════════════════════════ inception_network ══════════════╪══════════════
          │                                                         │
          │                                                         │
 ┌────────▼────────┐
 │   WordPress     │────────────────────────────┐
 │    PHP-FPM      │                            │
 └───────┬─────────┘                            │
         │                                      │
         │ SQL                                  │ Cache
         ▼                                      ▼
 ┌──────────────┐                      ┌────────────────┐
 │   MariaDB    │                      │     Redis      │
 └──────┬───────┘                      └────────────────┘
        │
        │
        ▼
 ┌────────────────┐
 │ mariadb_data   │
 └────────────────┘


            ┌────────────────┐
            │   Portfolio    │
            │     (.NET)     │
            └────────────────┘

            ┌────────────────┐
            │    Adminer     │
            └────────────────┘

            ┌────────────────┐
            │    Netdata     │
            └────────────────┘


 Shared Persistent Storage

 ┌────────────────────────────────────────────────────────────┐
 │                   wordpress_data                           │
 └──────────────┬──────────────────────────────┬──────────────┘
                │                              │
                ▼                              ▼
           WordPress                       NGINX
                ▲
                │
               FTP
```

---

## Architectural Characteristics

### Reverse Proxy Architecture

NGINX is the single HTTP/HTTPS gateway for the web infrastructure.

Rather than exposing multiple application servers, every HTTP request first reaches NGINX.

NGINX then decides which backend service should process the request based on the requested URL.

This provides:

- centralized TLS management,
- unified routing,
- simplified security,
- reduced attack surface.

---

### Private Service Network

All backend services communicate through Docker's embedded bridge network.

Containers never communicate using fixed IP addresses.

Instead, Docker automatically provides DNS resolution using service names.

Examples:

```
wordpress → mariadb
wordpress → redis
nginx → wordpress
nginx → portfolio
nginx → adminer
nginx → netdata
```

This makes the infrastructure portable because service discovery is independent of IP allocation.

---

### Persistent Storage Model

The infrastructure separates runtime from persistent state.

Containers remain ephemeral while data persists in Docker volumes.

Two named volumes are used.

| Volume | Purpose |
|---------|---------|
| wordpress_data | Website files |
| mariadb_data | Database storage |

Sharing `wordpress_data` between NGINX, WordPress, and FTP ensures that all three services operate on the same filesystem without duplicating data.

---

### Security Boundaries

The infrastructure intentionally minimizes externally accessible services.

Publicly exposed:

- HTTPS (NGINX)
- FTP

Private:

- WordPress
- MariaDB
- Redis
- Portfolio
- Adminer
- Netdata

This significantly reduces the number of services that can be reached directly from outside the Docker environment.

---

# 4. Repository Structure

The project is organized to clearly separate infrastructure orchestration from individual service implementations.

```text
.
├── Makefile
├── README.md
├── DEV_DOC.md
├── USER_DOC.md
└── srcs
    ├── docker-compose.yml
    ├── .env
    ├── secrets/
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

The repository is divided into three logical areas:

| Area | Purpose |
|-------|---------|
| Root directory | Project entry point and documentation |
| `srcs/` | Infrastructure definition |
| `requirements/` | Individual service implementations |

Every service is self-contained and includes all the files required to build its Docker image.

---

## Root Directory

The repository root contains the project entry point.

| File | Purpose |
|------|---------|
| `Makefile` | Automates the build, deployment, and cleanup workflow |
| `README.md` | Project overview |
| `DEV_DOC.md` | Internal technical documentation |
| `USER_DOC.md` | User guide |

The Makefile acts as the primary interface for interacting with the infrastructure.

---

## srcs/

The `srcs` directory contains everything required to deploy the infrastructure.

```text
srcs/
├── docker-compose.yml
├── .env
├── secrets/
└── requirements/
```

### docker-compose.yml

Defines the complete infrastructure, including:

- Services
- Networks
- Volumes
- Secrets
- Restart policies
- Build contexts
- Port mappings
- Service dependencies

Docker Compose is therefore responsible for orchestrating the entire deployment.

---

### .env

Stores non-sensitive configuration shared across services.

Typical examples include:

- domain name
- ports
- usernames
- database names
- volume paths

No passwords or confidential information should be stored inside this file.

---

### secrets/

Contains sensitive runtime configuration.

Examples include:

- database passwords
- WordPress credentials
- TLS certificate
- TLS private key

These files are mounted into containers as Docker Secrets during runtime.

---

### requirements/

Contains every Docker image used by the infrastructure.

Each service follows the same structure.

```text
service/
│
├── Dockerfile
├── conf/
├── tools/
└── assets/
```

Depending on the service, some directories may differ, but every container includes:

- Dockerfile
- configuration
- initialization scripts

This organization keeps every service independent and easy to maintain.

---

# 5. Build System

The infrastructure is built entirely through the Makefile.

Developers never interact directly with individual Dockerfiles during normal usage.

Instead, the Makefile provides a simplified interface for Docker Compose.

```text
Developer
      │
      ▼
 Makefile
      │
      ▼
 Docker Compose
      │
      ▼
 Docker Engine
      │
      ▼
 Containers
```

---

## Build Workflow

Executing

```bash
make
```

starts the complete deployment workflow.

The process can be summarized as follows.

```text
make
 │
 ├── Generate secrets
 │
 ├── Create certificates
 │
 ├── Create host directories
 │
 ├── Build Docker images
 │
 ├── Create Docker network
 │
 ├── Create Docker volumes
 │
 ├── Start containers
 │
 └── Infrastructure Ready
```

This process is fully automated and reproducible.

---

## Build Context

Each service defines its own build context.

Rather than sharing a common image, Docker builds every service independently.

```text
docker-compose.yml

      │
      ├──────── nginx/
      │
      ├──────── wordpress/
      │
      ├──────── mariadb/
      │
      ├──────── redis/
      │
      ├──────── adminer/
      │
      ├──────── ftp/
      │
      ├──────── portfolio/
      │
      └──────── netdata/
```

This approach provides:

- better modularity,
- independent builds,
- simpler debugging,
- easier maintenance.

---

## Docker Image Strategy

Every image is built locally from its corresponding Dockerfile.

No application-specific Docker Hub images are used.

Instead, the required software is installed during the image build process.

Advantages include:

- complete control over the environment,
- reproducible builds,
- explicit dependency management,
- easier customization.

---

# 6. Docker Compose Architecture

Docker Compose is responsible for orchestrating the entire infrastructure.

Instead of manually creating containers, networks, and volumes, the entire deployment is declared inside a single Compose file.

Compose automatically creates:

- all containers,
- the Docker bridge network,
- named volumes,
- Docker secrets,
- service dependencies.

This declarative approach ensures that the infrastructure can be recreated consistently on any compatible machine.

---

## Compose Responsibilities

The Compose configuration manages several aspects of the deployment.

### Service Definition

Each service specifies:

- image build context,
- container name,
- restart policy,
- exposed ports,
- mounted volumes,
- Docker secrets,
- environment variables,
- network membership.

---

### Network Management

Compose creates the private bridge network used by every service.

All containers automatically join this network unless explicitly configured otherwise.

Docker's embedded DNS enables service discovery using container names.

---

### Volume Management

Persistent storage is declared globally.

Compose creates the named volumes before the containers start and attaches them to the appropriate services.

This guarantees that persistent data survives container recreation.

---

### Secret Distribution

Docker Secrets are declared once and mounted only into the containers that require them.

This limits the exposure of confidential information.

---

### Dependency Management

Compose starts containers according to their declared dependencies.

For example:

```text
MariaDB
     │
     ▼
WordPress
     │
     ▼
NGINX
```

Although `depends_on` controls startup order, it does not guarantee application readiness.

Services requiring another application to be fully initialized implement their own readiness checks before continuing execution.

---

## Container Lifecycle

Every service follows the same lifecycle.

```text
Build Image
      │
      ▼
Create Container
      │
      ▼
Mount Volumes
      │
      ▼
Mount Secrets
      │
      ▼
Join Network
      │
      ▼
Execute Entrypoint
      │
      ▼
Start Main Process
      │
      ▼
Running
```

Keeping a single foreground process inside each container aligns with Docker's execution model and simplifies process management.

---


---

# 7. Request Lifecycle

Understanding how a client request traverses the infrastructure is essential to understanding the role of each service.

Every HTTP request follows a controlled path through the reverse proxy before reaching the application and data layers.

The general lifecycle is illustrated below.

```text
                     Client Browser
                           │
                    HTTPS Request
                           │
                           ▼
                      NGINX (443)
                           │
            Route Resolution & TLS Termination
                           │
      ┌────────────────────┼────────────────────┐
      │                    │                    │
      ▼                    ▼                    ▼
 WordPress            Portfolio            Adminer
    │
    │
 Redis Lookup
    │
 ┌──┴──────────────┐
 │ Cache Available?│
 └──────┬──────────┘
        │
   Yes  │                 No
        │                  │
        ▼                  ▼
 Response             MariaDB Query
                           │
                           ▼
                      Database Result
                           │
                           ▼
                     Generate Response
                           │
                           ▼
                        NGINX
                           │
                     HTTPS Response
                           │
                           ▼
                         Client
```

This architecture centralizes every web request through NGINX while keeping the backend services isolated from the Internet.

---

## Reverse Proxy Flow

NGINX is responsible for routing incoming requests to the appropriate backend service.

The routing strategy is based on the requested URL.

Examples include:

| Request | Destination |
|---------|-------------|
| `/` | WordPress |
| `/portfolio` | Portfolio (.NET) |
| `/adminer` | Adminer |
| `/netdata` | Netdata |

This approach offers several advantages:

- only one HTTPS endpoint,
- centralized TLS configuration,
- simplified firewall rules,
- hidden backend services,
- cleaner public interface.

Backend applications never communicate directly with external clients.

---

## WordPress Request Processing

When a request reaches WordPress, several internal operations occur.

```text
NGINX
   │
   ▼
PHP-FPM
   │
   ▼
WordPress
   │
   ├────────► Redis
   │
   │ Cache Hit
   │
   ▼
Response

or

WordPress
   │
   ▼
MariaDB
   │
   ▼
Response
```

WordPress first attempts to retrieve cached objects from Redis.

If the requested object exists in cache, no database query is necessary.

Otherwise:

1. WordPress queries MariaDB.
2. The result is returned.
3. Redis stores the object.
4. Future requests become significantly faster.

---

## Static File Requests

Not every request requires PHP execution.

When static resources are requested, NGINX serves them directly from the shared filesystem.

Examples include:

- CSS
- JavaScript
- Images
- Fonts
- Uploaded media

```text
Browser
    │
    ▼
NGINX
    │
    ▼
wordpress_data
    │
    ▼
Static File
```

This avoids unnecessary PHP execution and reduces server load.

---

## File Management Workflow

The FTP server provides direct access to the same persistent volume used by WordPress and NGINX.

```text
Developer
     │
 FTP Upload
     │
     ▼
FTP Container
     │
     ▼
wordpress_data
     │
 ┌───┴─────────┐
 │             │
 ▼             ▼
NGINX     WordPress
```

Because all three containers share the same volume, uploaded files become immediately available without synchronization.

---

## Monitoring Flow

Netdata continuously monitors the host and running containers.

```text
Containers
      │
      ▼
 Netdata
      │
      ▼
 Real-Time Metrics
      │
      ▼
 Browser
```

This allows administrators to observe infrastructure health while the system is running.

---

# 8. Infrastructure Components

Each container has a clearly defined responsibility within the infrastructure.

Rather than combining multiple services inside a single image, every application runs independently and communicates only through Docker networking.

The following sections describe each service individually, including:

- purpose,
- implementation,
- startup procedure,
- dependencies,
- communication model,
- persistent storage,
- configuration,
- security considerations.

---

# 8.1 NGINX

## Purpose

NGINX acts as the public entry point of the infrastructure.

Every HTTPS request reaches NGINX before any backend application.

It is responsible for:

- TLS termination,
- request routing,
- reverse proxying,
- serving static assets,
- forwarding client headers.

No backend application is directly exposed to the Internet.

---

## Responsibilities

NGINX performs several critical functions.

### TLS Termination

The TLS handshake is completed by NGINX.

Encrypted traffic is decrypted before forwarding requests through the internal Docker network.

Backend services never need to manage TLS certificates.

---

### Reverse Proxy

Incoming requests are forwarded to backend services according to the configured routes.

Example:

```text
Client
    │
HTTPS
    │
    ▼
NGINX
    │
 ┌──┼───────────────┬───────────────┐
 │  │               │               │
 ▼  ▼               ▼               ▼
WP Portfolio     Adminer       Netdata
```

The reverse proxy hides the internal topology from clients.

---

### Static File Serving

Static resources are served directly by NGINX.

This includes:

- images,
- CSS,
- JavaScript,
- uploaded media,
- fonts.

Serving static assets without PHP significantly improves response times.

---

### Header Forwarding

NGINX preserves important client information when proxying requests.

Forwarded headers include:

- original client IP,
- Host,
- protocol,
- forwarding chain.

This allows backend applications to generate accurate URLs and maintain correct request context.

---

## Communication

NGINX communicates with:

| Service | Purpose |
|----------|---------|
| WordPress | Reverse proxy |
| Portfolio | Reverse proxy |
| Adminer | Reverse proxy |
| Netdata | Reverse proxy |

NGINX does **not** communicate directly with MariaDB or Redis.

Its only responsibility is request routing.

---

## Shared Storage

NGINX mounts the `wordpress_data` volume.

This enables it to serve static WordPress assets directly without involving PHP-FPM.

Benefits include:

- lower latency,
- reduced CPU usage,
- fewer PHP processes,
- improved scalability.

---

## Startup Sequence

When the container starts:

1. Runtime configuration is initialized.
2. TLS certificates are loaded.
3. Configuration is validated.
4. NGINX starts in the foreground as the container's main process.

Running NGINX in the foreground allows Docker to manage the service lifecycle correctly and ensures that container status accurately reflects the state of the web server.

---


---

# 8.2 WordPress

## Purpose

The WordPress container hosts the main web application and is responsible for executing all PHP code requested by the web server.

Unlike a traditional LAMP stack, this container **does not include NGINX**. It only runs **PHP-FPM**, while NGINX remains responsible for handling HTTP requests and serving static content.

This separation follows the principle of **one service per container**, making the infrastructure easier to maintain, scale, and debug.

---

## Responsibilities

The WordPress container is responsible for:

- Running PHP-FPM
- Hosting the WordPress application
- Executing PHP scripts
- Connecting to MariaDB
- Communicating with Redis
- Managing plugins and themes
- Managing uploads
- Performing the initial WordPress installation
- Creating administrator accounts

Everything related to the application layer happens inside this container.

---

## Architecture

```
                   NGINX
                     │
             FastCGI Request
                     │
                     ▼
              PHP-FPM Process
                     │
                     ▼
                WordPress Core
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
      MariaDB                Redis
```

The container never communicates directly with clients.

All requests originate from NGINX through the FastCGI protocol.

---

## Startup Workflow

When the container starts, several initialization steps are executed before PHP-FPM begins serving requests.

```text
Container Starts
        │
        ▼
Read Docker Secrets
        │
        ▼
Generate wp-config.php
        │
        ▼
Wait for MariaDB
        │
        ▼
WordPress Installed?
        │
  ┌─────┴─────┐
  │           │
 Yes          No
  │           │
  │      Download Core
  │           │
  │      Configure Database
  │           │
  │      Install WordPress
  │           │
  │      Create Admin User
  │           │
  │      Create Normal User
  │           │
  └─────┬─────┘
        ▼
Configure Redis
        │
        ▼
Start PHP-FPM
```

The initialization script ensures that installation only occurs once.

Subsequent container restarts detect the existing installation and immediately launch PHP-FPM.

---

## Automatic Installation

Rather than requiring manual setup through the browser, the application is installed automatically during container initialization.

The startup script performs tasks such as:

- downloading WordPress (if necessary),
- generating the configuration,
- creating the database connection,
- installing the application,
- creating administrator credentials,
- creating additional users,
- enabling Redis,
- setting file permissions.

This makes the deployment completely reproducible.

---

## Waiting for MariaDB

Although Docker Compose starts MariaDB before WordPress, this does **not** guarantee that MariaDB is ready to accept connections.

The initialization script therefore implements its own readiness check.

```text
Start Container
      │
      ▼
Attempt Database Connection
      │
      ▼
Database Ready?
      │
 ┌────┴────┐
 │         │
 No        Yes
 │          │
Wait        Continue Installation
 │
Retry
```

Without this step, WordPress could attempt installation before MariaDB has finished initializing.

---

## PHP-FPM

PHP-FPM (FastCGI Process Manager) is responsible for executing PHP scripts.

Unlike traditional PHP modules embedded into Apache, PHP-FPM operates as an independent service.

Advantages include:

- process isolation,
- improved performance,
- better scalability,
- independent lifecycle management.

Communication with NGINX occurs through FastCGI.

```
Browser

   │

NGINX

   │ FastCGI

PHP-FPM

   │

WordPress
```

---

## Database Communication

Every dynamic request requiring persistent data is sent to MariaDB.

Examples include:

- login
- posts
- comments
- users
- settings
- plugins
- themes

```
WordPress
      │
SQL Query
      │
      ▼
MariaDB
      │
Result
      │
      ▼
WordPress
```

The database remains completely isolated from external clients.

---

## Redis Integration

To reduce database load, WordPress communicates with Redis before querying MariaDB.

```
WordPress

     │

Redis

     │

Cache Hit?

 │         │

Yes       No

 │         │

Return   MariaDB

            │

         Store Cache

            │

         Return Data
```

This caching strategy significantly reduces the number of SQL queries required for frequently accessed content.

---

## Persistent Storage

The container mounts the shared `wordpress_data` volume.

```
wordpress_data

      │

      ├──────── WordPress

      ├──────── NGINX

      └──────── FTP
```

The volume stores:

- WordPress core files
- themes
- plugins
- uploads
- media
- configuration

Sharing this volume ensures that:

- NGINX serves the latest files,
- FTP modifications appear immediately,
- application updates persist after container recreation.

---

## Communication Matrix

| Connected Service | Purpose |
|-------------------|---------|
| NGINX | FastCGI requests |
| MariaDB | Persistent storage |
| Redis | Object cache |
| FTP | Shared filesystem |
| Docker Volume | Website persistence |

---

## Security Considerations

Several security measures are implemented.

- No HTTP port is exposed publicly.
- PHP-FPM is accessible only through Docker networking.
- Credentials are loaded from Docker Secrets.
- Persistent data is separated from the container filesystem.
- Backend services cannot be reached directly from the Internet.

This minimizes the attack surface while keeping the application isolated behind the reverse proxy.

---

# 8.3 MariaDB

## Purpose

MariaDB provides the persistent relational database used by WordPress.

Unlike WordPress, which can be recreated at any time, MariaDB stores the application's permanent state.

Without the database, WordPress would lose:

- users,
- posts,
- pages,
- media references,
- comments,
- configuration,
- plugin settings,
- authentication data.

For this reason, MariaDB is one of the most critical services in the infrastructure.

---

## Responsibilities

MariaDB is responsible for:

- storing relational data,
- processing SQL queries,
- managing transactions,
- enforcing data integrity,
- authenticating database users.

Every persistent operation performed by WordPress ultimately reaches this service.

---

## Architecture

```
            WordPress
                 │
             SQL Queries
                 │
                 ▼
             MariaDB
                 │
                 ▼
          mariadb_data
```

The database is **never exposed publicly**.

Only the WordPress container is permitted to communicate with it over the private Docker bridge network.

---

## Initialization Workflow

When the MariaDB container starts, it performs several initialization tasks before launching the database server.

Typical operations include:

1. Reading Docker Secrets.
2. Creating the database directory.
3. Initializing the database if it does not already exist.
4. Starting the database daemon.
5. Creating the WordPress database.
6. Creating the application user.
7. Assigning user privileges.
8. Flushing privileges.

Because the database files are stored in a persistent volume, initialization only occurs during the first deployment.

Subsequent container restarts reuse the existing database without recreating users or tables.

---

# 8.4 Redis

## Purpose

Redis acts as an **in-memory object cache** for WordPress.

Instead of querying MariaDB for frequently accessed data, WordPress first checks Redis. If the requested object is already cached, it can be returned immediately without executing an SQL query.

```
                 WordPress
                      │
          Object Cache Lookup
                      │
            ┌─────────┴─────────┐
            │                   │
        Cache Hit          Cache Miss
            │                   │
            ▼                   ▼
       Return Data         MariaDB Query
                                │
                                ▼
                         Store in Redis
                                │
                                ▼
                           Return Data
```

### Responsibilities

- Store cached WordPress objects
- Reduce database queries
- Improve page response time
- Reduce MariaDB workload

### Communication

| Connected Service | Purpose |
|-------------------|---------|
| WordPress | Object cache |

Redis is completely internal and stores only temporary data. If the container is recreated, the cache is rebuilt automatically.

---

# 8.5 Adminer

## Purpose

Adminer provides a lightweight web interface for managing the MariaDB database.

Rather than exposing MariaDB directly, administrators connect to Adminer through NGINX.

```
Browser
    │
HTTPS
    │
NGINX
    │
Adminer
    │
MariaDB
```

### Responsibilities

- Execute SQL queries
- Browse tables
- Manage users
- Inspect database content

### Communication

| Connected Service | Purpose |
|-------------------|---------|
| MariaDB | Database management |
| NGINX | Reverse proxy |

Adminer is intended for administration only and is never accessed directly from the Internet.

---

# 8.6 FTP

## Purpose

The FTP container provides remote access to the WordPress filesystem.

Instead of communicating with WordPress through HTTP, developers can upload, modify or remove website files directly through FTP.

```
FTP Client
      │
      ▼
   FTP Server
      │
      ▼
wordpress_data
      │
 ┌────┴─────┐
 ▼          ▼
NGINX   WordPress
```

### Responsibilities

- File upload
- File download
- Remote file management

### Communication

| Connected Service | Purpose |
|-------------------|---------|
| wordpress_data | Shared filesystem |

FTP never communicates with MariaDB or Redis.

---

# 8.7 Portfolio (.NET)

## Purpose

The Portfolio service hosts a static ASP.NET application that presents personal information independently from WordPress.

NGINX proxies requests targeting the portfolio endpoint to the .NET application.

```
Browser
    │
HTTPS
    │
NGINX
    │
Portfolio
```

### Responsibilities

- Serve portfolio pages
- Deliver static assets
- Showcase personal projects

The application has no dependency on any other backend service.

---

# 8.8 Netdata

## Purpose

Netdata provides real-time monitoring of the infrastructure.

It continuously collects system metrics and presents them through a web dashboard.

```
Containers
      │
      ▼
   Netdata
      │
      ▼
Dashboard
```

### Responsibilities

- CPU monitoring
- Memory monitoring
- Disk monitoring
- Network monitoring
- Docker monitoring

NGINX proxies requests to the monitoring dashboard, allowing administrators to access it securely over HTTPS.

---

# 9. Docker Networking

## Network Architecture

All services are connected through a single **user-defined Docker bridge network**.

```
                        inception_network
────────────────────────────────────────────────────────────

          nginx
             │
 ┌───────────┼────────────┐
 │           │            │
 ▼           ▼            ▼
wordpress  portfolio   adminer
     │
 ┌───┴────┐
 ▼        ▼
redis   mariadb

ftp
 │
wordpress_data

netdata
```

Unlike the default Docker bridge network, a user-defined bridge provides:

- Automatic DNS resolution
- Service discovery
- Better container isolation
- Predictable communication

---

## Service Discovery

Docker automatically creates an internal DNS server.

Instead of using IP addresses, containers communicate using Compose service names.

Examples:

```
wordpress → mariadb

wordpress → redis

nginx → wordpress

nginx → portfolio

nginx → adminer

nginx → netdata
```

Because Docker manages name resolution internally, IP addresses may change without affecting the infrastructure.

---

## Public vs Private Services

Only two services expose ports on the host machine.

```
Internet

│

├──────── HTTPS (443) ─────► nginx

│

└──────── FTP (21) ─────────► ftp
```

All remaining services remain private inside the Docker bridge network.

| Public | Private |
|----------|----------|
| NGINX | WordPress |
| FTP | MariaDB |
| | Redis |
| | Adminer |
| | Portfolio |
| | Netdata |

This minimizes the attack surface by ensuring backend services cannot be accessed directly.

---

# 10. Persistent Storage

Containers are **temporary**, but application data must remain even if the container is deleted and recreated.

Persistent data is therefore stored in Docker named volumes.

```
                 wordpress_data
        ┌────────────┼─────────────┐
        │            │             │
        ▼            ▼             ▼
   WordPress      NGINX          FTP


                 mariadb_data
                      │
                      ▼
                  MariaDB
```

## wordpress_data

Shared by:

- WordPress
- NGINX
- FTP

Stores:

- WordPress core
- Plugins
- Themes
- Uploads
- Media
- Configuration

Sharing a single volume ensures every service works with the same files.

---

## mariadb_data

Mounted only by MariaDB.

Stores:

- Database tables
- Users
- Transactions
- Indexes
- Logs

Separating database storage from application storage prevents accidental coupling between services.

---

## Persistence Lifecycle

```
Container Deleted
        │
        ▼
 Docker Volume
        │
        ▼
 Data Preserved
        │
        ▼
New Container
        │
        ▼
Same Data Available
```

This allows infrastructure updates without data loss.

---

# 11. Secrets Management

Sensitive information is managed through **Docker Secrets**.

Rather than embedding credentials inside Docker images or environment variables, secrets are mounted as read-only files.

```
Host

│

Docker Secrets

│

/run/secrets/

│

Containers
```

Typical secrets include:

- MariaDB root password
- MariaDB user password
- WordPress administrator password
- FTP password
- TLS certificate
- TLS private key

---

## Why Docker Secrets?

Compared with environment variables, Docker Secrets provide several advantages.

| Environment Variables | Docker Secrets |
|----------------------|----------------|
| Visible through `docker inspect` | Mounted as files |
| Easy to leak into logs | Read only |
| Stored in container environment | Stored outside image |
| Less secure | More secure |

Only the containers requiring a particular secret receive access to it.

---

# 12. Infrastructure Startup Sequence

Although Docker Compose manages container startup order through `depends_on`, service startup and service readiness are different concepts.

The infrastructure therefore combines Docker Compose dependency ordering with application-level readiness checks.

```
                 make

                  │

                  ▼

           Docker Compose

                  │

                  ▼

        Create Network

                  │

                  ▼

        Create Volumes

                  │

                  ▼

        Build Images

                  │

                  ▼

       Start MariaDB

                  │

                  ▼

        Start Redis

                  │

                  ▼

      Start WordPress

                  │

 Wait until MariaDB Ready

                  │

                  ▼

      Install WordPress

                  │

                  ▼

       Start Portfolio

                  │

                  ▼

       Start Adminer

                  │

                  ▼

        Start Netdata

                  │

                  ▼

         Start NGINX

                  │

                  ▼

Infrastructure Ready
```

---

## Why Readiness Checks?

`depends_on` guarantees only that a container has been started.

It **does not guarantee** that the application inside the container is ready.

For example:

```
MariaDB Container Started

      │

Database Initialization

      │

Accept SQL Connections
```

If WordPress attempted installation immediately after the container started, the database might still be initializing.

To avoid this race condition, the WordPress startup script continuously checks database connectivity before performing installation.

This ensures a deterministic and reproducible deployment regardless of host performance or startup timing.

---

The following sections cover the infrastructure's security model, operational workflow, debugging techniques, and common troubleshooting scenarios encountered during development and deployment.


---

# 13. Security

The infrastructure follows the principle of **least privilege**, exposing only the services that must be accessible from outside the Docker environment while keeping every backend component isolated on the internal network.

Security is achieved through multiple independent layers rather than relying on a single mechanism.

---

## HTTPS Termination

All web traffic enters the infrastructure through NGINX using HTTPS.

```
Client
   │
HTTPS
   │
NGINX
   │
Internal HTTP/FastCGI
```

TLS encryption is terminated at the reverse proxy.

Backend containers communicate only through the private Docker bridge network and never expose their own HTTP endpoints publicly.

---

## Network Isolation

Every backend service belongs to the same private Docker bridge network.

```
Internet

      │

 ┌────┴────┐
 │  NGINX  │
 └────┬────┘
      │
═══════════════════════════════════════
 Private Docker Network
═══════════════════════════════════════

WordPress
MariaDB
Redis
Adminer
Portfolio
Netdata
```

Containers communicate only through Docker's embedded networking.

Neither MariaDB nor Redis exposes ports to the host machine.

---

## Secrets Protection

Sensitive information is never stored inside Docker images.

Credentials are distributed using Docker Secrets.

```
Host

│

Docker Secret

│

/run/secrets/

│

Container
```

Examples include:

- MariaDB passwords
- WordPress credentials
- FTP credentials
- TLS certificates

This reduces the risk of credential leakage through image inspection or version control.

---

## Persistent Data Isolation

Application state is separated from runtime.

```
Container

     │

Docker Volume

     │

Host Filesystem
```

Deleting a container does not delete persistent application data.

This allows infrastructure updates without affecting user content.

---

## Reverse Proxy Protection

Backend services are never contacted directly by clients.

Instead, NGINX validates every incoming request before forwarding it internally.

Advantages include:

- Centralized TLS management
- Single public endpoint
- Simplified firewall configuration
- Hidden internal topology

---

# 14. Development Workflow

The project follows a reproducible workflow that allows the entire infrastructure to be rebuilt from source.

```
Clone Repository

        │

        ▼

Configure Environment

        │

        ▼

Generate Secrets

        │

        ▼

Build Images

        │

        ▼

Create Infrastructure

        │

        ▼

Development

        │

        ▼

Testing

        │

        ▼

Deployment
```

---

## Typical Development Cycle

### Build Infrastructure

```bash
make
```

Builds every Docker image and starts the complete infrastructure.

---

### View Running Services

```bash
docker compose ps
```

Displays the status of every container.

---

### Follow Logs

```bash
docker compose logs -f nginx

docker compose logs -f wordpress

docker compose logs -f mariadb
```

Logs are the first source of information when debugging startup issues.

---

### Enter a Container

```bash
docker exec -it wordpress sh

docker exec -it mariadb sh

docker exec -it nginx sh
```

Interactive shells simplify debugging and configuration verification.

---

### Rebuild a Single Service

```bash
docker compose build wordpress

docker compose up -d wordpress
```

Rebuilding only the modified service significantly reduces development time.

---

### Clean the Infrastructure

```bash
make clean
```

Removes containers and images while preserving persistent data.

---

### Full Reset

```bash
make fclean
```

Removes:

- Containers
- Images
- Networks
- Volumes
- Generated secrets

The next deployment starts from a completely clean state.

---

# 15. Troubleshooting

The following table summarizes the most common issues encountered during development.

| Problem | Possible Cause | Solution |
|----------|----------------|----------|
| WordPress cannot connect to MariaDB | Database not ready | Verify MariaDB logs and readiness checks |
| 502 Bad Gateway | PHP-FPM unavailable | Verify WordPress container is running |
| Redis not used | Plugin disabled | Check Redis plugin configuration |
| HTTPS unavailable | TLS certificate missing | Regenerate secrets and rebuild |
| FTP login fails | Invalid credentials | Verify Docker Secrets |
| Database data missing | Volume removed | Restore or recreate persistent volume |

---

## Useful Commands

Container status

```bash
docker compose ps
```

View logs

```bash
docker compose logs -f <service>
```

Inspect containers

```bash
docker inspect <container>
```

Inspect volumes

```bash
docker volume ls

docker volume inspect <volume>
```

Inspect networks

```bash
docker network ls

docker network inspect inception_network
```

Resource usage

```bash
docker stats
```

Running processes

```bash
docker exec <container> ps aux
```

---

## Debugging Strategy

When diagnosing an issue, investigate the infrastructure from the bottom layer upward.

```
Docker Engine

      │

Docker Network

      │

Volumes

      │

MariaDB

      │

Redis

      │

WordPress

      │

NGINX

      │

Client
```

Since every service depends on lower layers, this approach minimizes unnecessary investigation.

---

# 17. Conclusion

The Inception project demonstrates how multiple independent services can be combined into a secure, maintainable, and reproducible containerized infrastructure.

Rather than treating Docker as a simple packaging tool, the project applies software architecture principles to infrastructure design by separating responsibilities across dedicated containers, defining explicit communication paths, and isolating persistent state from runtime environments.

Key architectural characteristics include:

- One responsibility per container
- Layered service architecture
- Private inter-container networking
- Reverse proxy entry point
- Persistent storage through Docker volumes
- Secure secret distribution
- Automated infrastructure provisioning
- Reproducible deployments

The resulting system closely resembles the architecture of a small production environment while remaining simple enough to understand, maintain, and extend.

---

# References

The implementation and architectural decisions in this project were based on the following official documentation and technical resources.

## Docker

- Docker Engine Documentation
- Docker Compose Specification
- Dockerfile Reference
- Docker Networking
- Docker Volumes
- Docker Secrets

## Web Technologies

- NGINX Documentation
- PHP-FPM Documentation
- WordPress Documentation
- WP-CLI Documentation
- MariaDB Documentation
- Redis Documentation
- Adminer Documentation
- ASP.NET Documentation
- Netdata Documentation
