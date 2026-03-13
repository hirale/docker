# Docker LNMP

Local development environment: **Nginx → PHP-FPM → MariaDB**, with Redis, Mailpit, and Ofelia (cron).

## Stack

| Service | Default | Notes |
|---------|---------|-------|
| Nginx | 1.27.x | Reverse proxy, SSL termination |
| PHP-FPM | 8.4 | Multi-version support via Compose override files (7.4/8.4/8.5) |
| MariaDB | 10.11 | With healthcheck |
| Redis | `${REDIS_VERSION}` | Session/cache store |
| Mailpit | `${MAILPIT_VERSION_IMAGE}` | Local mail testing, proxied through Nginx (no direct host port) |
| Ofelia | `${OFELIA_VERSION}` | Docker-native cron scheduler |

## Getting Started

### 1. Configure environment

```bash
cp .env.sample .env
# Edit .env — set WEB_ROOT to your projects directory
```

### 2. Configure Nginx sites

```bash
# Create a new site from template
./nginx/scripts/sitectl.sh new your-site.conf

# Edit nginx/conf/sites-available/your-site.conf
# Then enable it
./nginx/scripts/sitectl.sh enable your-site.conf
```

### 3. Set up SSL (optional)

```bash
mkdir -p nginx/conf/ssl
# Place your .crt and .key files in nginx/conf/ssl/
```

### 4. Start the stack

```bash
docker compose up -d
```

Default exposed host ports:
- `443` for Nginx
- `3306` for MariaDB

### Mailpit Sendmail (PHP `mail()` support)

This stack uses Mailpit's native sendmail command inside PHP containers:

```ini
sendmail_path = "/usr/local/bin/mailpit sendmail --smtp-addr=mailpit:1025"
```

`MAILPIT_BINARY_VERSION` is pinned in `.env`/`.env.sample` for reproducible PHP image builds.
To upgrade: bump `MAILPIT_BINARY_VERSION`, then rebuild PHP images:

```bash
docker compose build php-fpm
docker compose -f docker-compose.yml -f docker-compose.php85.yml build php85-fpm
docker compose -f docker-compose.yml -f docker-compose.php74.yml build php74-fpm
```

Service image tags are also pinned in `.env`:
- `MAILPIT_VERSION_IMAGE`
- `REDIS_VERSION`
- `OFELIA_VERSION`

MariaDB env keys use the `MARIADB_*` prefix for clarity:
- `MARIADB_DATABASE`, `MARIADB_USER`, `MARIADB_PASSWORD`
- `MARIADB_ROOT_PASSWORD`, `MARIADB_TZ`, `MARIADB_DATA_DIR`

### Multi-PHP Version Support

The default stack runs PHP 8.4 from `docker-compose.yml` (`PHP_VERSION=8.4.8`).
Start additional PHP versions with override files:

```bash
# Start PHP 8.5 alongside default
docker compose -f docker-compose.yml -f docker-compose.php85.yml up -d

# Start PHP 7.4 alongside default
docker compose -f docker-compose.yml -f docker-compose.php74.yml up -d

# Start everything
docker compose -f docker-compose.yml -f docker-compose.php85.yml -f docker-compose.php74.yml up -d
```

Then point your Nginx site config to the desired PHP-FPM upstream:

```nginx
# Default PHP 8.4
include sites-conf/php-upstream-84.conf;

# PHP 8.5
include sites-conf/php-upstream-85.conf;

# PHP 7.4
include sites-conf/php-upstream-74.conf;
```

### Mailpit UI via Nginx

Mailpit is not exposed directly on the host.
Use an Nginx vhost (for example `nginx/conf/sites-enabled/mail.domain.com.conf.sample`) that proxies to `mailpit:8025`.

### Useful Commands

```bash
# Enter PHP container as www-data
docker exec -it -u www-data php-fpm /bin/bash

# View logs
docker compose logs -f php-fpm

# Rebuild PHP after Dockerfile changes
docker compose build php-fpm

# Validate merged compose
docker compose -f docker-compose.yml -f docker-compose.php85.yml config

# Clean container logs
./clean_logs.sh
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
