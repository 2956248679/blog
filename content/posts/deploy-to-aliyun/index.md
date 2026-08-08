---
title: "阿里云 ECS + Docker + Nginx 部署全记录"
date: 2026-08-08T18:00:00+08:00
draft: false
tags: ["运维", "Docker", "Nginx", "阿里云", "HTTPS"]
summary: "记录从零在阿里云 ECS 上用 Docker Compose 部署博客，配置 HTTPS 证书和 CI/CD 自动部署的全过程。"
---

## 服务器环境

| 配置 | 详情 |
|------|------|
| 云平台 | 阿里云 ECS |
| 规格 | ecs.e-c1m1.large / 2 vCPU / 2 GiB |
| 系统 | Ubuntu 24.04 |
| 系统盘 | ESSD Entry 40 GiB |
| 带宽 | 10 Mbps 峰值（按流量计费） |
| 公网 IP | 47.119.121.45 |

## 安全组配置

阿里云安全组开放端口：

| 端口 | 协议 | 用途 |
|------|------|------|
| 22 | TCP | SSH 远程管理 |
| 80 | TCP | HTTP 访问（自动跳转 HTTPS） |
| 443 | TCP | HTTPS 加密访问 |

## 安装 Docker

使用官方脚本一键安装：

```bash
curl -fsSL https://get.docker.com | bash
systemctl enable docker --now
docker --version   # Docker version 29.7.2
docker compose version  # Docker Compose version v5.4.0
```

## 项目文件结构

```
/opt/blog/
├── site/                   # Hugo 构建的静态文件
├── nginx/
│   └── blog.conf           # Nginx 配置
└── docker-compose.yml      # 生产环境编排
```

## Nginx 配置

```nginx
# HTTP → HTTPS 强制跳转
server {
    listen 80;
    server_name www.lihuanyu.icu lihuanyu.icu;
    return 301 https://$host$request_uri;
}

# HTTPS 主服务
server {
    listen 443 ssl;
    http2 on;
    server_name www.lihuanyu.icu lihuanyu.icu;

    ssl_certificate /etc/ssl/certs/fullchain.pem;
    ssl_certificate_key /etc/ssl/private/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;

    root /usr/share/nginx/html;
    index index.html;

    # Gzip 压缩
    gzip on;
    gzip_types text/css application/javascript text/xml application/rss+xml;
    gzip_min_length 256;

    # 静态资源缓存 30 天
    location ~* \.(js|css|png|jpg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # 安全头
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header Strict-Transport-Security "max-age=31536000" always;
}
```

## docker-compose.yml

```yaml
services:
  blog:
    image: nginx:1.27-alpine
    container_name: blog
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /opt/blog/site:/usr/share/nginx/html:ro
      - /opt/blog/nginx/blog.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt/live/www.lihuanyu.icu/fullchain.pem:/etc/ssl/certs/fullchain.pem:ro
      - /etc/letsencrypt/live/www.lihuanyu.icu/privkey.pem:/etc/ssl/private/privkey.pem:ro
    restart: unless-stopped
```

关键设计点：
- `:ro`（只读）挂载 → 容器内无法修改文件，更安全
- `restart: unless-stopped` → 服务挂了自动重启
- 证书文件直接挂载 → 续期后重启容器即时生效

## HTTPS 证书

### 安装 Certbot

```bash
apt update && apt install -y certbot
```

### 首次签发

先停掉占用 80 端口的服务，用 standalone 模式验证：

```bash
docker compose stop
certbot certonly --standalone \
  -d www.lihuanyu.icu -d lihuanyu.icu \
  --email 2956248679@qq.com \
  --agree-tos --non-interactive
```

> 证书保存在 `/etc/letsencrypt/live/www.lihuanyu.icu/`

### 自动续期

Let's Encrypt 证书有效期 90 天。首次签发后用 webroot 模式续期，无需停止服务：

```bash
# 测试续期是否正常
certbot renew --webroot -w /opt/blog/site --dry-run

# 实际续期（写入 crontab，系统自动执行）
certbot renew --webroot -w /opt/blog/site --quiet
```

续期后自动重启 Nginx 容器使新证书生效：

```bash
#!/bin/bash
# /etc/letsencrypt/renewal-hooks/deploy/restart-nginx.sh
certbot renew --webroot -w /opt/blog/site --quiet
docker restart blog
```

## CI/CD 自动部署

### 整体流程

```
本地 git push → GitHub Actions 触发 → Hugo 构建 → rsync 同步到 ECS → 完成
```

### 关键步骤

**1. 生成部署专用 SSH 密钥**

```bash
ssh-keygen -t ed25519 -f ~/.ssh/blog-deploy -N "" -C "github-actions"
```

**2. 公钥放服务器**

```bash
cat ~/.ssh/blog-deploy.pub >> ~/.ssh/authorized_keys
```

**3. 私钥存 GitHub Secrets**

```
Name: SSH_PRIVATE_KEY
Value: （base64 编码后的私钥内容）
```

**4. GitHub Actions Workflow**

```yaml
name: Deploy Blog
on:
  push:
    branches: [master]
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true      # 主题是 Git 子模块

      - uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: "latest"
          extended: true

      - run: hugo --buildFuture --minify

      - name: Setup SSH
        run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.SSH_PRIVATE_KEY }}" | base64 -d > ~/.ssh/deploy_key
          chmod 600 ~/.ssh/deploy_key

      - name: Deploy
        run: |
          rsync -avz --delete \
            -e "ssh -i ~/.ssh/deploy_key -o StrictHostKeyChecking=no" \
            public/ root@47.119.121.45:/opt/blog/site/
```

## 常用运维命令

```bash
# 查看容器状态
docker ps
docker logs blog --tail 50 -f

# 重启服务
docker compose restart

# 更新证书后热加载
docker restart blog

# 查看磁盘使用
du -sh /opt/blog/site/
df -h

# 查看 Nginx 访问日志
docker exec blog cat /var/log/nginx/access.log
```

## 踩坑记录

### 1. GitHub Actions 私钥格式问题

直接用 `echo` 写入 SSH 私钥时，GitHub Secrets 会引入不可见字符，导致 `libcrypto` 解析失败。

**解决**：用 `base64` 编码后存 Secret，CI 中 `base64 -d` 解码。

### 2. Certbot standalone 与 Nginx 端口冲突

`certbot certonly --standalone` 需要绑定 80 端口，与正在运行的 Nginx 冲突。

**解决**：首次签发时先 `docker compose stop`，续期改用 `--webroot` 模式。

### 3. 证书挂载路径权限

Nginx 容器以非 root 用户运行，证书文件需要可读权限。

**解决**：用 `:ro`（只读）挂载，不需要特殊权限设置。

---

*部署耗时：约 3 小时（从零到全站上线）*
