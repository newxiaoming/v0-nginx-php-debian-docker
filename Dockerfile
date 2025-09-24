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
    /opt/websrv/run

# 更新系统并安装基础依赖
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg2 \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    build-essential \
    autoconf \
    libtool \
    pkg-config \
    cmake \
    git \
    unzip \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /usr/share/keyrings/nginx-archive-keyring.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian bookworm nginx" > /etc/apt/sources.list.d/nginx.list

RUN wget -qO /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg \
    && echo "deb https://packages.sury.org/php/ bookworm main" > /etc/apt/sources.list.d/php.list

RUN apt-get update && apt-get install -y \
    nginx \
    php7.3-fpm \
    php7.3-cli \
    php7.3-common \
    php7.3-bcmath \
    php7.3-curl \
    php7.3-dom \
    php7.3-exif \
    php7.3-fileinfo \
    php7.3-ftp \
    php7.3-gd \
    php7.3-gmp \
    php7.3-iconv \
    php7.3-imagick \
    php7.3-json \
    php7.3-mbstring \
    php7.3-mysql \
    php7.3-mysqli \
    php7.3-pdo \
    php7.3-pdo-mysql \
    php7.3-pdo-sqlite \
    php7.3-redis \
    php7.3-sqlite3 \
    php7.3-xml \
    php7.3-xmlreader \
    php7.3-xmlwriter \
    php7.3-zip \
    php7.3-dev \
    php-pear \
    libgeoip-dev \
    libprotobuf-dev \
    protobuf-compiler \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装额外的PHP扩展
RUN pecl install geoip-1.1.1 \
    && pecl install grpc \
    && pecl install protobuf \
    && pecl install swoole-4.8.13

# 编译安装nsq扩展
RUN git clone https://github.com/nsqio/php-nsq.git /tmp/php-nsq \
    && cd /tmp/php-nsq \
    && phpize7.3 \
    && ./configure --with-php-config=/usr/bin/php-config7.3 \
    && make && make install \
    && rm -rf /tmp/php-nsq

# 启用PHP扩展
RUN echo "extension=geoip.so" > /etc/php/7.3/mods-available/geoip.ini \
    && echo "extension=grpc.so" > /etc/php/7.3/mods-available/grpc.ini \
    && echo "extension=protobuf.so" > /etc/php/7.3/mods-available/protobuf.ini \
    && echo "extension=swoole.so" > /etc/php/7.3/mods-available/swoole.ini \
    && echo "extension=nsq.so" > /etc/php/7.3/mods-available/nsq.ini \
    && phpenmod -v 7.3 geoip grpc protobuf swoole nsq

# 安装Composer
RUN curl -sS https://getcomposer.org/installer | php -- --version=${COMPOSER_VERSION} --install-dir=/usr/local/bin --filename=composer

# 配置Nginx
COPY nginx.conf /opt/websrv/config/nginx/nginx.conf
COPY default.conf /opt/websrv/config/nginx/conf.d/default.conf

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
