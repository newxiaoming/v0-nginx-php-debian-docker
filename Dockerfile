# 使用官方PHP 7.3.33-fpm-bullseye镜像作为基础
FROM --platform=$BUILDPLATFORM php:7.3.33-fpm-bullseye

# 设置环境变量
ENV DEBIAN_FRONTEND=noninteractive
ENV NGINX_VERSION=1.28
ENV SUPERVISOR_VERSION=4.2.4
ENV COMPOSER_VERSION=2.6.3

RUN set -eux; \
    # 创建目录结构
    mkdir -p /opt/websrv/data/wwwroot \
    /opt/websrv/logs/nginx \
    /opt/websrv/logs/php \
    /opt/websrv/config/nginx/conf.d \
    /opt/websrv/config/php \
    /opt/websrv/run \
    /var/lib/php/sessions \
    /var/lib/php/wsdlcache; \
    \
    # 更新包管理器并安装依赖
    sed -i "s@deb.debian.org@mirrors.ustc.edu.cn@g" /etc/apt/sources.list; \
    sed -i "s@security.debian.org@mirrors.ustc.edu.cn@g" /etc/apt/sources.list; \
    apt-get update; \
    \
    apt-get install -y --no-install-recommends \
    # 运行时依赖
    nginx \
    supervisor \
    curl \
    ca-certificates \
    # PHP扩展运行时依赖
    libxml2 \
    libssl1.1 \
    libcurl4 \
    libjpeg62-turbo \
    libpng16-16 \
    libfreetype6 \
    libonig5 \
    libzip4 \
    libsqlite3-0 \
    libmariadb3 \
    libgmp10 \
    libicu67 \
    libbz2-1.0 \
    libreadline8 \
    libncurses6 \
    libxslt1.1 \
    libgeoip1 \
    libmagickwand-6.q16-6 \
    libsodium23 \
    libargon2-1 \
    libffi7 \
    libtidy5deb1 \
    libenchant-2-2; \
    \
    apt-get install -y --no-install-recommends \
    wget \
    gnupg2 \
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
    librecode-dev \
    libc-client-dev \
    libkrb5-dev \
    build-essential; \
    \
    docker-php-ext-configure gd --with-freetype-dir=/usr --with-jpeg-dir=/usr --with-png-dir=/usr; \
    docker-php-ext-configure intl; \
    \
    docker-php-ext-install -j$(nproc) \
    bcmath \
    calendar \
    ctype \
    curl \
    fileinfo \
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
    tokenizer \
    xml \
    dom \
    gd \
    intl \
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
    xsl; \
    \
    (docker-php-ext-install xmlreader || echo "XMLReader failed") && \
    (docker-php-ext-install xmlwriter || echo "XMLWriter failed") && \
    (docker-php-ext-install filter || echo "Filter failed"); \
    \
    pecl channel-update pecl.php.net || true; \
    (pecl install redis-5.3.7 && docker-php-ext-enable redis) || echo "Redis failed"; \
    (pecl install imagick-3.4.4 && docker-php-ext-enable imagick) || echo "ImageMagick failed"; \
    (pecl install geoip-1.1.1 && docker-php-ext-enable geoip) || echo "GeoIP failed"; \
    (pecl install swoole-4.8.13 && docker-php-ext-enable swoole) || echo "Swoole failed"; \
    \
    curl -sS https://getcomposer.org/installer | php -- --version=${COMPOSER_VERSION} --install-dir=/usr/local/bin --filename=composer; \
    \
    groupadd -f nginx && useradd -r -g nginx nginx || true; \
    \
    apt-get purge -y --auto-remove \
    wget \
    gnupg2 \
    git \
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
    librecode-dev \
    libc-client-dev \
    libkrb5-dev \
    build-essential; \
    \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*; \
    rm -rf /tmp/pear; \
    rm -rf /var/cache/apt/*; \
    \
    chown -R www-data:www-data /var/lib/php; \
    chmod -R 755 /var/lib/php; \
    chown -R nginx:nginx /opt/websrv/data/wwwroot; \
    chown -R nginx:nginx /opt/websrv/logs; \
    chmod -R 755 /opt/websrv/data/wwwroot

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

# 暴露端口
EXPOSE 80 443

# 设置工作目录
WORKDIR /opt/websrv/data/wwwroot

# 启动supervisor
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
