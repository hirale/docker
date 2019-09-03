FROM debian:stretch-slim

ARG MAKE_J
ARG NGINX_VERSION
ARG PAGESPEED_VERSION
ARG LIBPNG_VERSION

ENV MAKE_J=${MAKE_J} \
        NGINX_VERSION=${NGINX_VERSION} \
        LIBPNG_VERSION=${LIBPNG_VERSION} \
        PAGESPEED_VERSION=${PAGESPEED_VERSION}

RUN apt-get update -y && \
        apt-get upgrade -y

RUN apt-get install -y \
        apt-utils \
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

# Build libpng
RUN cd /tmp && \
        curl -L http://prdownloads.sourceforge.net/libpng/libpng-${LIBPNG_VERSION}.tar.gz | tar -zx && \
        cd /tmp/libpng-${LIBPNG_VERSION} && \
        ./configure --build=$CBUILD --host=$CHOST --prefix=/usr --enable-shared --with-libpng-compat && \
        make -j${MAKE_J} install V=0

RUN cd /tmp && \
        curl -O -L https://github.com/pagespeed/ngx_pagespeed/archive/v${PAGESPEED_VERSION}-stable.zip && \
        unzip v${PAGESPEED_VERSION}-stable.zip

RUN cd /tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-stable/ && \
        psol_url=https://dl.google.com/dl/page-speed/psol/${PAGESPEED_VERSION}.tar.gz && \
        [ -e scripts/format_binary_url.sh ] && psol_url=$(scripts/format_binary_url.sh PSOL_BINARY_URL) && \
        echo "URL: ${psol_url}" && \
        curl -L ${psol_url} | tar -xz

# Build in additional Nginx modules
RUN cd /tmp && \
        git clone git://github.com/vozlt/nginx-module-vts.git && \
        git clone https://github.com/openresty/headers-more-nginx-module.git && \
        git clone git://github.com/yaoweibin/ngx_http_substitutions_filter_module.git && \
        git clone --recursive https://github.com/eustas/ngx_brotli.git

# Build Nginx with support for PageSpeed
RUN cd /tmp && \
        curl -L http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz | tar -zx && \
        cd /tmp/nginx-${NGINX_VERSION} && \
        LD_LIBRARY_PATH=/tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}/usr/lib:/usr/lib ./configure \
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
        --without-http_autoindex_module \
        --without-http_browser_module \
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
        --add-module=/tmp/ngx_brotli \
        --add-module=/tmp/incubator-pagespeed-ngx-${PAGESPEED_VERSION}-stable && \
        make install --silent

# Clean-up
RUN apt-get remove -y git
RUN rm -rf /var/lib/apt/lists/* && rm -rf /tmp/* && \
        # Forward request and error logs to docker log collector
        ln -sf /dev/stdout /var/log/nginx/access.log && \
        ln -sf /dev/stderr /var/log/nginx/error.log && \
        # Make PageSpeed cache writable
        mkdir -p /var/cache/nginx/pagespeed && \
        chmod -R o+wr /var/cache/nginx/pagespeed && \
        mkdir -p /var/log/pagespeed && \
        chmod -R o+wr /var/log/pagespeed 

EXPOSE 80
WORKDIR /var/www/html
RUN usermod -u 1000 www-data

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]