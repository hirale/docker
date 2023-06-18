FROM varnish:6.0.11

WORKDIR /etc/varnish

COPY scripts/ /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/docker-varnish-entrypoint"]

EXPOSE 6081 6082
CMD []
