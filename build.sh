#!/bin/bash

# 构建ARM64架构的Docker镜像
docker build --platform linux/arm64 -t nginx-php-supervisor:latest .

# 如果需要推送到仓库，取消注释下面的行
# docker tag nginx-php-supervisor:latest your-registry/nginx-php-supervisor:latest
# docker push your-registry/nginx-php-supervisor:latest
