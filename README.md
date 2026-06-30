# Docker From Zero

A self-contained, hands-on guide to Docker. Instead of treating images, containers, networking, and Compose as separate isolated topics, this guide groups them the way you'd actually encounter them while building something: understand the model first, then run things, then connect things, then build things, then configure and harden things.

> **How to use this:** read top to bottom once if you're new to Docker. If you already know the basics, jump to whichever section title matches your question — each one is written to stand on its own.

## Contents

- **Part I — The Mental Model**: [Containers vs. VMs](#containers-vs-vms) · [Images vs. Containers](#images-vs-containers)
- **Part II — Running Things**: [Container Lifecycle](#container-lifecycle) · [What Isolation Actually Is](#what-isolation-actually-is) · [PID 1 and Signals](#pid-1-and-signals) · [Restart Policies](#restart-policies) · [First-Run Bootstrapping](#first-run-bootstrapping)
- **Part III — Images**: [Layers and the Build Cache](#layers-and-the-build-cache) · [Tags and Digests](#tags-and-digests) · [Registries](#registries)
- **Part IV — Storage**: [Volumes, Bind Mounts, and tmpfs](#volumes-bind-mounts-and-tmpfs)
- **Part V — Connecting Containers**: [Bridge Networks and DNS](#bridge-networks-and-dns) · [Startup Order vs. Readiness](#startup-order-vs-readiness)
- **Part VI — Building Images**: [Writing a Dockerfile](#writing-a-dockerfile) · [CMD vs. ENTRYPOINT](#cmd-vs-entrypoint) · [Multi-Stage Builds](#multi-stage-builds)
- **Part VII — Multi-Container Apps**: [Compose Basics](#compose-basics) · [Compose Command Reference](#compose-command-reference)
- **Part VIII — Configuration**: [Environment Variables](#environment-variables) · [Secrets, Properly](#secrets-properly)
- **Part IX — Things to Avoid**: [Six Anti-Patterns](#six-anti-patterns)
- **Appendix**: [Command Cheat Sheet](#command-cheat-sheet) · [FAQ](#faq)

---

## Part I — The Mental Model

### Containers vs. VMs

The fastest way to understand a container is to compare it to what came before: the virtual machine.

A VM virtualizes a *computer*. A hypervisor carves up physical hardware and gives each VM its own kernel, its own boot process, its own full operating system — even if all you wanted was to run one small app. A container virtualizes a *process*. It shares the host machine's kernel and uses kernel-level isolation (covered in [What Isolation Actually Is](#what-isolation-actually-is)) to make a process believe it has a machine to itself, without the overhead of actually booting one.

| | Virtual Machine | Container |
|---|---|---|
| What's isolated | Hardware, via a hypervisor | A process, via the kernel |
| Boots | An entire OS | The application itself |
| Disk footprint | Gigabytes | Often megabytes |
| Cold start | Seconds–minutes | Milliseconds–seconds |
| Kernel | One per VM | Shared with the host |

Neither is strictly "better" — VMs give you a stronger isolation boundary (a full separate kernel), which still matters for some multi-tenant or security-sensitive workloads. Containers trade a bit of that boundary for speed and density. Most application deployment today uses containers for exactly that tradeoff.

### Images vs. Containers

People use "image" and "container" interchangeably in casual conversation, but they're different things, and the difference matters the moment you try to debug something.

Think of an image the way you'd think of a class in object-oriented programming, and a container the way you'd think of an instance of that class:

```
        ┌─────────────┐
        │    IMAGE     │   read-only template
        │  (the class) │   (filesystem snapshot + metadata)
        └──────┬───────┘
               │  docker run
       ┌───────┼───────┐
       ▼       ▼       ▼
  ┌─────────┐ ┌─────────┐ ┌─────────┐
  │CONTAINER│ │CONTAINER│ │CONTAINER│   running instances
  │   #1    │ │   #2    │ │   #3    │   (the objects)
  └─────────┘ └─────────┘ └─────────┘
```

One image, many containers. Each container gets its own thin writable layer on top of the shared, read-only image — so you can spin up ten containers from the same image, and changes made inside one don't affect the others or the image itself. Delete every container that came from an image, and the image is untouched; you can `docker run` it again at any time.

---

## Part II — Running Things

### Container Lifecycle

```
docker create  →  created
docker start   →  running
docker pause   →  paused      (optional, rarely used)
docker stop    →  stopped
docker rm      →  (gone)
```

In daily use you'll mostly reach for `docker run`, which is `create` + `start` in one step:

```bash
docker run -d --name web nginx:1.27          # detached: runs in the background
docker run -it ubuntu:24.04 bash             # interactive: attaches a terminal
docker stop web                              # graceful stop
docker rm web                                # remove once stopped
docker rm -f web                             # force: stop + remove in one shot
```

### What Isolation Actually Is

Containers aren't a Docker invention — Docker is a friendly interface over two Linux kernel features that have existed independently for years:

**Namespaces** decide what a process *can see*. Each namespace type hides a different slice of the system from the container:

| Namespace | Hides / isolates |
|---|---|
| PID | Other processes — a container only sees its own process tree |
| NET | Network interfaces, IPs, ports |
| MNT | Mounted filesystems |
| UTS | Hostname |
| IPC | Inter-process communication channels |

**Cgroups** decide what a process *can use* — CPU time, memory, disk I/O. When you run `docker run --memory=512m --cpus=1.5 myapp`, cgroups are the mechanism actually enforcing those limits at the kernel level.

Put together: namespaces make the container *think* it's alone on the machine, and cgroups make sure it doesn't take more than its fair share even though it isn't.

### PID 1 and Signals

The first process inside a container is PID 1 within its own PID namespace — same role as `init`/`systemd` on a full Linux box, with the same special obligations:

1. **No default signal handlers.** If your application doesn't explicitly catch `SIGTERM`, `docker stop` sends it, gets no response, waits out a grace period (10s by default), and then escalates to `SIGKILL`. Clean shutdowns require your app to actually listen for the signal.
2. **Zombie reaping.** PID 1 is responsible for cleaning up exited child processes. A shell script or a Node `npm start` wrapper as PID 1 often doesn't do this correctly, which is how containers quietly accumulate zombie processes over a long uptime.

The common fix is a minimal init process in front of your app:

```bash
docker run --init myapp     # Docker injects tini as PID 1 for you
```

`tini` forwards signals correctly and reaps zombies, so your application process — running as its child — doesn't need to reimplement either.

### Restart Policies

```bash
docker run --restart=no <image>              # default — never restarts automatically
docker run --restart=on-failure:5 <image>     # restart on crash, give up after 5 tries
docker run --restart=unless-stopped <image>   # restart on crash or reboot, but not after a manual stop
docker run --restart=always <image>           # restart unconditionally, even after a manual stop
```

For a long-running service, `unless-stopped` is the policy most people actually want: it recovers from crashes and host reboots, but doesn't immediately fight you when you intentionally run `docker stop`.

### First-Run Bootstrapping

Some setup work should happen exactly once — the first time a container ever starts — and never again on later restarts. The standard pattern is an entrypoint script that checks for a marker file before doing the one-time work:

```bash
#!/bin/sh
# docker-entrypoint.sh
set -e

if [ ! -f /var/lib/app/.bootstrapped ]; then
  echo "First boot detected — running setup"
  ./scripts/init-schema.sh
  touch /var/lib/app/.bootstrapped
fi

exec "$@"
```

```dockerfile
COPY docker-entrypoint.sh /usr/local/bin/
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["node", "server.js"]
```

`exec "$@"` at the end matters more than it looks: without `exec`, the script stays as PID 1 and your app runs as its *child*, which means signals sent to the container go to the script, not the app. With `exec`, the app process replaces the script and takes over PID 1 directly.

---

## Part III — Images

### Layers and the Build Cache

Every instruction in a Dockerfile that touches the filesystem produces a new read-only layer, stacked on the ones before it. Two consequences follow directly from this:

- **Layers are shared.** Two images both built `FROM node:20-alpine` share that base layer on disk — Docker doesn't store it twice.
- **Layers are cached.** `docker build` compares each instruction's inputs to its last run. The first instruction whose inputs changed forces a cache miss for itself *and every instruction after it* — cache hits don't resume once broken.

```bash
docker history myapp:latest    # see the layer stack and the size each one added
```

That cache-invalidation rule is the whole reason Dockerfile instruction order is worth thinking about — see [Writing a Dockerfile](#writing-a-dockerfile).

### Tags and Digests

```
[registry-host/]namespace/repository[:tag]
```

A tag is a mutable, human-readable pointer — `myapp:1.4`, `postgres:16`, `node:20-alpine`. The same tag can point to a different underlying image tomorrow than it does today, which is exactly what happens with `:latest`. For a reproducible build or deployment, pin to a specific version tag, or better, an immutable digest:

```bash
docker pull postgres:16                                              # mutable-ish, version-pinned
docker pull postgres@sha256:8f1a3b...                                 # immutable, exact content
```

### Registries

A registry stores and serves images. Docker Hub is the public default; private registries (GHCR, ECR, GitLab Container Registry, a self-hosted Harbor instance) all speak the same protocol:

```bash
docker pull ghcr.io/yourorg/yourapp:2.3
docker push ghcr.io/yourorg/yourapp:2.3
docker login ghcr.io
```

When you write `docker pull redis`, Docker silently expands it to `docker.io/library/redis:latest` — the registry host and tag both have implicit defaults you're relying on without realizing it.

---

## Part IV — Storage

### Volumes, Bind Mounts, and tmpfs

Containers are disposable by design; your data usually isn't. Docker gives you three different ways to handle that mismatch, and picking the right one depends on who should own the data and how long it should live.

```bash
# Named volume — Docker manages the storage location
docker volume create app-data
docker run -v app-data:/var/lib/app/data myapp

# Bind mount — maps a specific host path directly in
docker run -v "$(pwd)/src":/app/src myapp

# tmpfs — lives in RAM only, never touches disk
docker run --tmpfs /app/tmp myapp
```

| | Named volume | Bind mount | tmpfs |
|---|---|---|---|
| Who owns the path | Docker | You | Nobody — it's memory |
| Survives `docker rm` | Yes | Yes | No |
| Best for | App/database data | Local dev, injected config | Secrets-in-use, scratch space |

A good way to actually convince yourself volumes persist — rather than just trusting the docs — is to remove the container entirely and start a fresh one against the same volume:

```bash
docker volume create demo
docker run --rm -v demo:/data busybox sh -c "echo persisted > /data/check.txt"
docker run --rm -v demo:/data busybox cat /data/check.txt
# -> persisted
```

The second container never existed when the first one wrote the file — the data outlived the container because it lived in the volume, not in the container's own writable layer.

---

## Part V — Connecting Containers

### Bridge Networks and DNS

```bash
docker network create app-net
docker run --network app-net --name cache redis:7
docker run --network app-net --name api myapi
```

Any two containers on the same user-defined bridge network can reach each other directly, and — this is the part people find genuinely useful — Docker runs an embedded DNS server on that network that resolves **container names** to IPs automatically:

```bash
# from inside the 'api' container:
redis-cli -h cache ping
# -> PONG, resolved by name, no hardcoded IP anywhere
```

> The network Docker creates automatically if you don't make your own (literally named `bridge`) does **not** get this DNS behavior — name resolution only works on networks you explicitly create. This alone is reason enough to always make a dedicated network for a multi-container project rather than relying on the default.

### Startup Order vs. Readiness

`depends_on` controls the order containers *start* in. It says nothing about whether the dependency is actually ready to accept work:

```yaml
services:
  api:
    depends_on:
      - cache        # cache's container starts before api's — that's the entire guarantee
  cache:
    image: redis:7
```

A database container can be "running" while the database engine inside it is still initializing. Two ways to close that gap:

**Healthchecks**, which let Compose wait for actual readiness rather than just process start:

```yaml
services:
  cache:
    image: redis:7
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 3s
      retries: 5
  api:
    depends_on:
      cache:
        condition: service_healthy
```

**A retry loop in the app itself**, which is the more robust option overall since it also handles the dependency going away briefly *after* startup — a restart, a network blip — not just the first few seconds.

---

## Part VI — Building Images

### Writing a Dockerfile

```dockerfile
FROM node:20-alpine
WORKDIR /app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

ENV PORT=3000
EXPOSE 3000

USER node
CMD ["node", "server.js"]
```

Quick notes on the less self-explanatory lines:

- `COPY package*.json ./` before `COPY . .` is deliberate, not accidental — see the caching note below.
- `EXPOSE` is documentation for humans (and for `docker run -P`), not enforcement. The actual port mapping happens at `docker run -p host:container`.
- `ENV` values get baked into the image and are visible to anyone who runs it — never put real credentials here.
- `USER node` drops from root to a non-privileged user before the container's main process starts.

**Order for caching:** put whatever changes least often first. Dependency manifests (`package.json`, `requirements.txt`, `go.sum`) change rarely; application source changes constantly. Installing dependencies *before* copying source means editing a single source file doesn't force a full dependency reinstall on every build:

```dockerfile
# Good — dependency layer only invalidates when package.json actually changes
COPY package*.json ./
RUN npm ci
COPY . .
```

```dockerfile
# Bad — any source edit invalidates the dependency-install layer too
COPY . .
RUN npm ci
```

### CMD vs. ENTRYPOINT

Both specify what runs at container start, but they compose with `docker run` arguments differently:

- `CMD` is a *default* — fully replaced if you pass a command at `docker run`.
- `ENTRYPOINT` is *fixed* — anything you pass at `docker run` is appended as arguments to it instead of replacing it.

```dockerfile
ENTRYPOINT ["node", "server.js"]
CMD ["--port=3000"]
```

```bash
docker run myapp                  # node server.js --port=3000
docker run myapp --port=8080      # node server.js --port=8080   (CMD's default replaced)
```

This pairing — a fixed `ENTRYPOINT` with an overridable default `CMD` — is the standard shape for an image meant to act like a dedicated command-line tool rather than a generic shell environment.

### Multi-Stage Builds

Keep build-time tooling out of the image you actually ship:

```dockerfile
# Stage 1: build
FROM golang:1.22 AS builder
WORKDIR /src
COPY . .
RUN CGO_ENABLED=0 go build -o /out/app

# Stage 2: run
FROM gcr.io/distroless/static-debian12
COPY --from=builder /out/app /app
ENTRYPOINT ["/app"]
```

The final image contains the compiled binary and nothing else — no Go compiler, no source code, no package manager. Smaller image, smaller attack surface, and the build tooling never even ships.

---

## Part VII — Multi-Container Apps

### Compose Basics

```yaml
services:
  api:
    build: ./api
    ports:
      - "3000:3000"
    environment:
      - REDIS_URL=redis://cache:6379
    depends_on:
      cache:
        condition: service_healthy
    networks:
      - backend

  cache:
    image: redis:7
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
    networks:
      - backend

networks:
  backend:
```

The shape to internalize: `services` is one entry per container, `build` compiles a local Dockerfile while `image` pulls a prebuilt one (a service can declare both — Compose builds and tags it), and `networks`/`volumes` get declared once at the top level and referenced by name inside each service. Compose also wires up a project-wide bridge network automatically, so service names resolve via DNS between containers without any manual `docker network create` step.

A standalone `docker run` container and a Compose-managed one are the same underlying object — Compose is an orchestration convenience, not a different container runtime. What you actually gain from it is everything starting and stopping together as one unit, automatic name-based networking between services, and configuration that lives in a reviewable file instead of a long shell history of `docker run` flags.

### Compose Command Reference

```bash
docker compose up -d --build     # build + start everything, detached
docker compose down              # stop and remove containers + network
docker compose down -v           # also wipe named volumes
docker compose ps                # status of every service in the project
docker compose logs -f api       # follow one service's logs
docker compose exec api sh       # shell into a running service
docker compose restart api       # restart a single service without touching the rest
```

A thin Makefile in front of these is a common convenience for teams who don't want to memorize Compose flags:

```makefile
.PHONY: up down logs shell

up:
	docker compose up -d --build

down:
	docker compose down

logs:
	docker compose logs -f

shell:
	docker compose exec api sh
```

---

## Part VIII — Configuration

### Environment Variables

The standard way to make one image behave differently across dev, staging, and production, without baking any of that difference into the image itself:

```bash
docker run -e LOG_LEVEL=debug -e PORT=3000 myapp
```

```dockerfile
ENV PORT=3000
```

Override order, from least to most specific: `ENV` in the Dockerfile sets the baked-in default, and anything passed at `docker run -e` or under Compose's `environment:` key overrides it at runtime.

Compose also reads a `.env` file automatically and substitutes those values **into the Compose file itself**:

```dotenv
# .env
APP_PORT=3000
LOG_LEVEL=info
```

```yaml
services:
  api:
    ports:
      - "${APP_PORT}:3000"
    environment:
      - LOG_LEVEL=${LOG_LEVEL}
```

Two details that trip people up: `.env` interpolation happens at *parse time*, not automatically inside every container, so a variable from `.env` still has to be explicitly listed under `environment:` to actually land inside a service. And since `.env` files often hold real credentials, they belong in `.gitignore`, with a committed `.env.example` (placeholder values only) for teammates to copy.

### Secrets, Properly

Environment variables are convenient but not private — they're visible via `docker inspect`, in `/proc/<pid>/environ`, and often in logs. For actual credentials, a mounted file is the better tool:

```yaml
services:
  api:
    secrets:
      - db_password
    environment:
      - DB_PASSWORD_FILE=/run/secrets/db_password

secrets:
  db_password:
    file: ./secrets/db_password.txt
```

```bash
# inside the app, read the file path the env var points to — not the value directly
DB_PASSWORD=$(cat "$DB_PASSWORD_FILE")
```

This `_FILE` convention is widely supported by official images directly — Postgres's image accepts `POSTGRES_PASSWORD_FILE` out of the box, for instance — precisely because a mounted secret file doesn't show up in `docker inspect`, can be locked down to `0400` permissions, and can be rotated by overwriting the file rather than rebuilding or recreating the container.

The same pattern extends naturally to TLS termination at a reverse proxy:

```yaml
services:
  nginx:
    image: nginx:1.27
    ports:
      - "443:443"
    secrets:
      - tls_cert
      - tls_key
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro

secrets:
  tls_cert:
    file: ./secrets/cert.pem
  tls_key:
    file: ./secrets/key.pem
```

`nginx` handles HTTPS at the edge using the mounted certificate and key, then forwards plain HTTP to `api` over the internal Docker network — the application container never has to deal with TLS itself, and the private key never ends up baked into any image layer.

---

## Part IX — Things to Avoid

### Six Anti-Patterns

**1. Reaching for `--network host` by default.** This drops a container into the host's own network namespace — no isolated IP, no port mapping, and DNS-based service discovery stops applying entirely. Occasionally justified for specific performance reasons; a poor default reach just to dodge `-p` flags.

**2. Using `--link`.** A deprecated, pre-DNS way of connecting two standalone containers. It's fragile — links break across container restarts since they're tied to container IDs — and fully superseded by [user-defined bridge networks](#bridge-networks-and-dns), which give every container automatic, restart-safe name resolution for free.

**3. Infinite-loop entrypoints.**

```dockerfile
CMD ["tail", "-f", "/dev/null"]    # avoid
```

This shows up when someone wants a container to "stay alive" for debugging and reaches for a no-op loop instead of running the real application. It makes `docker ps` and health checks meaningless, leaves no real PID 1 to receive signals (so `docker stop` falls through to a hard `SIGKILL`), and — worst of all — silently hides a crashing entrypoint by replacing it with something that can't crash. `docker exec -it <container> sh` works fine against a container running its actual process; there's no need to design around staying alive artificially.

**4. Running as root with no reason to.** Most official images default to a non-root user now, but custom images frequently don't bother. Set `USER` explicitly in the Dockerfile.

**5. Deploying on `:latest`.** Makes every deployment non-reproducible, since the same tag can point at a different image tomorrow than it does today. Pin a version (see [Tags and Digests](#tags-and-digests)).

**6. Treating the container's writable layer as storage.** Data written without a volume behind it disappears the instant someone runs a routine `docker rm` — often during cleanup, often without anyone noticing until it's needed.

---

## Appendix

### Command Cheat Sheet

| Task | Command |
|---|---|
| Run detached | `docker run -d --name <n> <image>` |
| Run interactively | `docker run -it <image> sh` |
| List running containers | `docker ps` |
| List all containers | `docker ps -a` |
| Stream logs | `docker logs -f <container>` |
| Shell into a running container | `docker exec -it <container> sh` |
| Stop / remove | `docker stop <c>` / `docker rm <c>` |
| Build an image | `docker build -t <name>:<tag> .` |
| List images | `docker images` |
| Remove unused images | `docker image prune` |
| Create a volume | `docker volume create <name>` |
| Create a network | `docker network create <name>` |
| Compose: start project | `docker compose up -d --build` |
| Compose: stop project | `docker compose down` |
| Compose: follow one service | `docker compose logs -f <service>` |

### FAQ

**Why does my container exit immediately after starting?**
Its main process exited. Unlike a VM, a container's lifetime is tied directly to its PID 1 process — when that process finishes (or crashes), the container stops, even if it finished successfully. Check `docker logs <container>` for what actually happened.

**Why can't two containers talk to each other by name?**
They're probably either on the default `bridge` network (which doesn't do name-based DNS — see [Bridge Networks and DNS](#bridge-networks-and-dns)) or on two different networks entirely. Put them on the same user-defined network.

**Why did my data disappear after I rebuilt the container?**
It was written to the container's writable layer instead of a volume. Rebuilding (as opposed to just restarting) throws that layer away. See [Volumes, Bind Mounts, and tmpfs](#volumes-bind-mounts-and-tmpfs).

**Should I use `ENV` or a secret file for a password?**
A secret file. `ENV` values are visible via `docker inspect` and process listings — fine for non-sensitive config, not for credentials. See [Secrets, Properly](#secrets-properly).

**My build is slow even though I only changed one line — why?**
Almost always instruction order. If a `COPY` of your whole source tree happens before your dependency install step, every source change invalidates the dependency cache too. See [Writing a Dockerfile](#writing-a-dockerfile).
