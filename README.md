# Docker LNMP (Local PHP Dev Environment)

A practical local stack for PHP projects:

- Nginx (TLS reverse proxy)
- PHP-FPM (default 8.4, optional 8.5 and 7.4)
- MariaDB
- Redis
- Mailpit (SMTP + inbox UI via Nginx)
- Ofelia (container cron)

This repository is optimized for local development with fixed container names and predictable versioning.

## Architecture

- Nginx proxies app traffic to PHP-FPM on the internal Docker network.
- MariaDB is exposed to host on `3306`.
- HTTPS is exposed on `443`.
- Mailpit is **not** directly exposed to host; access it through an Nginx vhost (for example: `mail.domain.com.conf.sample`).

## Prerequisites

- Docker Engine + Docker Compose plugin
- Local DNS/hosts entries for your dev domains
- TLS cert/key files if your vhost requires SSL

## Quick Start

1. Copy environment file.

```bash
cp .env.sample .env
```

2. Edit `.env` and set at least:

- `WEB_ROOT` (your local projects root)
- MariaDB credentials (`MARIADB_*`)

3. Create and enable an Nginx site config.

```bash
./nginx/scripts/sitectl.sh new your-site.conf
# edit nginx/conf/sites-available/your-site.conf
./nginx/scripts/sitectl.sh enable your-site.conf
```

4. Add SSL files if needed.

```bash
mkdir -p nginx/conf/ssl
# put *.crt and *.key in nginx/conf/ssl/
```

5. Start the default stack.

```bash
docker compose up -d
```

## Exposed Ports

- `443` -> Nginx
- `3306` -> MariaDB

Everything else stays internal by default.

## Multi-PHP Usage

Default PHP is from `docker-compose.yml` (`PHP_VERSION`, default `8.4.8`).

Start extra PHP versions with override files:

```bash
# add PHP 8.5
docker compose -f docker-compose.yml -f docker-compose.php85.yml up -d

# add PHP 7.4
docker compose -f docker-compose.yml -f docker-compose.php74.yml up -d

# run all (8.4 + 8.5 + 7.4)
docker compose -f docker-compose.yml -f docker-compose.php85.yml -f docker-compose.php74.yml up -d
```

Select PHP per site using Nginx snippet include:

```nginx
# PHP 8.4
include snippets/php-upstream-84.conf;

# PHP 8.5
include snippets/php-upstream-85.conf;

# PHP 7.4
include snippets/php-upstream-74.conf;
```

## Mailpit Integration

PHP uses Mailpit sendmail bridge:

```ini
sendmail_path = "/usr/local/bin/mailpit sendmail --smtp-addr=mailpit:1025"
```

Mailpit service is internal only. To view inbox, proxy `mailpit:8025` through an Nginx vhost.

## Environment Variables (Important)

### Core runtime

- `PHP_VERSION`
- `MARIADB_VERSION`
- `NGINX_VERSION`
- `WEB_ROOT`
- `NGINX_CONFIG`
- `PHP_CONFIG`

### MariaDB (clarified naming)

- `MARIADB_DATABASE`
- `MARIADB_USER`
- `MARIADB_PASSWORD`
- `MARIADB_ROOT_PASSWORD`
- `MARIADB_TZ`
- `MARIADB_DATA_DIR`

### Pinned image versions

- `MAILPIT_VERSION_IMAGE`
- `REDIS_VERSION`
- `OFELIA_VERSION`

### Build-time Mailpit binary version (inside PHP image)

- `MAILPIT_BINARY_VERSION`

### Ofelia

- `DOCKER_SOCKET`
- `OFELIA_CONFIG`

## Daily Commands

```bash
# start / stop
docker compose up -d
docker compose down

# logs
docker compose logs -f nginx
docker compose logs -f php-fpm

# shell into php container
docker exec -it -u www-data php-fpm /bin/bash

# validate compose (base)
docker compose -f docker-compose.yml config

# validate compose (with extra php versions)
docker compose -f docker-compose.yml -f docker-compose.php85.yml -f docker-compose.php74.yml config
```

## Nginx Site Management Helper

```bash
./nginx/scripts/sitectl.sh list
./nginx/scripts/sitectl.sh new mysite.conf
./nginx/scripts/sitectl.sh enable mysite.conf
./nginx/scripts/sitectl.sh disable mysite.conf
```

## Healthchecks

Core services include healthchecks in Compose:

- `nginx`
- `php-fpm` (and php74/php85 when enabled)
- `mysql`
- `redis`
- `mailpit`

This improves startup ordering and visibility via `docker compose ps`.

## Troubleshooting

- **Nginx 502/Bad Gateway**
  - Check `php-fpm` container is healthy: `docker compose ps`
  - Check vhost uses correct upstream snippet (`84/85/74`).

- **DB connection failed**
  - Confirm `.env` credentials and `MARIADB_DATABASE` match app config.
  - Confirm `mysql` is healthy and port `3306` is free on host.

- **Mail not visible**
  - Confirm app uses PHP `mail()` or SMTP to `mailpit:1025`.
  - Confirm Mailpit vhost proxies to `mailpit:8025`.

## License

MIT License. See [LICENSE](LICENSE).
