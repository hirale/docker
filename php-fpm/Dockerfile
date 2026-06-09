ARG PHP_VERSION
ARG MAILPIT_BINARY_VERSION

FROM php:${PHP_VERSION}-fpm
WORKDIR /var/www

ARG NODE_MAJOR=22

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    openssh-client \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libwebp-dev \
    libxml2-dev \
    libzip-dev \
    zlib1g-dev \
    libxslt-dev \
    libsodium-dev \
    libicu-dev \
    logrotate \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

# opcache is compiled into PHP core on 8.4/8.5 (no separate module to install — installing
# it fails on 8.5); 7.4 ships it as a loadable .so, so enable it defensively. The subshell
# scopes `|| true` to the enable only, so a real ext-install failure still fails the build.
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) \
        gd intl exif bcmath pdo_mysql zip xsl mysqli soap sodium sockets ftp \
    && (docker-php-ext-enable opcache 2>/dev/null || true)

RUN pecl install redis xdebug \
    && docker-php-ext-enable redis exif \
    && rm -rf /tmp/pear

RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    && mkdir -p /var/www/.composer && chown -R 1000:1000 /var/www/.composer

RUN mkdir -p /var/run/php

ARG TARGETARCH
# Install Mailpit binary for sendmail support (`mailpit sendmail`) with checksum verification.
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) MAILPIT_ARCH="amd64"; MAILPIT_SHA256="92a51cdc54dc785a2cae2afd1822c3d30f477e6e00a3a6529344bdd8da878574" ;; \
        arm64) MAILPIT_ARCH="arm64"; MAILPIT_SHA256="d42cb7cd92a692c24da879e15f4146b94546985e5cc5336549724e96ad197d0d" ;; \
        *) echo "Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    MAILPIT_TARBALL="mailpit-linux-${MAILPIT_ARCH}.tar.gz"; \
    MAILPIT_URL="https://github.com/axllent/mailpit/releases/download/v${MAILPIT_BINARY_VERSION:-1.29.3}/${MAILPIT_TARBALL}"; \
    wget -qO /tmp/mailpit.tar.gz "${MAILPIT_URL}"; \
    echo "${MAILPIT_SHA256}  /tmp/mailpit.tar.gz" | sha256sum -c -; \
    tar -xzf /tmp/mailpit.tar.gz -C /tmp mailpit; \
    install -m 0755 /tmp/mailpit /usr/local/bin/mailpit; \
    rm -f /tmp/mailpit /tmp/mailpit.tar.gz

RUN usermod -u 1000 www-data && groupmod -g 1000 www-data
