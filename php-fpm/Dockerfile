ARG PHP_VERSION

FROM php:${PHP_VERSION}-fpm
WORKDIR /var/www/html/

# bcmath pdo_mysql intl gd zip opcache redis memcached
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    git \
    openssh-client \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libxml2-dev \
    libmemcached-dev \
    unzip \
    zip \
    libzip-dev \
    zlib1g-dev \
    libxslt-dev \
    libsodium-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install -j$(nproc) gd intl bcmath pdo_mysql zip xsl opcache mysqli soap sodium sockets \
    && pecl install redis memcached xdebug \
    && docker-php-ext-enable redis memcached \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

RUN mkdir -p /var/run/php
# Mailhog
COPY mhsendmail_linux_amd64 /usr/local/bin/mhsendmail
RUN chmod +x /usr/local/bin/mhsendmail

RUN usermod -u 1000 www-data && groupmod -g 1000 www-data