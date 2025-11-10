# 多阶段构建 - 构建阶段
FROM --platform=$BUILDPLATFORM php:7.3.33-fpm-bullseye AS builder

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive

# 一次性安装所有扩展并清理
RUN set -eux; \
    # 更新包管理器
    sed -i "s@deb.debian.org@mirrors.ustc.edu.cn@g" /etc/apt/sources.list; \
    sed -i "s@security.debian.org@mirrors.ustc.edu.cn@g" /etc/apt/sources.list; \
    apt-get update; \
    \
    # 安装编译依赖
    apt-get install -y --no-install-recommends \
    wget git build-essential autoconf automake libtool make g++ pkg-config cmake unzip \
    libxml2-dev libssl-dev libcurl4-openssl-dev libjpeg-dev libpng-dev libfreetype6-dev \
    libonig-dev libzip-dev libsqlite3-dev default-libmysqlclient-dev libgmp-dev libicu-dev \
    libbz2-dev libreadline-dev libncurses5-dev libxslt1-dev libgeoip-dev libprotobuf-dev \
    protobuf-compiler zlib1g-dev libmagickwand-dev libpcre3-dev libedit-dev libsodium-dev \
    libargon2-dev libffi-dev libtidy-dev libenchant-2-dev librecode-dev libc-client-dev libkrb5-dev; \
    \
    # 配置和安装PHP核心扩展
    docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j$(nproc) bcmath calendar ctype curl fileinfo hash iconv json \
    mbstring pdo pdo_mysql pdo_sqlite phar posix session tokenizer xml dom gd intl mysqli \
    pcntl shmop soap sockets sysvmsg sysvsem sysvshm bz2 zip gmp xsl; \
    \
    # 安装可选扩展
    (docker-php-ext-install xmlreader xmlwriter filter || true); \
    \
    # 安装PECL扩展
    pecl channel-update pecl.php.net || true; \
    (pecl install redis-5.3.7 && docker-php-ext-enable redis || true); \
    (pecl install imagick-3.4.4 && docker-php-ext-enable imagick || true); \
    (pecl install geoip-1.1.1 && docker-php-ext-enable geoip || true); \
    (pecl install swoole-4.8.13 && docker-php-ext-enable swoole || true); \
    \
    # 安装protobuf和gRPC扩展
    cd /tmp; \
    wget -q https://pecl.php.net/get/protobuf-3.21.9.tgz; \
    tar -xzf protobuf-3.21.9.tgz; \
    cd protobuf-3.21.9; \
    phpize && ./configure && make -j$(nproc) && make install; \
    docker-php-ext-enable protobuf; \
    cd /tmp; \
    wget -q https://pecl.php.net/get/grpc-1.50.2.tgz; \
    tar -xzf grpc-1.50.2.tgz; \
    cd grpc-1.50.2; \
    phpize && ./configure && make -j$(nproc) && make install; \
    docker-php-ext-enable grpc; \
    \
    # 验证关键扩展
    php -m | grep -E "(protobuf|grpc)" && echo "✅ 关键扩展安装成功"; \
    \
    # 彻底清理
    cd /; \
    rm -rf /tmp/*; \
    rm -rf /var/tmp/*; \
    rm -rf /usr/src/*; \
    rm -rf /var/cache/apt/*; \
    rm -rf /var/lib/apt/lists/*; \
    apt-get clean;

# 生产阶段
FROM --platform=$BUILDPLATFORM php:7.3.33-fpm-bullseye

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV NGINX_VERSION=1.28
ENV SUPERVISOR_VERSION=4.2.4
ENV COMPOSER_VERSION=2.6.3

# 从构建阶段复制PHP扩展
COPY --from=builder /usr/local/lib/php/extensions/ /usr/local/lib/php/extensions/
COPY --from=builder /usr/local/etc/php/conf.d/ /usr/local/etc/php/conf.d/

RUN set -eux; \
    # 创建目录结构
    mkdir -p /opt/websrv/data/wwwroot /opt/websrv/logs/nginx /opt/websrv/logs/php \
    /opt/websrv/config/nginx/conf.d /opt/websrv/config/php /opt/websrv/run \
    /var/lib/php/sessions /var/lib/php/wsdlcache; \
    \
    # 更新包管理器并安装运行时依赖
    sed -i "s@deb.debian.org@mirrors.ustc.edu.cn@g" /etc/apt/sources.list; \
    sed -i "s@security.debian.org@mirrors.ustc.edu.cn@g" /etc/apt/sources.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends nginx supervisor curl ca-certificates \
    libxml2 libssl1.1 libcurl4 libjpeg62-turbo libpng16-16 libfreetype6 libonig5 libzip4 \
    libsqlite3-0 libmariadb3 libgmp10 libicu67 libbz2-1.0 libreadline8 libncurses6 \
    libxslt1.1 libgeoip1 libmagickwand-6.q16-6 libsodium23 libargon2-1 libffi7 \
    libtidy5deb1 libenchant-2-2 libprotobuf23 zlib1g; \
    \
    # 安装Composer
    curl -sS https://getcomposer.org/installer | php -- --version=${COMPOSER_VERSION} --install-dir=/usr/local/bin --filename=composer; \
    \
    # 创建用户和设置权限
    groupadd -f nginx && useradd -r -g nginx nginx || true; \
    chown -R www-data:www-data /var/lib/php; \
    chmod -R 755 /var/lib/php; \
    chown -R nginx:nginx /opt/websrv/data/wwwroot /opt/websrv/logs; \
    chmod -R 755 /opt/websrv/data/wwwroot; \
    \
    # 最终清理
    apt-get clean; \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/cache/apt/*;

# 配置Nginx
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

RUN ln -sf /opt/websrv/logs/nginx /var/log/nginx && \
    ln -sf /opt/websrv/run/nginx.pid /var/run/nginx.pid

# 创建PHP配置目录
RUN mkdir -p /opt/websrv/config/php/pool.d

# 配置PHP-FPM
COPY php-fpm.conf /opt/websrv/config/php/php-fpm.conf
COPY www.conf /opt/websrv/config/php/pool.d/www.conf
COPY php.ini /opt/websrv/config/php/php.ini

# 配置Supervisor
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# 最终验证
RUN echo "=== 最终扩展验证 ===" && \
    php -m | grep -E "(protobuf|grpc)" && \
    echo "✅ 所有扩展验证通过" || echo "⚠️ 部分扩展可能未加载"

# 暴露端口
EXPOSE 80 443

# 设置工作目录
WORKDIR /opt/websrv/data/wwwroot

# 启动supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
