ARG APACHE_VERSION
FROM httpd:${APACHE_VERSION}

RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

STOPSIGNAL SIGWINCH

CMD ["httpd-foreground"]