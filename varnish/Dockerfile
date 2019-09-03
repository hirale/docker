FROM alpine:3.7

ARG VARNISH_VERSION="${VARNISH_VERSION:-5.2.1-r0}"

ENV VARNISH_PORT="80" \
    VARNISH_RAM_STORAGE="128M" \
    VARNISH_VCL_PATH="/etc/varnish/default.vcl" \
    VARNISH_VCL_CONTENT="" \
    VARNISH_VCL_DEFAULT_BACKEND="nginx:80" \
    VARNISHD_ADDITIONAL_OPTS="" \
    VARNISHLOG="true" \
    VARNISHLOG_OPTS="" \
    VARNISH_VERSION="${VARNISH_VERSION}"
ENV VARNISHD_DEFAULT_OPTS="-a :${VARNISH_PORT} -s default=malloc,${VARNISH_RAM_STORAGE}"

RUN set -x && \
    apk add --no-cache --upgrade varnish=${VARNISH_VERSION} && \
    rm -rf /tmp/* /var/cache/apk/*

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint

RUN chmod +x /usr/local/bin/docker-entrypoint && \
    set -x ; \
    addgroup -g 82 -S www-data ; \
    adduser -u 82 -D -S -G www-data www-data && exit 0 ; exit 1

CMD ["/usr/local/bin/docker-entrypoint"]