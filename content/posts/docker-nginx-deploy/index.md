---
title: "Docker + Nginx 部署静态站点完整指南"
date: 2026-08-07T22:00:00+08:00
draft: false
tags: ["Docker", "Nginx", "运维"]
summary: "从零开始用 Docker Compose 部署 Nginx 静态站点，包括镜像选择、安全配置、Gzip 压缩和容器自动重启策略。"
---

## 为什么用 Docker 部署静态站点

传统方式在服务器上直接装 Nginx：

```bash
apt install nginx
vi /etc/nginx/sites-enabled/default
systemctl restart nginx
```

问题：
- 环境不一致（Ubuntu 22 和 24 的 Nginx 版本不同）
- 迁移麻烦（换服务器要重新配一遍）
- 残留文件（卸载不干净）

Docker 方式：

```bash
docker compose up -d
```

一行命令，环境完全一致，任何 Linux 发行版都能跑。

## Dockerfile

```dockerfile
FROM nginx:1.27-alpine
COPY site/ /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

选择 `alpine` 版本的原因：

| 镜像 | 大小 |
|------|------|
| nginx:1.27 | ~190MB |
| nginx:1.27-alpine | ~45MB |

Alpine 体积小、攻击面少，生产环境首选。

## docker-compose.yml

```yaml
services:
  blog:
    image: nginx:1.27-alpine
    container_name: blog
    ports:
      - "80:80"
    volumes:
      - ./site:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
```

关键配置解读：

- `volumes` 用 `:ro`（只读）挂载——容器不应该修改静态文件
- `restart: unless-stopped`——服务挂了自动重启，手动 stop 才停
- `container_name`——方便 `docker logs blog` 查看日志

## Nginx 配置要点

```nginx
server {
    listen 80;
    server_name www.lihuanyu.icu;

    root /usr/share/nginx/html;
    index index.html;

    # Gzip 压缩
    gzip on;
    gzip_types text/css application/javascript text/xml;
    gzip_min_length 256;
    gzip_comp_level 6;

    # 静态资源缓存 30 天
    location ~* \.(js|css|png|jpg|woff2)$ {
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

## 常用运维命令

```bash
# 启动
docker compose up -d

# 查看日志
docker compose logs -f --tail=50

# 重启（更新配置后）
docker compose restart

# 进入容器排查
docker exec -it blog sh

# 更新服务（CI/CD 中用）
docker compose down && docker compose up -d
```

## 总结

Docker 部署静态站点的核心优势：**环境一致、迁移简单、配置即代码**。对于运维工程师来说，这是基础中的基础，但也是面试必问的内容。
