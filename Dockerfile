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
    libenchant-2-2 \
    libprotobuf23 \
    zlib1g; \
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
    zlib1g-dev \
    pkg-config \
    cmake \
    autoconf \
    automake \
    libtool \
    make \
    g++ \
    unzip \
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
    # 安装gRPC扩展 - 多种备选方案确保安装成功
    echo "开始安装gRPC扩展..."; \
    export MAKEFLAGS="-j$(nproc)"; \
    \
    # 方案1: 尝试安装gRPC 1.25.0
    (pecl install grpc-1.25.0 && docker-php-ext-enable grpc && echo "gRPC 1.25.0 安装成功") || \
    \
    # 方案2: 如果失败，尝试gRPC 1.20.0
    (echo "尝试gRPC 1.20.0..." && pecl install grpc-1.20.0 && docker-php-ext-enable grpc && echo "gRPC 1.20.0 安装成功") || \
    \
    # 方案3: 如果还是失败，尝试手动编译最新稳定版
    (echo "尝试手动编译gRPC..." && \
    cd /tmp && \
    curl -L https://pecl.php.net/get/grpc-1.25.0.tgz -o grpc.tgz && \
    tar -xzf grpc.tgz && \
    cd grpc-* && \
    phpize && \
    ./configure --enable-grpc && \
    make -j$(nproc) && \
    make install && \
    docker-php-ext-enable grpc && \
    cd / && rm -rf /tmp/grpc* && \
    echo "手动编译gRPC成功") || \
    \
    echo "所有gRPC安装方案都失败了"; \
    \
    # 验证gRPC扩展安装
    if php -m | grep -q grpc; then \
    echo "✅ gRPC扩展安装成功"; \
    echo "gRPC版本: $(php --ri grpc | grep 'grpc support' || echo '无法获取版本信息')"; \
    ls -la $(php-config --extension-dir)/grpc.so; \
    else \
    echo "❌ gRPC扩展安装失败"; \
    echo "扩展目录内容:"; \
    ls -la $(php-config --extension-dir)/ | grep '\.so$' || echo "没有找到扩展文件"; \
    fi; \
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
    zlib1g-dev \
    cmake \
    autoconf \
    automake \
    libtool \
    make \
    g++ \
    unzip \
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
