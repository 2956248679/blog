# 罗非瑜的技术博客

[![Hugo](https://img.shields.io/badge/Hugo-0.164-blue?logo=hugo)](https://gohugo.io/)
[![Docker](https://img.shields.io/badge/Docker-27.x-blue?logo=docker)](https://www.docker.com/)
[![Nginx](https://img.shields.io/badge/Nginx-1.27-green?logo=nginx)](https://nginx.org/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

基于 **Hugo + Hugo Narrow 主题 + Docker + Nginx** 的个人技术博客，支持 CI/CD 自动部署。

👉 在线地址：[www.lihuanyu.icu](https://www.lihuanyu.icu)

![screenshot](static/images/og-default.avif)

---

## 技术栈

| 技术 | 用途 |
|------|------|
| [Hugo](https://gohugo.io/) | Go 语言静态站点生成器，毫秒级构建 |
| [Hugo Narrow](https://github.com/tom2almighty/hugo-narrow) | Tailwind CSS 4 + DaisyUI 主题 |
| [Docker](https://www.docker.com/) | 容器化部署，环境一致性 |
| [Nginx](https://nginx.org/) | 高性能 Web 服务器 |
| [GitHub Actions](https://github.com/features/actions) | CI/CD 自动构建部署 |
| [Let's Encrypt](https://letsencrypt.org/) | 免费 HTTPS 证书 |

---

## 快速开始（本地开发）

### 前提

- Hugo Extended ≥ 0.158.0
- Git

### 1. 克隆项目

```bash
git clone --recursive https://github.com/2956248679/blog.git
cd blog
```

> `--recursive` 确保同时拉取 Hugo Narrow 主题子模块。

### 2. 启动开发服务器

```bash
hugo server --buildFuture --disableFastRender
```

浏览器打开 `http://localhost:1313`，修改 Markdown 文件后页面自动刷新。

### 3. 构建静态文件

```bash
hugo --buildFuture --minify
```

构建产物在 `public/` 目录。

---

## Docker 部署

### 方式一：docker-compose（生产推荐）

```bash
# 1. 构建静态文件
hugo --buildFuture --minify

# 2. 推送到服务器
scp -r public/* root@你的服务器IP:/opt/blog/site/
scp nginx/blog.conf root@你的服务器IP:/opt/blog/nginx/

# 3. 在服务器上启动
ssh root@你的服务器IP
cd /opt/blog
docker compose -f docker-compose.prod.yml up -d
```

### 方式二：Dockerfile 构建

```bash
# 构建镜像
docker build -t my-blog .

# 运行容器
docker run -d -p 80:80 --name blog --restart unless-stopped my-blog
```

---

## CI/CD 自动部署

本项目配置了 GitHub Actions，推送代码后自动部署：

```
git push → GitHub Actions → Hugo 构建 → SCP 同步到服务器 → Nginx 热更新
```

### 配置 GitHub Secrets

在仓库 `Settings → Secrets and variables → Actions` 中添加：

| Secret | 说明 |
|--------|------|
| `SSH_PRIVATE_KEY` | 服务器 SSH 私钥 |
| `REMOTE_HOST` | 服务器公网 IP |
| `REMOTE_USER` | 服务器用户名 |

---

## 项目结构

```
blog/
├── content/               # 📝 Markdown 文章目录
│   ├── posts/             #    技术文章
│   ├── projects/          #    项目介绍
│   └── about.md           #    关于页面
├── config/_default/       # ⚙️ Hugo 配置
│   ├── hugo.yaml          #    主配置
│   ├── params.yaml        #    主题参数
│   └── menus.yaml         #    导航菜单
├── layouts/               # 🎨 自定义模板
├── static/                # 🖼️ 静态资源（图片、Logo）
├── themes/hugo-narrow/    # 🧩 Hugo Narrow 主题（Git 子模块）
├── nginx/                 # 🔧 Nginx 配置
├── Dockerfile             # 🐳 Docker 镜像构建
├── docker-compose.prod.yml# 🚀 生产环境编排
└── .github/workflows/     # ⚡ CI/CD 工作流
```

---

## 写文章

```bash
# 1. 创建新文章
hugo new content posts/新文章标题.md

# 2. 编辑 content/posts/新文章标题.md
#    改 draft: false，写 Markdown 内容

# 3. 本地预览
hugo server --buildFuture

# 4. 提交发布
git add . && git commit -m "新文章: xxx"
git push
```

> ⚠️ 注意：Front Matter 中的 `date` 必须带时区，否则可能被 Hugo 当作未来文章过滤。
> ```yaml
> date: 2026-08-08T08:00:00+08:00  # 正确 ✅
> date: 2026-08-08                  # 可能被过滤 ❌
> ```

---

## 主题定制

本项目使用 [Hugo Narrow](https://github.com/tom2almighty/hugo-narrow) 主题，以下部分做了自定义：

| 文件 | 改动 |
|------|------|
| `layouts/baseof.html` | 导航栏全宽显示 |
| `layouts/_partials/navigation/header.html` | Logo 容器调整为矩形 |
| `layouts/_partials/layout/head.html` | Favicon 支持 PNG 格式 |
| `assets/css/custom/header.css` | 去除导航栏圆角和边框 |

---

## License

MIT © 罗非瑜
