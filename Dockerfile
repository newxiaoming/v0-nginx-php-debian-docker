FROM debian:12

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV PHP_VERSION=7.3.33
ENV NGINX_VERSION=1.28
ENV SUPERVISOR_VERSION=4.2.4
ENV COMPOSER_VERSION=2.6.3

# 创建目录结构
RUN mkdir -p /opt/websrv/data/wwwroot \
    /opt/websrv/logs/nginx \
    /opt/websrv/logs/php \
    /opt/websrv/config/nginx \
    /opt/websrv/config/php \
    /opt/websrv/run \
    /var/lib/php/sessions \
    /var/lib/php/wsdlcache

RUN \
    sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list.d/debian.sources && \
    apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg2 \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    build-essential \
    autoconf \
    automake \
    libtool \
    pkg-config \
    cmake \
    git \
    unzip \
    supervisor \
    libxml2-dev \
    libssl-dev \
    libssl3 \
    openssl \
    libcurl4-openssl-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    libonig-dev \
    libzip-dev \
    libsqlite3-dev \
    default-libmysqlclient-dev \
    libgmp-dev \
    libicu-dev \
    libbz2-dev \
    libreadline-dev \
    libxslt1-dev \
    libgeoip-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libmagickwand-dev \
    libpcre3-dev \
    libedit-dev \
    libsodium-dev \
    libargon2-dev \
    libffi-dev \
    libtidy-dev \
    libenchant-2-dev \
    libsnmp-dev \
    libpspell-dev \
    librecode-dev \
    libmcrypt-dev \
    re2c \
    bison \
    flex \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN cd /tmp \
    && wget https://mirrors.mydev.work/php/${PHP_VERSION}/php-${PHP_VERSION}.tar.gz \
    && tar -xzf php-${PHP_VERSION}.tar.gz \
    && cd php-${PHP_VERSION} \
    && export PKG_CONFIG_PATH="/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig" \
    && ./configure \
        --prefix=/usr/local/php \
        --with-config-file-path=/opt/websrv/config/php \
        --with-config-file-scan-dir=/opt/websrv/config/php/conf.d \
        --enable-fpm \
        --with-fpm-user=www-data \
        --with-fpm-group=www-data \
        --enable-bcmath \
        --enable-calendar \
        --enable-exif \
        --enable-ftp \
        --enable-gd \
        --with-freetype-dir=/usr \
        --with-jpeg-dir=/usr \
        --with-png-dir=/usr \
        --enable-intl \
        --enable-mbstring \
        --enable-mysqlnd \
        --with-mysqli=mysqlnd \
        --with-pdo-mysql=mysqlnd \
        --with-pdo-sqlite \
        --enable-pcntl \
        --enable-shmop \
        --enable-soap \
        --enable-sockets \
        --enable-sysvmsg \
        --enable-sysvsem \
        --enable-sysvshm \
        --with-curl \
        --with-openssl=/usr \
        --with-openssl-dir=/usr \
        --with-readline \
        --with-zlib \
        --with-zlib-dir=/usr \
        --with-bz2 \
        --enable-zip \
        --with-libzip \
        --with-gmp \
        --with-xsl \
        --enable-fileinfo \
        --enable-ctype \
        --enable-dom \
        --enable-filter \
        --enable-hash \
        --enable-iconv \
        --enable-json \
        --enable-libxml \
        --enable-phar \
        --enable-posix \
        --enable-session \
        --enable-simplexml \
        --enable-sqlite3 \
        --enable-tokenizer \
        --enable-xml \
        --enable-xmlreader \
        --enable-xmlwriter \
        --with-pic \
        --disable-rpath \
    && make -j$(nproc) \
    && make install \
    && rm -rf /tmp/php-${PHP_VERSION}*

RUN ln -sf /usr/local/php/bin/php /usr/local/bin/php \
    && ln -sf /usr/local/php/bin/php-config /usr/local/bin/php-config \
    && ln -sf /usr/local/php/bin/phpize /usr/local/bin/phpize \
    && ln -sf /usr/local/php/sbin/php-fpm /usr/local/bin/php-fpm \
    && mkdir -p /opt/websrv/config/php/conf.d

# 安装Nginx
RUN curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian bookworm nginx" > /etc/apt/sources.list.d/nginx.list \
    && apt-get update \
    && apt-get install -y nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN cd /tmp \
    && wget https://pecl.php.net/get/imagick-3.4.4.tgz \
    && tar -xzf imagick-3.4.4.tgz \
    && cd imagick-3.4.4 \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config \
    && make && make install \
    && echo "extension=imagick.so" > /opt/websrv/config/php/conf.d/imagick.ini \
    && rm -rf /tmp/imagick-*

RUN cd /tmp \
    && wget https://pecl.php.net/get/redis-5.3.7.tgz \
    && tar -xzf redis-5.3.7.tgz \
    && cd redis-5.3.7 \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config \
    && make && make install \
    && echo "extension=redis.so" > /opt/websrv/config/php/conf.d/redis.ini \
    && rm -rf /tmp/redis-*

RUN cd /tmp \
    && wget https://pecl.php.net/get/geoip-1.1.1.tgz \
    && tar -xzf geoip-1.1.1.tgz \
    && cd geoip-1.1.1 \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config \
    && make && make install \
    && echo "extension=geoip.so" > /opt/websrv/config/php/conf.d/geoip.ini \
    && rm -rf /tmp/geoip-*

RUN cd /tmp \
    && wget https://pecl.php.net/get/grpc-1.42.0.tgz \
    && tar -xzf grpc-1.42.0.tgz \
    && cd grpc-1.42.0 \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config \
    && make && make install \
    && echo "extension=grpc.so" > /opt/websrv/config/php/conf.d/grpc.ini \
    && rm -rf /tmp/grpc-*

RUN cd /tmp \
    && wget https://pecl.php.net/get/protobuf-3.21.12.tgz \
    && tar -xzf protobuf-3.21.12.tgz \
    && cd protobuf-3.21.12 \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config \
    && make && make install \
    && echo "extension=protobuf.so" > /opt/websrv/config/php/conf.d/protobuf.ini \
    && rm -rf /tmp/protobuf-*

RUN cd /tmp \
    && wget https://pecl.php.net/get/swoole-4.8.12.tgz \
    && tar -xzf swoole-4.8.12.tgz \
    && cd swoole-4.8.12 \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config --enable-openssl --enable-http2 \
    && make && make install \
    && echo "extension=swoole.so" > /opt/websrv/config/php/conf.d/swoole.ini \
    && rm -rf /tmp/swoole-*

RUN cd /tmp \
    && git clone https://github.com/nsqio/php-nsq.git \
    && cd php-nsq \
    && /usr/local/php/bin/phpize \
    && ./configure --with-php-config=/usr/local/php/bin/php-config \
    && make && make install \
    && echo "extension=nsq.so" > /opt/websrv/config/php/conf.d/nsq.ini \
    && rm -rf /tmp/php-nsq

# 安装Composer
RUN curl -sS https://getcomposer.org/installer | /usr/local/php/bin/php -- --version=${COMPOSER_VERSION} --install-dir=/usr/local/bin --filename=composer

# 设置权限
RUN chown -R www-data:www-data /var/lib/php \
    && chmod -R 755 /var/lib/php

# 配置Nginx
COPY nginx.conf /opt/websrv/config/nginx/nginx.conf
COPY default.conf /opt/websrv/config/nginx/conf.d/default.conf

RUN mkdir -p /opt/websrv/config/php/pool.d

# 配置PHP-FPM
COPY php-fpm.conf /opt/websrv/config/php/php-fpm.conf
COPY www.conf /opt/websrv/config/php/pool.d/www.conf
COPY php.ini /opt/websrv/config/php/php.ini

# 配置Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 创建nginx用户和组
RUN groupadd -r nginx && useradd -r -g nginx nginx

# 设置权限
RUN chown -R nginx:nginx /opt/websrv/data/wwwroot \
    && chown -R nginx:nginx /opt/websrv/logs \
    && chmod -R 755 /opt/websrv/data/wwwroot

# 创建默认的index.php
RUN echo "<?php phpinfo(); ?>" > /opt/websrv/data/wwwroot/index.php

# 暴露端口
EXPOSE 80 443

# 设置工作目录
WORKDIR /opt/websrv/data/wwwroot

# 启动supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
