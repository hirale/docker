ARG PHP_71VERSION

FROM php:${PHP_71VERSION}-fpm
WORKDIR /var/www/html/

# bcmath pdo_mysql intl gd zip opcache xdebug redis memcached
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    cron \
    supervisor \
    git \
    openssh-client \
    libfreetype6-dev \
    libjpeg62-turbo-dev \
    libpng-dev \
    libxml2-dev \
    libmemcached-dev \
    unzip \
    zip \
    zlib1g-dev \
    libxslt-dev \
    libmcrypt-dev \
    libsodium-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-configure intl \
    && docker-php-ext-configure opcache --enable-opcache \
    && docker-php-ext-install -j$(nproc) gd intl bcmath pdo_mysql zip xsl json opcache soap mcrypt mysqli sodium \
    && pecl install redis memcached xdebug \
    && docker-php-ext-enable redis memcached xdebug \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

# Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Mailhog
COPY mhsendmail_linux_amd64 /usr/local/bin/mhsendmail
RUN chmod +x /usr/local/bin/mhsendmail

RUN usermod -u 1000 www-data

CMD ["/usr/bin/supervisord"]