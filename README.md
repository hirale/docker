# Docker LNMP (Local PHP Dev Environment)

A practical local stack for PHP projects:

- Nginx (TLS reverse proxy)
- PHP-FPM (default 8.4, optional 8.5 and 7.4)
- MySQL
- Redis
- Mailpit (SMTP + inbox UI via Nginx)
- Ofelia (container cron)
- Certbot (SSL via DNS-01, 117+ providers)

## Quick Start

```bash
# 1. Copy and edit environment file
cp .env.sample .env
# Edit .env — set WEB_ROOT, MYSQL_* credentials

# 2. Create an Nginx site
make site-new NAME=my-site.conf
# Edit nginx/sites-available/my-site.conf
make site-enable NAME=my-site.conf

# 3. Add SSL certs (manual or via certbot)
mkdir -p nginx/certs
# put *.crt and *.key in nginx/certs/

# 4. Start
make up
```

Run `make help` to see all available commands.

## Project Structure

```
.
├── compose.yml                  # Core LNMP services + certbot
├── compose.observability.yml    # Observability stack (optional)
├── compose.php74.yml            # PHP 7.4 addon
├── compose.php85.yml            # PHP 8.5 addon
├── Makefile                     # Shortcut commands
├── .env.sample                  # Environment template
├── config.ini.example           # Ofelia cron config template
│
├── certbot/                     # SSL certificate management
│   ├── credentials/             # DNS provider credential files
│   ├── conf/                    # Let's Encrypt state (gitignored)
│
├── nginx/
│   ├── nginx.conf
│   ├── certs/                   # SSL certificates (gitignored)
│   ├── sites-available/         # Site configs (gitignored)
│   ├── sites-enabled/           # Enabled sites (symlinks, gitignored)
│   └── snippets/                # Reusable config snippets
│
├── php-fpm/
│   ├── Dockerfile
│   └── conf/                    # PHP config (php.ini, etc.)
│
├── loki/                        # Loki config (observability)
├── alloy/                       # Alloy config (observability)
├── grafana/                     # Grafana provisioning + dashboards
├── prometheus/                  # Prometheus config
│
└── scripts/
    ├── db.sh                    # Database helper
    ├── site.sh                  # Nginx site management
    ├── xdebug.sh                # Xdebug toggle
    └── logs.sh                  # Container log truncation
```

## Compose Structure

The stack is split into composable files:

| File | Services | Default |
|---|---|---|
| `compose.yml` | nginx, php-fpm, mysql, mailpit, redis, ofelia, certbot | Yes |
| `compose.observability.yml` | loki, alloy, grafana, prometheus, exporters, glitchtip | No |
| `compose.php74.yml` | php74-fpm | No |
| `compose.php85.yml` | php85-fpm | No |

```bash
# Core only
make up

# Core + observability
make up-obs

# Core + PHP 8.5
make up-php85

# Core + PHP 7.4
make up-php74

# Everything
make up-all
```

Or use `docker compose` directly:

```bash
docker compose up -d
docker compose -f compose.yml -f compose.observability.yml up -d
docker compose -f compose.yml -f compose.php85.yml up -d
```

## Exposed Ports

- `443` -> Nginx
- `3306` -> MySQL

Everything else stays internal by default.

## Multi-PHP Usage

Default PHP is from `compose.yml` (`PHP_VERSION`, default `8.4.8`).

Select PHP per site using Nginx snippet include:

```nginx
# PHP 8.4
include snippets/php-upstream-84.conf;

# PHP 8.5
include snippets/php-upstream-85.conf;

# PHP 7.4
include snippets/php-upstream-74.conf;
```

## SSL Certificates (Certbot)

Certbot runs as an on-demand container using `certbot-dns-multi` (supports 117+ DNS providers via lego).

### Setup

1. Copy a credential template:

```bash
cp certbot/credentials/cloudflare.ini.example certbot/credentials/cloudflare.ini
# Edit with your API token
chmod 600 certbot/credentials/cloudflare.ini
```

2. Issue a certificate:

```bash
make ssl-issue DOMAIN=example.com EMAIL=you@email.com CRED=cloudflare
```

3. Renew:

```bash
make ssl-renew
```

### Supported DNS Providers

Create a credential file in `certbot/credentials/` for your provider. See `.ini.example` files for format:

- Cloudflare (`cloudflare.ini`)
- DigitalOcean (`digitalocean.ini`)
- Porkbun (`porkbun.ini`)
- GoDaddy (`godaddy.ini`)
- Route53, Google Cloud, Namecheap, and 110+ more via [lego](https://go-acme.github.io/lego/dns/)

## Mailpit Integration

PHP uses Mailpit sendmail bridge:

```ini
sendmail_path = "/usr/local/bin/mailpit sendmail --smtp-addr=mailpit:1025"
```

Mailpit service is internal only. To view inbox, proxy `mailpit:8025` through an Nginx vhost.

## Observability

The observability stack includes:

- **Loki** — log aggregation
- **Alloy** — log shipper (replaces Promtail)
- **Grafana** — dashboards + log explorer
- **Prometheus** — metrics collection
- **Exporters** — mysqld, redis, nginx metrics
- **GlitchTip** — Sentry-protocol error tracking

### Quick Start

```bash
# Copy and configure observability configs from their .example files
cp loki/config.yaml.example loki/config.yaml
cp alloy/config.alloy.example alloy/config.alloy
cp prometheus/prometheus.yml.example prometheus/prometheus.yml
# Edit each file to match your project paths and labels

make up-obs
```

Access Grafana via your configured Nginx vhost (proxied to `grafana:3000`).

## Database Helper (`scripts/db.sh`)

```bash
./scripts/db.sh list                                    # List databases
./scripts/db.sh shell                                   # Open MySQL REPL
./scripts/db.sh shell my_project_db                     # Open MySQL REPL for a database
./scripts/db.sh export my_project_db                    # Export to sql/
./scripts/db.sh ensure my_project_db                    # Create DB + user
./scripts/db.sh import ./sql/dump.sql.gz my_project_db  # Import
./scripts/db.sh copy my_project_db my_project_db_copy   # Clone
```

See `./scripts/db.sh help` for all options.

## Nginx Site Management (`scripts/site.sh`)

```bash
make site-list                    # List available/enabled sites
make site-new NAME=my-site.conf   # Create from template
make site-enable NAME=my-site.conf
make site-disable NAME=my-site.conf
```

## Xdebug (`scripts/xdebug.sh`)

Xdebug is disabled by default. Toggle it without editing files manually:

```bash
make xdebug-on      # Enable + restart php-fpm
make xdebug-off     # Disable + restart php-fpm
make xdebug-status  # Show current state
```

IDE settings: host `host.docker.internal`, port `9003`, idekey `VSCODE`.

## Log Rotation

The php-fpm image ships with `logrotate`. Copy the example policy and configure an Ofelia job to run it on a schedule.

```bash
cp php-fpm/conf/logrotate.d/app.example php-fpm/conf/logrotate.d/myapp
# Edit paths in php-fpm/conf/logrotate.d/myapp
```

The example `config.ini.example` includes a ready-made Ofelia `logrotate` job. After updating `config.ini`:

```bash
docker compose restart ofelia

# Manual run (verification)
docker exec -u www-data php-fpm \
  /usr/sbin/logrotate -f \
  -s /var/www/myapp/var/log/.logrotate-state \
  /usr/local/etc/logrotate.d/myapp
```

## Healthchecks

Core services include healthchecks in Compose:

- `nginx`
- `php-fpm` (and php74/php85 when enabled)
- `mysql`
- `redis`
- `mailpit`

This improves startup ordering and visibility via `docker compose ps`.

## Environment Variables

See `.env.sample` for the full reference. Key variables:

| Variable | Description |
|---|---|
| `WEB_ROOT` | Local projects root path |
| `PHP_VERSION` | Default PHP version (8.4.8) |
| `MYSQL_*` | Database credentials |
| `NGINX_VERSION` | Nginx image tag |
| `GRAFANA_ADMIN_PASSWORD` | Grafana admin password (observability) |

## Troubleshooting

- **Nginx 502/Bad Gateway**
  - Check `php-fpm` container is healthy: `make ps`
  - Check vhost uses correct upstream snippet (`84/85/74`).

- **DB connection failed**
  - Confirm `.env` credentials and `MYSQL_DATABASE` match app config.
  - Confirm `mysql` is healthy and port `3306` is free on host.

- **Mail not visible**
  - Confirm app uses PHP `mail()` or SMTP to `mailpit:1025`.
  - Confirm Mailpit vhost proxies to `mailpit:8025`.

## License

MIT License. See [LICENSE](LICENSE).
