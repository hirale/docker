FROM debian:stretch-slim


ARG NGINX_VERSION

ENV NGINX_VERSION=${NGINX_VERSION} 

RUN apt-get update -y && \
        apt-get upgrade -y

RUN apt-get install -y \
        apt-utils \
        wget \
        git nano \
        g++ \
        gcc \
        curl \
        make \
        unzip \
        bzip2 \
        gperf \
        python \
        openssl \
        libuuid1 \
        apt-utils \
        pkg-config \
        icu-devtools \
        build-essential \
        ca-certificates \
        uuid-dev \
        zlib1g-dev \
        libicu-dev \
        libssl-dev \
        apache2-dev \
        libpcre3 \
        libpcre3-dev \
        libpng-dev \
        libaprutil1-dev \
        linux-headers-amd64 \
        libjpeg62-turbo-dev \
        libcurl4-openssl-dev

# Build in additional Nginx modules
RUN cd /tmp && \
        git clone https://github.com/vozlt/nginx-module-vts.git && \
        git clone https://github.com/openresty/headers-more-nginx-module.git && \
        git clone https://github.com/yaoweibin/ngx_http_substitutions_filter_module.git && \
        git clone --recursive https://github.com/eustas/ngx_brotli.git

# Build Nginx with support for PageSpeed
RUN cd /tmp && \
        curl -L https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zx && \
        cd /tmp/nginx-${NGINX_VERSION} && \
        ./configure \
        --sbin-path=/usr/sbin \
        --modules-path=/usr/lib/nginx \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --with-file-aio \
        --with-http_v2_module \
        --with-http_realip_module \
        --with-http_sub_module \
        --with-http_gunzip_module \
        --with-http_secure_link_module \
        --with-http_stub_status_module \
        --with-threads \
        --with-stream \
        --with-stream_ssl_module \
        --without-http_memcached_module \
        --without-http_userid_module \
        --without-mail_pop3_module \
        --without-mail_imap_module \
        --without-mail_smtp_module \
        --without-http_split_clients_module \
        --without-http_uwsgi_module \
        --without-http_scgi_module \
        --without-http_upstream_ip_hash_module \
        --prefix=/var/www \
        --conf-path=/etc/nginx/nginx.conf \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --pid-path=/var/run/nginx.pid \
        --add-module=/tmp/nginx-module-vts \
        --add-module=/tmp/headers-more-nginx-module \
        --add-module=/tmp/ngx_http_substitutions_filter_module \
        --add-module=/tmp/ngx_brotli && \
        make install --silent

# Clean-up
RUN apt-get remove -y git
RUN rm -rf /var/lib/apt/lists/* && rm -rf /tmp/* && \
        # Forward request and error logs to docker log collector
        ln -sf /dev/stdout /var/log/nginx/access.log && \
        ln -sf /dev/stderr /var/log/nginx/error.log

EXPOSE 80
WORKDIR /var/www/html
RUN usermod -u 1000 www-data && groupmod -g 1000 www-data

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"] 