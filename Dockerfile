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

# 先尝试使用系统自带的PHP，然后手动编译需要的扩展
RUN apt-get update && apt-get install -y \
    nginx \
    php-fpm \
    php-cli \
    php-common \
    php-bcmath \
    php-curl \
    php-dom \
    php-gd \
    php-gmp \
    php-mbstring \
    php-mysql \
    php-pdo \
    php-redis \
    php-sqlite3 \
    php-xml \
    php-zip \
    php-dev \
    php-pear \
    libgeoip-dev \
    libprotobuf-dev \
    protobuf-compiler \
    libmagickwand-dev \
    libswoole-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装imagick扩展
RUN pecl install imagick \
    && echo "extension=imagick.so" > /etc/php/8.2/mods-available/imagick.ini \
    && phpenmod imagick

# 安装geoip扩展
RUN pecl install geoip-1.1.1 \
    && echo "extension=geoip.so" > /etc/php/8.2/mods-available/geoip.ini \
    && phpenmod geoip

# 安装grpc扩展
RUN pecl install grpc \
    && echo "extension=grpc.so" > /etc/php/8.2/mods-available/grpc.ini \
    && phpenmod grpc

# 安装protobuf扩展
RUN pecl install protobuf \
    && echo "extension=protobuf.so" > /etc/php/8.2/mods-available/protobuf.ini \
    && phpenmod protobuf

# 安装swoole扩展
RUN pecl install swoole \
    && echo "extension=swoole.so" > /etc/php/8.2/mods-available/swoole.ini \
    && phpenmod swoole

RUN git clone https://github.com/nsqio/php-nsq.git /tmp/php-nsq \
    && cd /tmp/php-nsq \
    && phpize \
    && ./configure \
    && make && make install \
    && echo "extension=nsq.so" > /etc/php/8.2/mods-available/nsq.ini \
    && phpenmod nsq \
    && rm -rf /tmp/php-nsq

# 安装Composer
RUN curl -sS https://getcomposer.org/installer | php -- --version=${COMPOSER_VERSION} --install-dir=/usr/local/bin --filename=composer

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

RUN ln -sf /opt/websrv/config/php/php.ini /etc/php/8.2/fpm/php.ini \
    && ln -sf /opt/websrv/config/php/php.ini /etc/php/8.2/cli/php.ini

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
