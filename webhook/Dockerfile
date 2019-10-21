ARG PHP_73VERSION

FROM php:${PHP_73VERSION}-fpm
WORKDIR /usr/share/nginx/html

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN mkdir /var/www/.ssh && ln -s /run/secrets/host_ssh_key /var/www/.ssh/id_rsa
RUN touch /var/www/.ssh/known_hosts
RUN ssh-keyscan gitlab.a2z.com >> /var/www/.ssh/known_hosts
RUN usermod -u 1000 www-data
RUN chown -R  www-data:1000 /var/www/.ssh