# 使用官方PHP 7.3-fpm镜像作为基础
FROM php:7.3.33-fpm-bullseye

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
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

# 更新包管理器并安装基础依赖
RUN \
    sed -i "s@deb.debian.org@mirrors.ustc.edu.cn@g" /etc/apt/sources.list && \
    sed -i "s@security.debian.org@mirrors.ustc.edu.cn@g" /etc/apt/sources.list && \
    apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg2 \
    lsb-release \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    supervisor \
    nginx \
    git \
    # PHP扩展编译依赖
    libxml2-dev \
    libssl-dev \
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
    libncurses5-dev \
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
    libc-client-dev \
    libkrb5-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# 安装PHP核心扩展 - 第一批（基础扩展）
RUN docker-php-ext-install -j$(nproc) \
        bcmath \
        calendar \
        ctype \
        curl \
        dom \
        exif \
        fileinfo \
        filter \
        ftp \
        hash \
        iconv \
        json \
        mbstring \
        pdo \
        pdo_mysql \
        pdo_sqlite \
        phar \
        posix \
        session \
        simplexml \
        sqlite3 \
        tokenizer \
        xml \
        xmlreader \
        xmlwriter

# 安装PHP核心扩展 - 第二批（需要配置的扩展）
RUN docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr \
    && docker-php-ext-install -j$(nproc) gd

RUN docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) intl

# 安装PHP核心扩展 - 第三批（系统相关扩展）
RUN docker-php-ext-install -j$(nproc) \
        mysqli \
        pcntl \
        shmop \
        soap \
        sockets \
        sysvmsg \
        sysvsem \
        sysvshm \
        bz2 \
        zip \
        gmp \
        xsl

# 安装ImageMagick扩展
RUN pecl install imagick-3.4.4 || true \
    && docker-php-ext-enable imagick || true

# 安装Redis扩展
RUN pecl install redis-5.3.7 || true \
    && docker-php-ext-enable redis || true

# 安装GeoIP扩展
RUN pecl install geoip-1.1.1 || true \
    && docker-php-ext-enable geoip || true

# 安装Swoole扩展
RUN pecl install swoole-4.8.13 || true \
    && docker-php-ext-enable swoole || true

# 安装gRPC和Protobuf扩展（使用更保守的方法）
RUN pecl install grpc-1.42.0 || true \
    && docker-php-ext-enable grpc || true

RUN pecl install protobuf-3.21.12 || true \
    && docker-php-ext-enable protobuf || true

# 安装Composer
RUN curl -sS https://getcomposer.org/installer | php -- --version=${COMPOSER_VERSION} --install-dir=/usr/local/bin --filename=composer

# 设置权限
RUN chown -R www-data:www-data /var/lib/php \
    && chmod -R 755 /var/lib/php

# 配置Nginx
COPY nginx.conf /opt/websrv/config/nginx/nginx.conf
COPY default.conf /opt/websrv/config/nginx/conf.d/default.conf

# 创建PHP配置目录
RUN mkdir -p /opt/websrv/config/php/pool.d

# 配置PHP-FPM
COPY php-fpm.conf /opt/websrv/config/php/php-fpm.conf
COPY www.conf /opt/websrv/config/php/pool.d/www.conf
COPY php.ini /opt/websrv/config/php/php.ini

# 配置Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 创建nginx用户和组（如果不存在）
RUN groupadd -f nginx && useradd -r -g nginx nginx || true

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
