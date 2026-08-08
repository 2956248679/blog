---
title: "容器化技术博客平台"
date: 2026-08-08T08:00:00+08:00
draft: false
tags: ["Docker", "Hugo", "Nginx", "CI/CD"]
summary: "从零搭建的运维实战项目，涵盖服务器加固、Docker 部署、Nginx 配置、CI/CD 流水线全流程。"
---

## 项目概述

这个博客本身就是运维实战项目。以下每个环节都有完整的操作命令和配置说明。

---

## 一、服务器环境

### 云服务器

| 配置 | 详情 |
|------|------|
| 云平台 | 阿里云 ECS |
| 操作系统 | Ubuntu 24.04 |
| 规格 | 2 vCPU / 2 GiB / 40 GB ESSD |
| 带宽 | 10 Mbps 峰值（按流量计费） |
| 公网 IP | 47.119.121.45 |

### SSH 安全加固

```bash
# 创建普通用户，禁用 root SSH 登录
useradd -m -s /bin/bash admin
usermod -aG sudo admin

# 配置 SSH 密钥登录
mkdir -p ~/.ssh && chmod 700 ~/.ssh
vi ~/.ssh/authorized_keys   # 写入公钥
chmod 600 ~/.ssh/authorized_keys

# 修改 SSH 配置
vi /etc/ssh/sshd_config
# PermitRootLogin no
# PasswordAuthentication no
# PubkeyAuthentication yes

systemctl restart sshd
```

### 安装 Docker

```bash
# 官方脚本安装
curl -fsSL https://get.docker.com | bash

# 启动 + 开机自启
systemctl enable docker --now

# 验证
docker --version
docker compose version
```

---

## 二、项目目录结构

```
blog-project/
├── content/               # Markdown 文章
│   ├── posts/             # 技术文章
│   ├── projects/          # 项目介绍
│   └── about.md           # 关于页面
├── config/_default/       # Hugo 配置
│   ├── hugo.yaml          # 主配置
│   ├── params.yaml        # 主题参数
│   └── menus.yaml         # 导航菜单
├── layouts/               # 自定义模板
│   ├── baseof.html        # 全宽导航
│   └── _partials/         # 覆盖主题组件
├── static/images/         # Logo / 头像
├── themes/hugo-narrow/    # Hugo Narrow 主题
├── nginx/blog.conf        # Nginx 配置
├── Dockerfile             # Hugo 构建镜像
├── docker-compose.yml     # 本地构建
├── docker-compose.prod.yml # 生产部署
└── .github/workflows/     # CI/CD
```

---

## 三、Docker 容器化

### Dockerfile（多阶段构建）

```dockerfile
# 阶段一：编译 Hugo 静态文件
FROM hugomods/hugo:exts as builder
WORKDIR /src
COPY . /src
RUN hugo --buildFuture --minify

# 阶段二：Nginx 提供 Web 服务
FROM nginx:1.27-alpine
COPY --from=builder /src/public /usr/share/nginx/html
COPY nginx/blog.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### docker-compose.prod.yml（生产环境）

```yaml
services:
  blog:
    image: nginx:1.27-alpine
    container_name: blog
    ports:
      - "80:80"
    volumes:
      - /opt/blog/site:/usr/share/nginx/html:ro
      - ./nginx/blog.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
```

部署命令：

```bash
# 首次部署
docker compose -f docker-compose.prod.yml up -d

# 更新静态文件后
docker compose restart

# 查看日志
docker compose logs -f --tail=50
```

---

## 四、Nginx 配置

```nginx
server {
    listen 80;
    server_name www.lihuanyu.icu lihuanyu.icu 47.119.121.45;

    root /usr/share/nginx/html;
    index index.html index.xml;

    # Gzip 压缩 — 减少传输体积
    gzip on;
    gzip_types text/css application/javascript text/xml application/rss+xml;
    gzip_min_length 256;
    gzip_comp_level 6;

    # 静态资源缓存 30 天
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # 安全头
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

---

## 五、CI/CD 自动部署

### GitHub Actions 工作流

```yaml
name: Deploy Blog
on:
  push:
    branches: [main]
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true

      - name: Setup Hugo
        uses: peaceiris/actions-hugo@v3
        with:
          hugo-version: "latest"
          extended: true

      - name: Build
        run: hugo --buildFuture --minify

      - name: Deploy to ECS
        uses: easingthemes/ssh-deploy@v5
        with:
          SSH_PRIVATE_KEY: ${{ secrets.SSH_PRIVATE_KEY }}
          ARGS: "-avz --delete"
          SOURCE: "public/"
          REMOTE_HOST: ${{ secrets.REMOTE_HOST }}
          REMOTE_USER: ${{ secrets.REMOTE_USER }}
          TARGET: "/opt/blog/site/"
```

部署流程：

```
git push → GitHub Actions 触发 → Hugo 构建 → SCP 同步到 ECS → Nginx 热更新
```

---

## 六、踩坑记录

### 时区问题：文章不显示

文章的 `date` 字段不加时区时，Hugo 默认使用 UTC 时间解析。北京时间（UTC+8）比 UTC 快 8 小时，导致凌晨发布的文章被当作"未来文章"过滤。

```yaml
# 错误：会被当作 UTC 零点，可能在当前 UTC 时间的"未来"
date: 2026-08-08

# 正确：明确指定东八区时间
date: 2026-08-08T08:00:00+08:00
```

排查过程用了 3 小时：怀疑模板 → 怀疑版本 → 怀疑多语言 → 怀疑页面包 → 对比实验 → 最终定位时区。

### Hugo Narrow 导航栏宽度

Hugo Narrow 默认把整个页面（包括导航）限制在 `max-width: 56rem` 内。通过自定义 `layouts/baseof.html` 把 header 移到容器外，实现导航栏铺满全屏。

---

## 总结

这个项目覆盖了运维工程师的核心技能栈：

| 技能 | 落地 |
|------|------|
| Linux 管理 | SSH 加固、用户权限、文件操作 |
| Docker | 多阶段构建、Compose 编排、Volume 挂载 |
| Nginx | 反向代理、Gzip、缓存、安全头 |
| CI/CD | GitHub Actions 自动化部署 |
| 排错能力 | 时区问题 3 小时排查全记录 |
