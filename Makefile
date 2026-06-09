# Docker LNMP — Makefile
# Run `make help` to see available commands.

COMPOSE_CORE     := -f compose.yml
COMPOSE_OBS      := -f compose.observability.yml
COMPOSE_PHP74    := -f compose.php74.yml
COMPOSE_PHP85    := -f compose.php85.yml

.DEFAULT_GOAL := help

.PHONY: help up down restart ps logs shell build \
        up-obs down-obs up-php74 up-php85 up-all \
        ssl-issue ssl-renew ssl-reload certs-dev \
        db-list db-shell db-export db-import db-ensure db-copy \
        site-list site-new site-enable site-disable \
        xdebug-on xdebug-off xdebug-status \
        clean-logs validate validate-obs

# ──────────────────────────────────────────────
# Help
# ──────────────────────────────────────────────
help: ## Show available commands
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ──────────────────────────────────────────────
# Core services
# ──────────────────────────────────────────────
up: ## Start core services
	docker compose $(COMPOSE_CORE) up -d

down: ## Stop core services
	docker compose $(COMPOSE_CORE) down

restart: ## Restart core services
	docker compose $(COMPOSE_CORE) restart

ps: ## Show service status
	docker compose $(COMPOSE_CORE) ps

logs: ## Tail logs (SVC=service name, optional)
	docker compose $(COMPOSE_CORE) logs -f $(SVC)

shell: ## Shell into php-fpm container
	docker exec -it php-fpm /bin/bash

build: ## Build php-fpm image
	docker compose $(COMPOSE_CORE) build php-fpm

validate: ## Validate compose file(s)
	docker compose $(COMPOSE_CORE) config

# ──────────────────────────────────────────────
# Observability
# ──────────────────────────────────────────────
up-obs: ## Start core + observability stack
	docker compose $(COMPOSE_CORE) $(COMPOSE_OBS) up -d

down-obs: ## Stop core + observability stack
	docker compose $(COMPOSE_CORE) $(COMPOSE_OBS) down

validate-obs: ## Validate compose files with observability
	docker compose $(COMPOSE_CORE) $(COMPOSE_OBS) config

# ──────────────────────────────────────────────
# Multi-PHP
# ──────────────────────────────────────────────
up-php74: ## Start core + PHP 7.4 addon
	docker compose $(COMPOSE_CORE) $(COMPOSE_PHP74) up -d

up-php85: ## Start core + PHP 8.5 addon
	docker compose $(COMPOSE_CORE) $(COMPOSE_PHP85) up -d

up-all: ## Start everything (core + observability + PHP 7.4 + 8.5)
	docker compose $(COMPOSE_CORE) $(COMPOSE_OBS) $(COMPOSE_PHP74) $(COMPOSE_PHP85) up -d

# ──────────────────────────────────────────────
# SSL (certbot)
# ──────────────────────────────────────────────
ssl-issue: ## Issue SSL cert via DNS-01 (DOMAIN= EMAIL= CRED=provider)
	@test -n "$(DOMAIN)" || (echo "Missing DOMAIN" && exit 1)
	@test -n "$(EMAIL)" || (echo "Missing EMAIL" && exit 1)
	@test -n "$(CRED)" || (echo "Missing CRED (credential file name without .ini)" && exit 1)
	docker compose $(COMPOSE_CORE) run --rm certbot certonly \
		-a dns-multi \
		--dns-multi-credentials /credentials/$(CRED).ini \
		--non-interactive --agree-tos \
		--email $(EMAIL) \
		-d $(DOMAIN) -d '*.$(DOMAIN)' \
		--deploy-hook "cp -L /etc/letsencrypt/live/$(DOMAIN)/fullchain.pem /output/certs/$(DOMAIN).crt && cp -L /etc/letsencrypt/live/$(DOMAIN)/privkey.pem /output/certs/$(DOMAIN).key"
	-docker exec nginx nginx -s reload 2>/dev/null

ssl-renew: ## Renew all SSL certs
	docker compose $(COMPOSE_CORE) run --rm certbot renew
	-docker exec nginx nginx -s reload 2>/dev/null

ssl-reload: ## Reload nginx SSL config
	docker exec nginx nginx -s reload

certs-dev: ## Generate a self-signed dev cert into nginx/certs (DOMAIN=localhost)
	@mkdir -p nginx/certs
	docker run --rm -v "$(CURDIR)/nginx/certs:/certs" alpine/openssl req -x509 -nodes \
		-newkey rsa:2048 -days 825 \
		-keyout /certs/$(or $(DOMAIN),localhost).key \
		-out /certs/$(or $(DOMAIN),localhost).crt \
		-subj "/CN=$(or $(DOMAIN),localhost)" \
		-addext "subjectAltName=DNS:$(or $(DOMAIN),localhost),DNS:*.$(or $(DOMAIN),localhost)"

# ──────────────────────────────────────────────
# Database
# ──────────────────────────────────────────────
db-list: ## List databases
	./scripts/db.sh list

db-shell: ## Open MySQL shell (DB=name optional)
	./scripts/db.sh shell $(DB)

db-export: ## Export database (DB=name [OUTPUT=path.sql.gz])
	./scripts/db.sh export $(DB) $(OUTPUT)

db-import: ## Import database (FILE=path DB=name [USER=] [PASS=])
	./scripts/db.sh import $(FILE) $(DB) $(USER) $(PASS)

db-ensure: ## Ensure database + user exist (DB=name [USER=] [PASS=])
	./scripts/db.sh ensure $(DB) $(USER) $(PASS)

db-copy: ## Copy database (SRC=name DST=name [OPTIONS...])
	./scripts/db.sh copy $(SRC) $(DST) $(OPTIONS)

# ──────────────────────────────────────────────
# Nginx site management
# ──────────────────────────────────────────────
site-list: ## List nginx sites
	./scripts/site.sh list

site-new: ## Create new site config (NAME=site.conf)
	@test -n "$(NAME)" || (echo "Missing NAME" && exit 1)
	./scripts/site.sh new $(NAME)

site-enable: ## Enable site (NAME=site.conf)
	@test -n "$(NAME)" || (echo "Missing NAME" && exit 1)
	./scripts/site.sh enable $(NAME)

site-disable: ## Disable site (NAME=site.conf)
	@test -n "$(NAME)" || (echo "Missing NAME" && exit 1)
	./scripts/site.sh disable $(NAME)

# ──────────────────────────────────────────────
# Xdebug
# ──────────────────────────────────────────────
xdebug-on: ## Enable xdebug and restart php-fpm
	./scripts/xdebug.sh on

xdebug-off: ## Disable xdebug and restart php-fpm
	./scripts/xdebug.sh off

xdebug-status: ## Show xdebug status
	./scripts/xdebug.sh status

# ──────────────────────────────────────────────
# Misc
# ──────────────────────────────────────────────
clean-logs: ## Truncate all container logs
	./scripts/logs.sh
